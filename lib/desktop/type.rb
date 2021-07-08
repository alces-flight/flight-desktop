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
require_relative 'errors'

require 'erb'
require 'fileutils'
require 'yaml'
require 'whirly'
require_relative 'patches/unicode-display_width'

module Desktop
  class Type
    FUNC_DELIMITER = begin
                       major, minor, patch =
                                     IO.popen("/bin/bash -c 'echo $BASH_VERSION'")
                                       .read.split('.')[0..2]
                                       .map(&:to_i)
                       (
                         major > 4 ||
                         major == 4 && minor > 3 ||
                         major == 4 && minor == 3 && patch >= 27
                       ) ? '%%' : '()'
                     end

    class << self
      def each(&block)
        all.values.each(&block)
      end

      def [](k)
        all[k.to_sym].tap do |t|
          if t.nil?
            raise UnknownDesktopTypeError, "unknown desktop type: #{k}"
          end
        end
      end

      def all
        @types ||=
          begin
            {}.tap do |h|
              Config.type_paths.each do |p|
                Dir[File.join(p,'*'),File.join(p,'.[a-z]*')].sort.each do |d|
                  begin
                    md = YAML.load_file(File.join(d,'metadata.yml'))
                    t = Type.new(md, d)
                    h[md[:name].to_sym] = t if t.supports_host_arch?
                  rescue
                    nil
                  end
                end
              end
            end
          end
      end

      def default
        type = nil
        begin
          type = Type[Flight.config.desktop_type] if Flight.config.desktop_type
        rescue UnknownDesktopTypeError
          # NOOP
        end
        type || all.values.find { |t| t.default == true } || \
                all.values.first || \
                Type.new({name: 'default'}, '/tmp')
      end

      def set_default(type_name, global: false)
        self[type_name].tap do |t|
          Flight.config.save_key('desktop_type', t.name, global: global)
        end
      end
    end

    attr_reader :name
    attr_reader :summary
    attr_reader :url
    attr_reader :default
    attr_reader :arch
    attr_reader :hidden
    attr_reader :dir

    def initialize(md, dir)
      @name = md[:name]
      @summary = md[:summary]
      @url = md[:url]
      @default = md[:default]
      @dir = dir
      @arch = md[:arch] || []
      @hidden = (File.basename(dir)[0] == '.' || md[:hidden] || false)
    end

    def session_script
      @session_script ||= File.join(@dir, 'session.sh')
    end

    def supports_host_arch?
      if @arch.empty?
        true
      else
        @arch.include?(RbConfig::CONFIG['host_cpu'])
      end
    end

    def verified?
      paths = [
        File.join(global_state_dir, 'state.yml'),
        File.join(state_dir, 'state.yml')
      ].uniq.select { |p| File.exists?(p) }
      return false if paths.empty?

      path = paths.sort_by { |p| File.ctime(p) }.last
      YAML.load(File.read(path), symbolize_names: true)[:verified]
    end

    def prepare(force: false)
      return true if !force && verified?
      puts "Preparing desktop type #{Paint[name, :cyan]}:\n\n"
      if run_script(File.join(@dir, prepare_script), 'prepare')
        FileUtils.mkdir_p(global_state_dir)
        File.write(File.join(state_dir, 'state.yml'), { verified: true }.to_yaml)
        puts <<EOF

Desktop type #{Paint[name, :cyan]} has been prepared.

EOF
        true
      else
        log_file = File.join(
          Flight.config.log_dir,
          "#{name}.prepare.log"
        )
        raise TypeOperationError, "Unable to prepare desktop type '#{name}'; see: #{log_file}"
      end
    end

    def verify(force: false)
      return true if !force && verified?
      puts "Verifying desktop type #{Paint[name, :cyan]}:\n\n"
      ctx = {
        missing: []
      }
      success = run_script(File.join(@dir, verify_script), 'verify', ctx)
      FileUtils.mkdir_p(state_dir)
      if ctx[:missing].empty? && success
        File.write(File.join(state_dir, 'state.yml'), { verified: true }.to_yaml)
        puts <<EOF

Desktop type #{Paint[name, :cyan]} has been verified.

EOF
        true
      else
        File.write(File.join(state_dir, 'state.yml'), { verified: false }.to_yaml)
        puts <<EOF

Desktop type #{Paint[name, :cyan]} has missing prerequisites:

EOF
        ctx[:missing].each do |m|
          puts " * #{m}"
        end
        if Process.euid == 0
          puts <<EOF

