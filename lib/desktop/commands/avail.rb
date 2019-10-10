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
require_relative '../table'
require_relative '../type'

module Desktop
  module Commands
    class Avail < Command
      def run
        if $stdout.tty?
          if Type.all.empty?
            puts "No desktop types found."
          else
            word_wrap = method(:word_wrap)
            Table.emit do |t|
              headers 'Name', 'Summary', 'State'
              Type.each do |t|
                row Paint[t.name, :cyan],
                    word_wrap.call(
                      "#{Paint[t.summary, :green]}".tap do |s|
                        s << "\n > #{Paint[t.url, :blue, :bright, :underline]}\n " if t.url
                      end,
                      line_width: TTY::Screen.width - 30
                    ),
                    t.verified? ? 'Verified' : 'Unverified'
              end
            end
          end
        else
          Type.each do |t|
            puts [t.name, t.summary.chomp.gsub("\n"," "), t.url, t.verified? ? 'Verified' : 'Unverified'].join("\t")
          end
        end
      end

      def word_wrap(text, line_width: 80, break_sequence: "\n")
        text.split("\n").collect! do |line|
          line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1#{break_sequence}").strip : line
        end * break_sequence
      end
    end
  end
end
