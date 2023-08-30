# Flight Desktop

Manage interactive GUI desktop sessions.

## Overview

Flight Desktop facilitates the creation of and access to
interactive GUI desktop sessions within HPC enviornments. A user may
select the type of desktop they wish to use and access it via the VNC
protocol.

## Installation

### Installing with the OpenFlight package repos

Flight Desktop is available as part of the *Flight User Suite*.  This is the
easiest method for installing Flight Desktop and all its dependencies.  It is
documented in [the OpenFlight
Documentation](https://docs.openflighthpc.org/2023.5/flight-environment/use-flight/flight-user-suite/flight-desktop/).

### Manual Installation

#### Prerequisites

Flight Desktop is developed and tested with Ruby version `2.7.1` and `bundler`
`2.1.4`.  Other versions may work but currently are not officially supported.

Also, a VNC password program is required at `/usr/bin/vncpasswd`. For example,
this can be provided by `tigervnc-server`.  See the configuration section
below for details on how to use a different path.

#### Steps

The following will install from source using `git`.  The `master` branch is
the current development version and may not be appropriate for a production
installation. Instead a tagged version should be checked out.

```
git clone https://github.com/alces-flight/flight-desktop.git
cd flight-desktop
git checkout <tag>
bundle config set --local with default
bundle config set --local without test
bundle install
```

Use the script located at `bin/desktop` to execute the tool.

## Configuration

Making changes to the default configuration is optional and can be achieved by
creating a `config.yml` file in the `etc/` subdirectory of the tool.  A
`config.yml.ex` file is distributed which outlines all the configuration
values available:

 * `desktop_type` - Global setting for default desktop type (defaults to
   `gnome`).
 * `geometry` - Global setting for default geometry (defaults to `1024x768`).
 * `bg_image` - background image to use for (some) desktop types.
 * `access_hosts` - array of host addresses/network ranges for machines
   considered to be "access hosts", i.e. hosts that can be logged into from
   outside the cluster (for e.g. login nodes).
 * `access_host` - hostname to use to SSH into the cluster when accessing
   externally.
 * `access_ip` - IP address of the machine on which Flight Desktop is
   installed that can be used to access it from external locations (only
   applies to designated "access hosts" and will default to the IP address of
   interface with the public route).
 * `vnc_passwd_program` - program to use to generate VNC passwords (defaults
   to `/usr/bin/vncpasswd`).
 * `vnc_server_program` - program to use to start VNC sessions (must be Flight
   Desktop compatible, defaults to `libexec/vncserver` within Flight Desktop
   tree).

## Operation

A brief usage guide is given below.  See the `help` command for further
details and information about other commands.

Display the range of available desktop types using the `avail` command.

Verify that desktop type prerequisites are met using the `verify` command. If
they are not, use the `prepare` command to fulfil the prequisites and mark the
desktop type as verified -- note that superuser (root) access is required to
execute the `prepare` command as it will need to install distribution
packages.

Once verified, a user can start a desktop session with the `start` command.

Access desktop sessions using a VNC client as instructed by the output
from the `start` and `show` commands.

If Flight Desktop was installed via the OpenFlight package repos, you can read
more detailed usage instructions by running `flight howto show flight
desktop`.  Further information and examples of the `desktop` command are
available in [the OpenFlight
documentation](https://docs.openflighthpc.org/2023.5/flight-environment/use-flight/flight-user-suite/flight-desktop/).

# Contributing

Fork the project. Make your feature addition or bug fix. Send a pull
request. Bonus points for topic branches.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

# Copyright and License

Eclipse Public License 2.0, see [LICENSE.txt](LICENSE.txt) for details.

Copyright (C) 2019-present Alces Flight Ltd.

This program and the accompanying materials are made available under
the terms of the Eclipse Public License 2.0 which is available at
[https://www.eclipse.org/legal/epl-2.0](https://www.eclipse.org/legal/epl-2.0),
or alternative license terms made available by Alces Flight Ltd -
please direct inquiries about licensing to
[licensing@alces-flight.com](mailto:licensing@alces-flight.com).

Flight Desktop is distributed in the hope that it will be
useful, but WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER
EXPRESS OR IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR
CONDITIONS OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR
A PARTICULAR PURPOSE. See the [Eclipse Public License 2.0](https://opensource.org/licenses/EPL-2.0) for more
details.
