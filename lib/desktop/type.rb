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
                Dir[File.join(p,'*')].sort.each do |d|
                  begin
                    md = YAML.load_file(File.join(d,'metadata.yml'))
                    h[md[:name].to_sym] = Type.new(md, d)
                  rescue
                    nil
                  end
                end
              end
            end
          end
      end

      def default
        all.values.find { |t| t.default == true } || all.values.first || Type.new({name: 'default'}, '/tmp')
      end

      def set_default(type_name, global: false)
        self[type_name].tap do |t|
          if global
            Config.data.set(:desktop_type, value: t.name)
            Config.save_data
          else
            Config.user_data.set(:desktop_type, value: t.name)
            Config.save_user_data
          end
        end
      end
    end

    attr_reader :name
    attr_reader :summary
    attr_reader :url
    attr_reader :default

    def initialize(md, dir)
      @name = md[:name]
      @summary = md[:summary]
      @url = md[:url]
      @default = md[:default]
      @dir = dir
    end

    def session_script
      @session_script ||= File.join(@dir, 'session.sh')
    end

    def verified?
      File.exist?(File.join(prep_dir, 'state.yml')) ||
        File.exist?(File.join(verify_dir, 'state.yml'))
    end

    def prepare(force: false)
      return true if !force && verified?
      puts "Preparing desktop type #{Paint[name, :cyan]}:\n\n"
      if run_script(File.join(@dir, 'prepare.sh'), prep_dir, 'prepare')
        File.open(File.join(prep_dir, 'state.yml'), 'w') do |io|
          io.write({verified: true}.to_yaml)
        end
        puts <<EOF

Desktop type #{Paint[name, :cyan]} has been prepared.

EOF
        true
      else
        log_file = File.join(
          prep_dir,
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
      success = run_script(File.join(@dir, 'verify.sh'), verify_dir, 'verify', ctx)
      if ctx[:missing].empty? && success
        File.open(File.join(verify_dir, 'state.yml'), 'w') do |io|
          io.write({verified: true}.to_yaml)
        end
        puts <<EOF

Desktop type #{Paint[name, :cyan]} has been verified.

EOF
        true
      else
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
      h['BASH_FUNC_flight_desktop_comms()'] = <<EOF
() { local msg=$1
 shift
 if [ "$1" ]; then
 echo "${msg}:$*" 1>&#{fileno};
 else
 cat | sed "s/^/${msg}:/g" 1>&#{fileno};
 fi
}
EOF
      h['BASH_FUNC_desktop_err()'] = "() { flight_desktop_comms ERR \"$@\"\n}"
      h['BASH_FUNC_desktop_stage()'] = "() { flight_desktop_comms STAGE \"$@\"\n}"
      h['BASH_FUNC_desktop_miss()'] = "() { flight_desktop_comms MISS \"$@\"\n}"
#      h['BASH_FUNC_desktop_cat()'] = "() { flight_desktop_comms\n}"
#      h['BASH_FUNC_desktop_echo()'] = "() { flight_desktop_comms DATA \"$@\"\necho \"$@\"\n}"
    end

    def run_script(script, dir, op, context = {})
      if File.exists?(script)
        Bundler.with_clean_env do
          run_fork(context) do |wr|
            wr.close_on_exec = false
            setup_bash_funcs(ENV, wr.fileno)
            log_file = File.join(
              dir,
              "#{name}.#{op}.log"
            )
            FileUtils.mkdir_p(dir)
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
        raise IncompleteTypeError, "no preparation script provided for type: #{name}"
      end
    end

    def prep_dir
      @prep_dir ||= File.join(Config.root,'var','lib','desktop',name)
    end

    def verify_dir
      @verify_dir ||=
        if Process.euid == 0
          prep_dir
        else
          File.join(Config.user_verify_path, name)
        end
    end
  end
end
