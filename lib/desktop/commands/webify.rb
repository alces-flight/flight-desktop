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
require_relative '../command_utils'
require_relative '../config'
require_relative '../errors'
require_relative '../session'
require_relative '../type'

require 'whirly'

module Desktop
  module Commands
    class Webify < Command
      def run
        if session.active?
          puts "Starting web access support for desktop session #{Paint[session.uuid, :magenta]}:\n\n"
          status_text = Paint["Starting web access support", '#2794d8']
          print "   > "
          begin
            Whirly.start(
              spinner: 'star',
              remove_after_stop: true,
              append_newline: false,
              status: status_text
            )
            success = session.start_web_support_services
            Whirly.stop
          rescue
            puts "\u274c #{status_text}\n\n"
            raise
          end
          puts "#{success ? "\u2705" : "\u274c"} #{status_text}\n\n"
        elsif session.local?
          raise SessionOperationError, "session #{session.uuid} is not active"
        else
          raise SessionOperationError, "session #{session.uuid} is not local"
        end
      end

      private
      def uuid
        @uuid ||= args[0][0] == ':' ? nil : args[0]
      end

      def display
        @display ||= args[0][0] == ':' ? args[0][1..-1] : nil
      end

      def session
        @session ||=
          if uuid
            Session[uuid]
          else
            Session.find_by_display(display) ||
              raise(SessionNotFoundError, "no local active session found for display :#{display}")
          end
      end
    end
  end
end
