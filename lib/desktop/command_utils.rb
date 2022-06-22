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
require_relative 'network_utils'
require 'timeout'

module Desktop
  module CommandUtils
    ENV_BLACKLIST = %w(
      flight_COMMAND_ROOT
      flight_MODE
      flight_NAME
      FLIGHT_PROGRAM_NAME
      FLIGHT_CWD
      SSL_CERT_FILE
    )

    class << self
      def command(cmd)
        Paint%[
          "%{q}#{cmd}%{q}",
          :bright, :white, 48, 5, 68,
          q: ["'", :bright, :white, :default]
        ]
      end
    end

    INTERNAL_ONLY = <<EOF.freeze
This desktop session is not directly accessible from outside of your
cluster as it is running on a machine that only provides internal
cluster access.  #{Paint["In order to access your desktop session you will need
to perform port forwarding using 'ssh'.",:underline]}

Refer to #{command('%PROGNAME% show %SESSION%')} for more details.
EOF

    ON_ACCESS_HOST = <<EOF.freeze
This desktop session is not accessible from the public internet, but
may be directly accessible from within your local network or over a
virtual private network (VPN).
EOF

    IMPORTANT_NOTE = <<EOF.freeze
IMPORTANT NOTE
==============
  Accessing desktop sessions directly is NOT SECURE and we #{Paint["highly", :underline]}
  #{Paint["recommend using a secure port forwarding technique with 'ssh' to", :underline]}
  #{Paint["secure your desktop session.", :underline]}

  Refer to #{command('%PROGNAME% show %SESSION%')} for more details.
EOF

    PUBLIC = "This desktop session is directly accessible from the public internet.".freeze

    class << self
      def emit_details(session, suffix)
        if $stdout.tty?
          puts <<EOF

== #{Paint["Session details",:bright]} ==
      #{Paint['Name:','#2794d8']} #{Paint[session.name, :green]}      
  #{Paint['Identity:','#2794d8']} #{Paint[session.uuid, :green]}
      #{Paint['Type:','#2794d8']} #{Paint[session.type.name, :green]}
   #{Paint['Host IP:','#2794d8']} #{Paint[session.ip, :green]}
  #{Paint['Hostname:','#2794d8']} #{Paint[session.host_name, :green]}
      #{Paint['Port:','#2794d8']} #{Paint[session.port, :green]}
   #{Paint['Display:','#2794d8']} #{Paint[":#{session.display}",:green]}
  #{Paint['Password:','#2794d8']} #{Paint[session.password, :green]}
  #{Paint['Geometry:','#2794d8']} #{Paint[session.geometry, :green]}
EOF
          if session.job_id
            puts <<EOF
    #{Paint['Job ID:','#2794d8']} #{Paint[session.job_id, :green]}
EOF
          end
          puts "\n#{__send__(suffix, session)}"
        else
          puts "Identity\t#{session.uuid}"
          puts "Type\t#{session.type.name}"
          puts "Host IP\t#{session.ip}"
          puts "Hostname\t#{session.host_name}"
          puts "Port\t#{session.port}"
          puts "Display\t:#{session.display}"
          puts "Password\t#{session.password}"
          puts "State\t#{session.local? ? (session.active? ? 'Active' : 'Exited') : 'Remote'}"
          puts "WebSocket Port\t#{session.websocket_port}"
          puts "Created At\t#{session.created_at.strftime("%Y-%m-%dT%T%z")}"
          puts "Last Accessed At\t#{session.last_accessed_at&.strftime("%Y-%m-%dT%T%z").to_s}"
          puts "Screenshot Path\t#{File.join(session.dir, 'session.png')}"
          puts "IPs\t#{session.ips.join("|")}"
          puts "Name\t#{session.name}"
          puts "Geometry\t#{session.geometry}"
          puts "Job ID\t#{session.job_id}"
          puts "Available Geometries\t#{session.available_geometries.join("|")}"
        end
      end

      def password_prompt(session)
        <<EOF
If prompted, you should supply the following password: #{Paint[session.password, :green]}
EOF
      end

      def vnc_details(ip, session, color)
        <<EOF
Depending on your client and network configuration you may be able to
directly connect to the session using:

  #{Paint["vnc://#{ENV['USER']}:#{session.password}@#{ip}:#{session.port}",color]}
  #{Paint["#{ip}:#{session.port}",color]}
  #{Paint["#{ip}:#{session.display}",color]}
