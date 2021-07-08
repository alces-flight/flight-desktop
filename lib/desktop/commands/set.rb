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
require_relative '../config'
require_relative '../errors'

module Desktop
  module Commands
    class Set < Command
      def run
        if args.any?
          if options.global && !File.writable?(Flight.config.class.global_config)
            raise InvalidSettingError, "permission denied for updating global defaults"
          end
          updates = []
          args.each do |a|
            k, v = a.split('=')
            raise InvalidSettingError, "missing value: #{a}" if v.nil?
            case k
            when 'desktop'
              updates << lambda do
                Type.set_default(v, global: options.global)
              end
            when 'geometry'
              updates << lambda do
                Config.set_geometry(v, global: options.global)
              end
            else
              raise InvalidSettingError, "unrecognized setting: #{k}"
            end
          end
          updates.each(&:call)
        end
        # TODO: These will be wrong after the update
        puts "Default desktop type: #{Type.default.name}"
        puts "    Default geometry: #{Config.geometry}"
      end
    end
  end
end
