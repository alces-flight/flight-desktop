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
require_relative '../type'
require_relative '../io_redirect'

module Desktop
  module Commands
    class Verify < Command
      def run
        if json?
          IORedirect.new.run { run_verify }
          puts type.to_json
        else
          run_verify
        end
      end

      private

      def run_verify
        if options.force
          type.verify(force: true)
        elsif type.verified?
          $stderr.puts <<~MSG
            Desktop type #{Paint[type.name, :cyan]} has already been verified.
          MSG
          true
        else
          type.verify(force: false)
        end
      end

      def type
        @type ||= Type[args[0]]
      end
    end
  end
end