Before this desktop type can be used, it must be prepared using the
'prepare' command, i.e.:

  #{Desktop::CLI::PROGRAM_NAME} prepare #{name}

EOF
        else
          puts <<EOF

Before this desktop type can be used, it must be prepared by your
cluster administrator using the 'prepare' command, i.e.:

  #{Desktop::CLI::PROGRAM_NAME} prepare #{name}

EOF
        end
        false
      end
    end

    private
    def distro
      if File.exists?('/etc/redhat-release')
        'rhel'
      elsif File.exists?('/etc/debian_version')
        'debian'
      end
    end

    def verify_script
      @verify_script ||=
        case distro
        when 'rhel'
          'verify.sh'
        else
          "verify.#{distro}.sh"
        end
    end

    def prepare_script
      @prepare_script ||=
        case distro
        when 'rhel'
          'prepare.sh'
        else
          "prepare.#{distro}.sh"
        end
    end

    def run_fork(context = {}, &block)
      Signal.trap('INT','IGNORE')
      rd, wr = IO.pipe
      pid = fork {
        rd.close
        Signal.trap('INT','DEFAULT')
        begin
          if block.call(wr)
            exit(0)
          else
            exit(1)
          end
        rescue Interrupt
          nil
        end
      }
      wr.close
      while !rd.eof?
        line = rd.readline
        if line =~ /^STAGE:/
          stage_stop
          @stage = line[6..-2]
          stage_start
        elsif line =~ /^ERR:/
          puts "== ERROR: #{line[4..-2]}"
        elsif line =~ /^MISS:/
          (context[:missing] ||= []) << line[5..-2]
          stage_stop(false)
        else
          puts " > #{line}"
        end
      end
      _, status = Process.wait2(pid)
      raise InterruptedOperationError, "Interrupt" if status.termsig == 2
      stage_stop(status.success?)
      Signal.trap('INT','DEFAULT')
      status.success?
    end

    def stage_start
      print "   > "
      Whirly.start(
        spinner: 'star',
        remove_after_stop: true,
        append_newline: false,
        status: Paint[@stage, '#2794d8']
      )
    end

    def stage_stop(success = true)
      return if @stage.nil?
      Whirly.stop
      puts "#{success ? "\u2705" : "\u274c"} #{Paint[@stage, '#2794d8']}"
      @stage = nil
    end

    def setup_bash_funcs(h, fileno)
      h["BASH_FUNC_flight_desktop_comms#{FUNC_DELIMITER}"] = <<EOF
() { local msg=$1
 shift
 if [ "$1" ]; then
 echo "${msg}:$*" 1>&#{fileno};
 else
 cat | sed "s/^/${msg}:/g" 1>&#{fileno};
 fi
}
EOF
      h["BASH_FUNC_desktop_err#{FUNC_DELIMITER}"] = "() { flight_desktop_comms ERR \"$@\"\n}"
      h["BASH_FUNC_desktop_stage#{FUNC_DELIMITER}"] = "() { flight_desktop_comms STAGE \"$@\"\n}"
      h["BASH_FUNC_desktop_miss#{FUNC_DELIMITER}"] = "() { flight_desktop_comms MISS \"$@\"\n}"
#      h['BASH_FUNC_desktop_cat()'] = "() { flight_desktop_comms\n}"
#      h['BASH_FUNC_desktop_echo()'] = "() { flight_desktop_comms DATA \"$@\"\necho \"$@\"\n}"
    end

    def run_script(script, op, context = {})
      if File.exists?(script)
        CommandUtils.with_clean_env do
          run_fork(context) do |wr|
            wr.close_on_exec = false
            setup_bash_funcs(ENV, wr.fileno)
            log_file = File.join(
              Flight.config.log_dir,
              "#{name}.#{op}.log"
            )
            FileUtils.mkdir_p(Flight.config.log_dir)
            exec(
              {},
              '/bin/bash',
              '-x',
              script,
              name,
              close_others: false,
              [:out, :err] => [log_file ,'w']
            )
          end
        end
      else
        raise IncompleteTypeError, "no #{op} script provided for type: #{name}"
      end
    end

    def global_state_dir
      @global_state_dir ||= File.join(Config.global_state_path, name)
    end

    def state_dir
      @state_dir ||=
        if Process.euid == 0
          global_state_dir
        else
          File.join(Config.user_state_path, name)
        end
    end
  end
end