EOF
      end

      def public?(session)
        # determine if session is publicly reachable
        # 1. determine if this machine has a public IP
        # 2. determine if the VNC port is reachable
        !NetworkUtils.private_ip?(session.ip) &&
          NetworkUtils.reachable?(session.port)
      end

      def on_access_host?(session)
        # determine if session is running on designated access host
        # 1. determine if this machine is an access host
        NetworkUtils.access_host?(session.ip)
      end

      def access_summary(session)
        if public?(session)
          [
            PUBLIC,
            vnc_details(session.ip, session, :yellow),
            IMPORTANT_NOTE,
            password_prompt(session)
          ].join("\n")
        elsif on_access_host?(session)
          [
            ON_ACCESS_HOST,
            vnc_details(Config.access_ip, session, :yellow),
            IMPORTANT_NOTE,
            password_prompt(session)
          ].join("\n")
        else
          [
            INTERNAL_ONLY,
            password_prompt(session)
          ].join("\n")
        end.gsub(
          /\%.*?\%/, {
            '%PROGNAME%' => Desktop::CLI::PROGRAM_NAME,
            '%SESSION%' => session.uuid.split('-').first
          })
      end

      def access_details(session)
        general = <<EOF.chomp
Once the ssh connection has been established, depending on your
client, you can connect to the session using one of:

  #{Paint["vnc://#{ENV['USER']}:#{session.password}@localhost:#{session.port}",:green]}
  #{Paint["localhost:#{session.port}",:green]}
  #{Paint["localhost:#{session.display}",:green]}

If, when connecting, you receive a warning as follows, try again with
a different port number, e.g. #{session.port + 1}, #{session.port + 2} etc.:

  #{Paint["channel_setup_fwd_listener_tcpip: cannot listen to port: #{session.port}", :bold, '#888888']}

#{password_prompt(session)}
EOF
        if public?(session)
          <<EOF.chomp
This desktop session is accessible from the public internet.
#{vnc_details(Config.access_ip, session, :yellow)}
However, please be aware that desktop sessions accessed over the
public internet are not secure and steps should be taken to secure the
link.

#{Paint["We highly recommend that you access your desktop session using 'ssh'
port forwarding",:underline]}:

  #{Paint["ssh -L #{session.port}:localhost:#{session.port} #{ENV['USER']}@#{session.ip}",:green]}

#{general}
EOF
        elsif on_access_host?(session)
          <<EOF.chomp
This desktop session is not accessible from the public internet, but
may be directly accessible from within your local network or over a
virtual private network (VPN).

#{vnc_details(Config.access_ip, session, :yellow)}
However, #{Paint["we highly recommend that you access your desktop session using
'ssh' port forwarding",:underline]}:

  #{Paint["ssh -L #{session.port}:#{session.ip}:#{session.port} #{ENV['USER']}@#{Flight.config.access_host_or_ip}",:green]}

#{general}
EOF
        else
          <<EOF.chomp
This desktop session is not directly accessible from outside of your
cluster as it is running on a machine that only provides internal
cluster access.  #{Paint["In order to access your desktop session you will need
to perform port forwarding using 'ssh'",:underline]}:

  #{Paint["ssh -L #{session.port}:#{session.ip}:#{session.port} #{ENV['USER']}@#{Flight.config.access_host_or_ip}",:green]}

#{general}
EOF
        end
      end

      def generate_password
        if File.executable?('/usr/bin/apg')
          begin
            Timeout.timeout(5) do
              `/usr/bin/apg -n1 -M Ncl -m 8 -x 8`.chomp
            end
          rescue Timeout::Error
            SecureRandom.urlsafe_base64[0..7].tr('-_','fl')
          end
        else
          SecureRandom.urlsafe_base64[0..7].tr('-_','fl')
        end
      end

      def with_clean_env(&block)
        if Kernel.const_defined?(:OpenFlight) && OpenFlight.respond_to?(:with_standard_env)
          OpenFlight.with_standard_env { block.call }
        else
          msg = Bundler.respond_to?(:with_unbundled_env) ? :with_unbundled_env : :with_clean_env
          Bundler.__send__(msg) { block.call }
        end
      end

      def with_cleanest_env(&block)
        with_clean_env do
          original_env = ENV.clone
          ENV_BLACKLIST.each {|k| original_env.delete(k)}
          begin
            block.call
          ensure
            ENV.clear.replace(original_env)
          end
        end
      end
    end
  end
end
