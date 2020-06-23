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

    attr_reader :uuid, :type, :metadata, :host_name, :state, :websocket_port

    def initialize(uuid: nil, type: nil)
      if uuid.nil?
        @uuid = SecureRandom.uuid
        @type = type
        @metadata = {}
        @host_name = Socket.gethostname.split('.')[0]
        @state = :new
      else
        @uuid = uuid
        begin
          load
        rescue
          @metadata = {}
          @state = :broken
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

    def websocket_port
      @websocket_port ||= allocate_websocket_port
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
        rc = $?
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
          start_vnc_server(geometry: geometry) &&
            start_websocket_server &&
            start_grabber &&
            start_cleaner &&
            save
        end
      end
    end

    def start_websocket_server
      if File.executable?('/usr/bin/websockify') && websocket_port > 0
        pid = fork {
          log_file = File.join(
            dir,
            "websocket.log"
          )
          exec(
            {},
            '/usr/bin/websockify',
            "0.0.0.0:#{websocket_port}",
            "#{ip}:#{port}",
            [:out, :err] => [log_file ,'w']
          )
        }
        Process.detach(pid)
        @websocket_pid = pid
      else
        @websocket_port = 0
      end
      true
    end

    def start_cleaner
      pid = fork {
        log_file = File.join(
          dir,
          "cleaner.log"
        )
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
      end
      true
    end

    def start_vnc_server(geometry: Config.geometry)
      IO.popen(
        {}.tap do |h|
          h['flight_DESKTOP_root'] = Config.root
          h['flight_DESKTOP_type_root'] = type.dir
          h['flight_DESKTOP_bg_image'] = File.expand_path(
            Config.bg_image || 'etc/assets/backgrounds/default.jpg',
            Config.root
          )
          h['flight_DESKTOP_geometry'] = Config.geometry
        end,
        [
          Config.vnc_server_program,
          '-autokill',
          '-sessiondir', dir,
          '-sessionscript', File.join(dir, 'session.sh'),
          '-vncpasswd', File.join(dir, 'password.dat'),
          '-exedir', '/usr/bin',
          '-geometry', geometry,
          :err=>[:child, :out]
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
    end

    def save
      {
        metadata: @metadata,
        type: @type.name,
        password: password,
        ip: ip,
        websocket_port: websocket_port,
        host_name: host_name,
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
  end
end
