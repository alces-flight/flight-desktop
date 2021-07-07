# =============================================================================
# Copyright (C) 2019-present Alces Flight Ltd.
#
# This file is part of Flight Desktop.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# Flight Desktop is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with Flight Desktop. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on Flight Desktop, please visit:
# https://github.com/alces-flight/flight-desktop
# ==============================================================================
require_relative 'config'
require_relative 'network_utils'
require_relative 'command_utils'
require 'time'
require 'securerandom'
require 'fileutils'
require 'sys/proctable'
require 'socket'

module Desktop
  class Session
    class << self
      def each(&block)
        all.values.each(&block)
      end

      def [](k)
        s = all[k]
        if s.nil?
          s = all.values.find do |r|
            r.uuid.split('-').first == k
          end
        end
        if s.nil?
          raise SessionNotFoundError, "unknown session: #{k}"
        end
        s
      end

      def find_by_display(display, include_exited: false)
        all.values.find do |s|
          s.display == display && s.local? && (include_exited || s.active?)
        end
      end

      def all
        @sessions ||=
          begin
            {}.tap do |h|
              Dir[File.join(Config.session_path,'*')].sort.each do |d|
                begin
                  uuid = File.basename(d)
                  unless Dir[File.join(d,'*')].empty?
                    h[uuid] = Session.new(uuid: uuid)
                  end
                rescue
                  nil
                end
              end
            end
          end
      end
    end

    attr_reader :uuid, :type, :metadata, :host_name, :state, :websocket_port, :created_at, :last_accessed_at

    def initialize(uuid: nil, type: nil)
      if uuid.nil?
        @uuid = SecureRandom.uuid
        @type = type
        @metadata = {}
        @host_name = Socket.gethostname.split('.')[0]
        @state = :new
        @created_at = Time.now
      else
        @uuid = uuid
        begin
          load
        rescue
          @metadata = {}
          @state = :broken
          @created_at = determine_created_at
        end
      end
    end

    def state
      @state
    end

    def ip
      @ip ||= NetworkUtils.primary_ip
    end

    def method_missing(s, *a, &b)
      if @metadata.key?(s)
        @metadata[s]
      else
        super
      end
    end

    def respond_to_missing?(s, include_all)
      @metadata.key?(s.to_sym) || super
    end

    def dir
      @dir ||= find_session_dir
    end

    def display
      @metadata[:display]
    end

    def port
      (@metadata[:display] || 0).to_i + 5900
    end

    def password
      @password ||= CommandUtils.generate_password
    end

    def clean
      FileUtils.rm_rf(session_dir_path)
    end

    def kill
      CommandUtils.with_clean_env do
        IO.popen(
          [
            Config.vnc_server_program,
            '-kill',
            '-sessiondir',
            session_dir_path,
            :err=>[:child, :out]
          ]
        ) do |io|
          lines = io.readlines
          if ENV['flight_DESKTOP_debug']
            puts lines.inspect
          end
        end
        $?.success?.tap do |s|
          clean if s && ENV['flight_DESKTOP_debug'].nil?
        end
      end
    end

    def start(geometry: Config.geometry)
      h = (Dir.home rescue '/')
      Dir.chdir(h) do
        CommandUtils.with_cleanest_env do
          create_password_file
          install_session_script
          start_vnc_server(geometry: geometry).tap do |started|
            if started
              start_websocket_server
              start_grabber
              start_cleaner
              save
            end
          end
        end
      end
    end

    def start_web_support_services
      h = (Dir.home rescue '/')
      Dir.chdir(h) do
        CommandUtils.with_cleanest_env do
          start_websocket_server.tap do |started|
            if started
              start_grabber
              start_cleaner
              save
            end
          end
        end
      end
    end

    def start_websocket_server
      return true if !@websocket_pid.nil?

      websockify_exe = Config.websockify_paths.detect { |p| File.executable?(p) }
      unless websockify_exe
        @websocket_port = 0
        return false
      end

      @websocket_port = allocate_websocket_port
      return false if @websocket_port == 0

      pid = fork {
        log_file = File.join(
          dir,
          "websocket.log"
        )
        exec(
          {},
          websockify_exe,
          "0.0.0.0:#{@websocket_port}",
          "127.0.0.1:#{port}",
          [:out, :err] => [log_file ,'w']
        )
      }
      Process.detach(pid)
      @websocket_pid = pid
      true
    end

    def start_cleaner
      pid = fork {
        exec(
          {
            'SESSION_VNC_PID' => File.read(pidfile).chomp,
            'SESSION_PIDS' => "#{@websocket_pid} #{@grabber_pid}",
            'SESSION_DIR' => dir,
          },
          File.join(Config.root,'libexec','cleaner'),
          [:out, :err] => ['/dev/null','w'],
          :chdir => '/'
        )
      }
      Process.detach(pid)
      true
    end

    def start_grabber
      if File.executable?('/usr/bin/xwd') &&
         File.executable?('/usr/bin/xwdtopnm') &&
         File.executable?('/usr/bin/pnmtopng')
        pid = fork {
          log_file = File.join(
            dir,
            "grabber.log"
          )
          exec(
            {},
            File.join(Config.root,'libexec','grabber'),
            display,
            dir,
            [:out, :err] => [log_file ,'w']
          )
        }
        Process.detach(pid)
        @grabber_pid = pid
        true
      else
        false
      end
    end

    def start_vnc_server(geometry: Config.geometry)
      IO.popen(
        {}.tap do |h|
          h['flight_DESKTOP_type_root'] = type.dir
          h['flight_DESKTOP_bg_image'] = Config.bg_image
          h['flight_DESKTOP_geometry'] = geometry

          # DEPREACTED: flight_DESKTOP_root does not function correctly
          # due to the desktop-types being extracted. Originally it was
          # used to construct paths like:
          #
          # etc/gnome/session.sh:flight_DESKTOP_type_root="${flight_DESKTOP_type_root:-${flight_DESKTOP_root}/etc/types/gnome}"
          #
          # However flight-desktop-type are no longer stored under 'etc',
          # so this paths isn't correct. The builder also changes the path
          # to be within 'usr/lib'. AFAICS, this fallback is never correct.
          #
          # Instead flight_DESKTOP_root should be removed entirely from
          # flight-desktop{-type} in favour of setting
          # `flight_DESKTOP_type_root and flight_DESKTOP_bg_image
          # directly; as done above.
          h['flight_DESKTOP_root'] = Config.root
          if Config.session_env_override
            h['USER'] = ENV['USER']
            h['HOME'] = ENV['HOME']
            h['LANG'] = ENV['LANG']
            h['PATH'] = Config.session_env_path
          end
        end,
        [
          Config.vnc_server_program,
          '-autokill',
          '-sessiondir', dir,
          '-sessionscript', File.join(dir, 'session.sh'),
          '-vncpasswd', File.join(dir, 'password.dat'),
          '-exedir', '/usr/bin',
          '-geometry', geometry,
          {
            err: [:child, :out],
            unsetenv_others: Config.session_env_override
          }
        ]
      ) do |io|
        yaml_content = ""
        keep = false
        io.readlines.each do |l|
          puts l.inspect if ENV['flight_DESKTOP_debug']
          if l == "<YAML>\n"
            keep = true
          elsif l == "</YAML>\n"
            keep = false
          elsif keep
            yaml_content << l
          end
        end
        yaml_vals = YAML.load(yaml_content)
        if yaml_vals.is_a?(Hash)
          @metadata.merge!(yaml_vals)
        end
      end
      rc = $?
      rc.success?
    end

    def start_app(*args, index:, max:)
      pid = fork {
        log_file = File.join(
          dir,
          "apps.log"
        )
        exec(
          {},
          'bash',
          type.launch_app_path,
          ":#{display}",
          index.to_s,
          max.to_s,
          *args,
          [:out, :err] => [log_file ,'w']
        )
      }
      Process.detach(pid)
    end

    def start_script(*args, index:, max:)
      pid = fork {
        log_file = File.join(
          dir,
          "scripts.log"
        )
        exec(
          {},
          'bash',
          type.launch_script_path,
          ":#{display}",
          index.to_s,
          max.to_s,
          *args,
          [:out, :err] => [log_file ,'w']
        )
      }
      Process.detach(pid)
    end

    def active?
      if @state != :broken && local? && File.exists?(pidfile)
        pid = File.read(pidfile)
        !!Sys::ProcTable.ps(pid: pid.to_i)
      end
    end

    def local?
      ip == NetworkUtils.primary_ip
    end

    private
    def allocate_websocket_port
      free_port = (@metadata[:display] || 0).to_i + 41360
      begin
        TCPServer.new(free_port).close
      rescue Errno::EADDRINUSE
        if free_port < 43000
          free_port += 100
          retry
        else
          free_port = 0
        end
      end
      free_port
    end

    def load
      metadata = YAML.load_file(metadata_file)
      @metadata = metadata[:metadata]
      @type = Type[metadata[:type]]
      @password = metadata[:password]
      @ip = metadata[:ip]
      @websocket_port = metadata[:websocket_port] || 0
      @websocket_pid = metadata[:websocket_pid]
      @host_name = metadata[:host_name]
      @state = active? ? :active : :exited
      @last_accessed_at = if File.exists?File.join(dir, 'session.log')
                            File.ctime File.join(dir, 'session.log')
                          end
      @created_at = determine_created_at
    end

    def save
      {
        metadata: @metadata,
        type: @type.name,
        password: password,
        ip: ip,
        host_name: host_name,
        created_at: created_at.strftime("%Y-%m-%dT%T%z")
      }.tap do |md|
        if websocket_port != 0
          md[:websocket_port] = websocket_port
          md[:websocket_pid] = @websocket_pid
        end
        File.open(metadata_file, 'w') do |io|
          io.write(md.to_yaml)
        end
      end
    end

    def session_dir_path
      @session_dir_path ||= File.join(Config.session_path, uuid)
    end

    def install_session_script
      FileUtils.cp(type.session_script, session_dir_path)
    end

    def create_password_file
      vnc_password = IO.popen([Config.vnc_passwd_program,'-f'],'r+') do |io|
        io.write(password)
        io.close_write
        io.read
      end
      File.open(File.join(dir,'password.dat'), 'w') do |f|
        f.print(vnc_password)
      end
    end

    def find_session_dir
      session_dir_path.tap do |p|
        if ! File.directory?(p)
          FileUtils.mkdir_p(p)
        end
      end
    end

    def metadata_file
      @metadata_file ||= File.join(session_dir_path, 'metadata.yml')
    end

    def determine_created_at
      # The easy case.
      return Time.parse(metadata[:created_at]) if metadata[:created_at]

      # Backwards compatibility with sessions started with older versions of
      # `flight-desktop`.  Return the oldest sensible time that is not after
      # `last_accessed_at`.  A best guess is sufficient.
      dir_ctime = File.ctime(session_dir_path) if File.exist?(session_dir_path)
      meta_ctime = File.ctime(metadata_file) if File.exist?(metadata_file)
      [
        [ dir_ctime, meta_ctime ].compact.max,
        last_accessed_at,
      ].compact.min
    end
  end
end
