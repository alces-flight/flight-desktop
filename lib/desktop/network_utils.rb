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
require 'ipaddr'

module Desktop
  module NetworkUtils
    PRIVATE_IPS = [
      IPAddr.new('10.0.0.0/8'),
      IPAddr.new('172.16.0.0/12'),
      IPAddr.new('192.168.0.0/16'),
    ].freeze

    class << self
      def private_ip?(ip_address)
        if ip_address.is_a?(String)
          ip_address = IPAddr.new(ip_address)
        end
        PRIVATE_IPS.any? { |private_ip| private_ip.include?(ip_address) }
      end

      def primary_ip
        @primary_ip ||= `#{Flight.root}/libexec/get-primary-ip`.chomp
      end

      def reachable?(port)
        `#{Config.root}/libexec/reachable #{port}`.chomp == 'true'
      end

      def access_host?(ip)
        ip_addr = IPAddr.new(ip)
        Config.access_hosts.any? do |h|
          IPAddr.new(h).include?(ip_addr)
        end
      end
    end
  end
end
