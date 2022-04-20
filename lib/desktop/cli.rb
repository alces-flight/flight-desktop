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
require_relative 'commands'
require_relative 'version'

require 'tty/reader'
require 'commander'
require 'erb'
require_relative 'patches/geometry_option'

module Desktop
  module CLI
    PROGRAM_NAME = ENV.fetch('FLIGHT_PROGRAM_NAME','desktop')
    APP_TYPES = Type.all.values.select { |t| File.exist?(t.launch_app_path) }
                    .map(&:name).join(',')
    SCRIPT_TYPES = Type.all.values.select { |t| t.scriptable?}.map(&:name).join(',')

    extend Commander::CLI
    program :application, "Flight Desktop"
    program :name, PROGRAM_NAME
    program :version, "v#{Desktop::VERSION}"
    program :description, 'Manage interactive GUI desktop sessions.'
    program :help_paging, false
    default_command :help

    if [/^xterm/, /rxvt/, /256color/].all? { |regex| ENV['TERM'] !~ regex }
      Paint.mode = 0
    end

    class << self
      def cli_syntax(command, args_str = nil)
        command.syntax = [
          PROGRAM_NAME,
          command.name,
          args_str
        ].compact.join(' ')
      end
    end

    command :avail do |c|
      cli_syntax(c)
      c.summary = 'Show available desktop types'
      c.action Commands, :avail
      c.description = <<EOF
Display a list of available desktop types.

Desktop types marked 'Verified' are available for use, while those
marked 'Unverified' must have their prequisites verified using the
'verify' command before they can be used.  If prerequisites are not
met, the superuser must prepare the desktop type using the 'prepare'
command to make the desktop type available for use.
EOF
    end
    alias_command :av, :avail

    command :clean do |c|
      cli_syntax(c, '[DESKTOP]')
      c.summary = 'Clean up one or more exited desktop sessions'
      c.action Commands, :clean
      c.description = <<EOF
Remove one or more desktop session directories for exited desktop
sessions.

Depending on how cleanly desktop sessions exit, the session directory
may be retained until and require manual cleaning.  Desktops that are
cleanly exited or manually terminated using the 'kill' command are
automatically cleaned.

You may specify the optional DESKTOP parameter either as a session
identity or a display number prefixed with ':', e.g. ':1'.  If no
DESKTOP is specified, data for all sessions that are marked as
'exited' will be removed.
EOF
    end

    command :doctor do |c|
      cli_syntax(c)
      c.summary = 'Perform diagnostics and display results'
      c.action Commands, :doctor
      c.slop.bool '--json', 'Output machine readable response in JSON format'
      c.description = <<EOF
Perform a series of diagnostics regarding available functionality and
display the results.

Tests will be made to determine the availability of required and
optional dependencies.
EOF
    end

    command :show do |c|
      cli_syntax(c, 'DESKTOP')
      c.summary = 'Show information about a desktop session'
      c.action Commands, :show
      c.description = <<EOF
Display the details of a desktop session, including the desktop type,
the host name and IP address that may be used to access the session,
the X11 display number, the VNC port number, and the password required
to access the session.

The DESKTOP parameter should either specify the session identity or
a display number prefixed with ':', e.g. ':1'.
EOF
    end

    command :list do |c|
      cli_syntax(c)
      c.summary = 'List interactive desktop sessions'
      c.action Commands, :list
      c.description = <<EOF
Display a table containing all known desktop sessions and their
states.

If accessed without a terminal (e.g. piped to 'grep') the table is
delimited with tabs and does not have a header, facilitating the use
of standard UNIX tools with the session data.
EOF
    end
    alias_command :ls, :list

    command :kill do |c|
      cli_syntax(c, 'DESKTOP')
      c.summary = 'Terminate an interactive desktop session'
      c.action Commands, :kill
      c.description = <<EOF
Instruct an active interactive desktop session to terminate.

The DESKTOP parameter should either specify the session identity or
a display number prefixed with ':', e.g. ':1'.
EOF
    end
    alias_command :k, :kill

    APP_DESC = ERB.new(<<~TEMPLATE, nil, '-').result(binding).chomp
Launch the given graphical application in the session.  Multiple applications
can be started by repeating the --app flag.
<% if APP_TYPES.empty? -%>

