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
require_relative '../session_finder'

module Desktop
  module Commands
    class Clean < Command
      include Concerns::SessionFinder

      def run
        if session
          clean(session)
        else
          if Session.all.empty?
            puts "No desktop sessions found."
          else
            Session.each do |s|
              clean(s)
            end
          end
        end
      end

      private

      def clean(target)
        if !target.local?
          puts "#{target.uuid}: skipping; not local"
        elsif !target.active?
          if target.clean
            puts "#{target.uuid}: cleaned"
          else
            puts "#{target.uuid}: cleaning failed"
          end
        else
          puts "#{target.uuid}: skipping; currently active"
        end
      end
    end
  end
end
