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

module Desktop
  module CommandUtils
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

  #{Paint['Identity:','#2794d8']} #{Paint[session.uuid, :green]}
      #{Paint['Type:','#2794d8']} #{Paint[session.type.name, :green]}
   #{Paint['Host IP:','#2794d8']} #{Paint[session.ip, :green]}
  #{Paint['Hostname:','#2794d8']} #{Paint[session.host_name, :green]}
      #{Paint['Port:','#2794d8']} #{Paint[session.port, :green]}
   #{Paint['Display:','#2794d8']} #{Paint[":#{session.display}",:green]}
  #{Paint['Password:','#2794d8']} #{Paint[session.password, :green]}

#{__send__(suffix, session)}
EOF
        else
          puts "Identity\t#{session.uuid}"
          puts "Type\t#{session.type.name}"
          puts "Host IP\t#{session.ip}"
          puts "Hostname\t#{session.host_name}"
          puts "Port\t#{session.port}"
          puts "Display\t:#{session.display}"
          puts "Password\t#{session.password}"
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

  #{Paint["vnc://#{ENV['USER']}:#{session.password}@localhost:5901",:green]}
  #{Paint["localhost:5901",:green]}
  #{Paint["localhost:1",:green]}

If, when connecting, you receive a warning as follows, try again with
a different port number, e.g. 5902, 5903 etc.:

  #{Paint["channel_setup_fwd_listener_tcpip: cannot listen to port: 5901", :bold, '#888888']}

#{password_prompt(session)}
EOF
        if public?(session)
          <<EOF
This desktop session is accessible from the public internet. However,
please be aware that desktop sessions accessed over the public
internet are not secure and steps should be taken to secure the link.

#{Paint["We highly recommend that you access your desktop session using 'ssh'
port forwarding",:underline]}:

  #{Paint["ssh -L 5901:localhost:#{session.port} #{ENV['USER']}@#{session.ip}",:green]}

#{general}
EOF
        elsif on_access_host?(session)
          <<EOF
This desktop session is not accessible from the public internet, but
may be directly accessible from within your local network or over a
virtual private network (VPN).

#{vnc_details(Config.access_ip, session, :yellow)}
However, #{Paint["we highly recommend that you access your desktop session using
'ssh' port forwarding",:underline]}:

  #{Paint["ssh -L 5901:#{session.ip}:#{session.port} #{ENV['USER']}@#{Config.access_host}",:green]}

#{general}
EOF
        else
          <<EOF
This desktop session is not directly accessible from outside of your
cluster as it is running on a machine that only provides internal
cluster access.  #{Paint["In order to access your desktop session you will need
to perform port forwarding using 'ssh'",:underline]}:

  #{Paint["ssh -L 5901:#{session.ip}:#{session.port} #{ENV['USER']}@#{Config.access_host}",:green]}

#{general}
EOF
        end
      end

      def generate_password
        if File.executable?('/usr/bin/apg')
          `/usr/bin/apg -n1 -M Ncl -m 8 -x 8`.chomp
        else
          SecureRandom.urlsafe_base64[0..7].tr('-_','fl')
        end
      end
    end
  end
end