Not supported by any install desktop types!
<% else -%>
Supported by: #{APP_TYPES}
<% end -%>
TEMPLATE

    SCRIPT_DESC = ERB.new(<<~TEMPLATE, nil, '-').result(binding).chomp
Run the given script in a suitable terminal inside the session.  Only a single
script can be ran.

<%  if SCRIPT_TYPES.empty? -%>

Not supported by any installed desktop types!
<%  else -%>
Supported by: #{SCRIPT_TYPES}
<%  end -%>
TEMPLATE

    command :start do |c|
      cli_syntax(c, '[TYPE]')
      c.summary = 'Start an interactive desktop session'
      c.action Commands, :start
      c.slop.string '-n', '--name', "Give the desktop session a name so it can be more easily identified.", meta: 'NAME'
      c.slop.geometry '-g', '--geometry', 'Desktop geometry.', meta: 'WIDTHxHEIGHT', default: Config.geometry
      c.slop.bool '--override-env', "Blank the session environment (unset with --no-override-env).", default: !!Config.session_env_override
      c.slop.array '-a', '--app', APP_DESC, delimiter: nil, meta: '"BINARY [ARGUMENTS...]"'
      c.slop.string '-s', '--script', SCRIPT_DESC, delimiter: nil, meta: '"SCRIPT [ARGUMENTS...]"'
      c.slop.bool '--kill-on-script-exit', "Exit the desktop session when the script given by --script exits."
      c.description = <<EOF
Start a new interactive desktop session and display details about the
new session.

By default the TYPE started will be '#{Type.default.name}', which can be overridden
by specifying the desktop TYPE argument.

The default geometry for sessions is #{Config.geometry}, which can be
overridden by specifying the '--geometry' parameter.  The value should
be specified in <width>x<height> format, e.g. 1280x1024.

Available desktop types can be shown using the 'avail' command.
EOF
    end
    alias_command :s, :start
    alias_command :st, :start

    command :webify do |c|
      cli_syntax(c, 'DESKTOP')
      c.summary = 'Start web access support for an active desktop session'
      c.action Commands, :webify
      c.description = <<EOF
Start required and optional web support programs for an active interactive
desktop session.

The DESKTOP parameter should either specify the session identity or
a display number prefixed with ':', e.g. ':1'.
EOF
    end
    alias_command :web, :webify

    command :set do |c|
      cli_syntax(c, '[NAME=VALUE...]')
      c.summary = 'Set or display default settings'
      c.action Commands, :set
      c.slop.bool '-g', '--global', 'Set global default'
      c.description = <<EOF
Update or display current defaults.

If no arguments are specified, the current defaults are displayed.

Specify arguments as NAME=VALUE pairs to update default settings. Available
settings are:

   desktop - default desktop type for 'start' with no argument
  geometry - default geometry to use for desktops

EOF
    end

    if Process.euid == 0
      command :prepare do |c|
        cli_syntax(c, 'TYPE')
        c.summary = 'Prepare a desktop type for use'
        c.action Commands, :prepare
        c.slop.bool '-f', '--force', 'Prepare even if type has already been verified.'
        c.description = <<EOF
Prepare a desktop type for use on this system.  This command is only
available to the superuser as installing prerequisites for a desktop
type requires permission to install distribution packages

Specify '--force' to perform preparation even if the desktop type has
already been verified.

Available desktop types can be shown using the 'avail' command.
EOF
      end
    end

    command :verify do |c|
      cli_syntax(c, 'TYPE')
      c.summary = 'Verify prerequisites are met for a desktop type'
      c.action Commands, :verify
      c.slop.bool '-f', '--force', 'Verify even if type has already been verified.'
      c.description = <<EOF
Verify that a desktop type can be used on this system.  Desktop types
must be verified before they can be used to ensure that their
prerequisites are met.

If prerequisites are met, then the desktop type is marked as verified
and may be used. If prequisites are found to be missing, the superuser
must prepare the desktop type using the 'prepare' command to make the
desktop available for use.

Specify '--force' to perform verification even if the desktop type has
already been verified.

Available desktop types can be shown using the 'avail' command.
EOF
    end
  end
end
