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
    class Start < Command

      def run
        assert_functional
        success = if !type.verified?
          raise UnverifiedTypeError, "Desktop type '#{type.name}' has not been verified"
        elsif json?
          start
        else
          puts "Starting a '#{Paint[type.name, :cyan]}' desktop session:\n\n"
          status_text = Paint["Starting session", '#2794d8']
          print "   > "
          begin
            Whirly.start(
              spinner: 'star',
              remove_after_stop: true,
              append_newline: false,
              status: status_text
            )
            start.tap do |s|
              Whirly.stop
              puts "#{s ? "\u2705" : "\u274c"} #{status_text}\n\n"
            end
          rescue
            puts "\u274c #{status_text}\n\n"
            raise
          end
        end
        if success && json?
          puts session.to_json
        elsif success
          puts "A '#{Paint[type.name, :cyan]}' desktop session has been started."
          CommandUtils.emit_details(session, :access_summary)
        else
          raise SessionOperationError, "unable to start session"
        end
      end

      private

      def start
        session.start(geometry: @options.geometry || Config.geometry)
      end

      def type
        @type ||= (args[0] && Type[args[0]]) || Type.default
      end

      def session
        @session ||= Session.new(type: type)
      end

      def assert_functional
        if !Config.functional?
          raise SessionOperationError, "system-level prerequisites not present"
        end
      end
    end
  end
end
