# =============================================================================
# Copyright (C) 2020-present Alces Flight Ltd.
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
require_relative '../command'
require_relative '../config'

require 'json'

module Desktop
  module Commands
    class Doctor < Command
      CRITICAL_PROGS = {
        'VNC session management' => Config.vnc_server_program,
        'X VNC server' => '/usr/bin/Xvnc',
        'X authority file utility' => '/usr/bin/xauth',
        'VNC password management' => Config.vnc_passwd_program,
      }

      OPTIONAL_PROGS = {
        'Screen capture handling' => {
          'X window capture' => '/usr/bin/xwd',
          'Image converter (stage 1)' => '/usr/bin/xwdtopnm',
          'Image converter (stage 2)' => '/usr/bin/pnmtopng',
        },
        'Networking' => {
          'Websocket provider' => Config.websockify_paths,
        },
        'Improved passwords' =>  {
          'Password generator' => '/usr/bin/apg',
        },
      }

      def run
        if options.json
          critical_success = true
          output = {
            sections: (sections = []),
            failed: (failures = [])
          }
          sections << {
            description: 'Critical',
            services: (services = [])
          }
          CRITICAL_PROGS.each do |k,v|
            success = File.executable?(v)
            services << {
              description: k,
              executable: v,
              presence: success
            }
            critical_success &&= success
          end
          failures << 'Critical' unless critical_success
          all_success = critical_success
          OPTIONAL_PROGS.each do |s,h|
            section_success = true
            sections << {
              description: s,
              services: (services = [])
            }
            h.each do |k,v|
              if v.is_a?(Array)
                p = v.detect { |p| File.executable?(p) }
                success = !!p
                if success
                  services << {
                    description: k,
                    executable: p,
                    presence: success
                  }
                else
                  services << {
                    description: k,
                    executable: v,
                    presence: success
                  }
                end
              else
                success = File.executable?(v)
                services << {
                  description: k,
                  executable: v,
                  presence: success
                }
              end
              section_success &&= success
              all_success &&= success
            end
            failures << s unless section_success
          end
          output[:status] = all_success ? 'good' : ( critical_success ? 'pass' : 'fail' )
          puts JSON.pretty_generate(output)
        elsif $stdout.tty?
          puts "Verifying critical dependencies:\n\n"
          critical_success = true
          CRITICAL_PROGS.each do |k,v|
            success = File.executable?(v)
            puts "   > #{success ? "\u2705" : "\u274c"} #{k} (#{v})"
            critical_success &&= success
          end

          section_summary = []
          puts "\nVerifying optional dependencies:\n"
          OPTIONAL_PROGS.each do |s,h|
            section_output = ""
            section_success = true
            h.each do |k,v|
              if v.is_a?(Array)
                p = v.detect { |p| File.executable?(p) }
                success = !!p
                if success
                  section_output << "     > #{success ? "\u2705" : "\u274c"} #{k} (#{p})\n"
                  section_success &&= success
                else
                  section_output << "     > #{success ? "\u2705" : "\u274c"} #{k} (#{v.join(':')})\n"
                  section_success &&= success
                end
              else
                File.executable?(v).tap do |success|
                  section_output << "     > #{success ? "\u2705" : "\u274c"} #{k} (#{v})\n"
                  section_success &&= success
                end
              end
            end
            if !section_success
              section_summary << " * #{Paint["OPTIONAL",:bright,:yellow]} - #{s} dependencies are not satisfied."
            end
            puts "\n   > #{section_success ? "\u2705" : "\u274c"} #{s}\n#{section_output}"
          end
          puts "\n== #{Paint["Summary",:bright]} ==\n\n"
          if section_summary.empty? && critical_success
            puts " * #{Paint["OK",:bright,:green]} - all dependencies are satisfied!"
          else
            puts section_summary.join("\n")
            if !critical_success
              puts <<EOF
 * #{Paint["CRITICAL",:bright,:red]} - required dependencies are not available. 

 #{Paint["Flight Desktop will not function without further action.",:bright, :red]}
EOF
            end
          end
          puts ""
        else
          CRITICAL_PROGS.each do |k,v|
            success = File.executable?(v)
            puts "Critical\t#{k}\t#{v}\t#{success}"
          end
          OPTIONAL_PROGS.each do |s,h|
            h.each do |k,v|
              if v.is_a?(Array)
                p = v.detect { |p| File.executable?(p) }
                success = !!p
                if success
                  puts "#{s}\t#{k}\t#{p}\t#{success}"
                else
                  puts "#{s}\t#{k}\t#{v.join(':')}\t#{success}"
                end
              else
                File.executable?(v).tap do |success|
                  puts "#{s}\t#{k}\t#{v}\t#{success}"
                end
              end
            end
          end
        end
      end
    end
  end
end
