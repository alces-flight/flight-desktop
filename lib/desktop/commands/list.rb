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
require_relative '../command'
require_relative '../session'
require_relative '../table'

module Desktop
  module Commands
    class List < Command
      def run
        if $stdout.tty?
          if Session.all.empty?
            puts "No desktop sessions found."
          else
            session_to_array = method(:session_to_array)
            Table.emit do |t|
              headers 'Identity', 'Type', 'Host name', 'IP address', 'Display (Port)', 'Password', 'State'
              Session.each do |s|
                row(*session_to_array.call(s))
              end
            end
          end
        else
          Session.each do |s|
            a =
              if s.state == :broken
                [s.uuid].tap do |b|
                  b[8] = 'Broken'
                  b[9] = s.created_at&.strftime("%Y-%m-%dT%T%z")
                end
              else
                [
                  s.uuid,
                  s.type.name,
                  s.host_name,
                  s.ip,
                  s.display,
                  s.port,
                  s.websocket_port,
                  s.password,
                  s.local? ? (s.active? ? 'Active' : 'Exited') : 'Remote',
                  s.created_at.strftime("%Y-%m-%dT%T%z"),
                  s.last_accessed_at&.strftime("%Y-%m-%dT%T%z").to_s,
                  File.join(s.dir, 'session.png')
                ]
              end
            puts a.join("\t")
          end
        end
      end

      private
      def session_to_array(s)
        if s.state == :broken
          [
            (s.uuid.split('-').first rescue nil),
            '',
            '',
            '',
            '',
            '',
            'BROKEN'
          ]
        else
          [
            s.uuid.split('-').first,
            s.type.name,
            s.host_name,
            s.ip,
            ":#{s.display} (#{s.port})",
            s.password,
            s.local? ? (s.active? ? 'Active' : 'Exited') : 'Remote'
          ]
        end
      end
    end
  end
end
