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
module Desktop
  class Error < RuntimeError
    def self.define_class(code)
      Class.new(self).tap do |klass|
        klass.instance_variable_set(:@exit_code, code)
      end
    end

    def self.exit_code
      @exit_code || begin
        parent.respond_to?(:exit_code) ? parent.exit_code : 2
      end
    end

    def exit_code
      self.class.exit_code
    end
  end

  SessionNotFoundError = Error.define_class(3)
  UnknownDesktopTypeError = Error.define_class(4)

  IncompleteTypeError = Error.define_class(5)
  UnverifiedTypeError = Error.define_class(6)
  InvalidSettingError = Error.define_class(7)

  SessionOperationError = Error.define_class(8)
  TypeOperationError = Error.define_class(9)
  InterruptedOperationError = Error.define_class(10)
end
