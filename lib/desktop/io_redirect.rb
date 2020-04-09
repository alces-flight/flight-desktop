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

require 'stringio'

module Desktop
  IORedirect = Struct.new(:stdout, :stderr) do
    attr_reader :stdout, :stderr

    def initialize(*_)
      super
      @stdout ||= StringIO.new
      @stderr ||= StringIO.new
      raise <<~ERROR if stdout == STDOUT || stderr == STDERR
        Can not redirect to the default STDOUT or STDERR
      ERROR
    end

    def run
      old_stdout = $stdout
      old_stderr = $stderr
      $stdout = stdout
      $stderr = stderr
      yield if block_given?
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
      stdout.rewind
      stderr.rewind
    end
  end
end

