# Flight Desktop

Manage interactive GUI desktop sessions.

## Overview

Flight Desktop facilitates the creation of and access to
interactive GUI desktop sessions within HPC enviornments. A user may
select the type of desktop they wish to use and access it via the VNC
protocol.

## Installation

### Installing with OpenFlight `yum` Repos

The installation of Flight Desktop and the Flight User Suite is documented in [the OpenFlight Documentation](https://use.openflighthpc.org/en/latest/installing-user-suite/install.html#installing-flight-user-suite).

### Manual Installation

#### Prerequisites

Flight Desktop requires a recent version of Ruby (2.5+) and `bundler`.

Also, a VNC password program is required at `/usr/bin/vncpasswd`. For example, this can be provided by `tigervnc-server`.

#### Steps

The following will install from source using `git`:

```
git clone https://github.com/alces-flight/flight-desktop.git
cd flight-desktop
bundle install --path=vendor
```

Use the script located at `bin/desktop` to execute the tool.

## Configuration

Making changes to the default configuration is optional and can be achieved by creating a `config.yml` file in the `etc/` subdirectory of the tool.  A `config.yml.ex` file is distributed which outlines all the configuration values available:

 * `desktop_type` - Global setting for default desktop type (defaults to `gnome`).
 * `geometry` - Global setting for default geometry (defaults to `1024x768`).
 * `bg_image` - background image to use for (some) desktop types.
 * `access_hosts` - array of host addresses/network ranges for machines considered to be "access hosts", i.e. hosts that can be logged into from outside the cluster (for e.g. login nodes).
 * `access_host` - hostname to use to SSH into the cluster when accessing externally.
 * `access_ip` - IP address of the machine on which Flight Desktop is installed that can be used to access it from external locations (only applies to designated "access hosts" and will default to the IP address of interface with the public route).
 * `vnc_passwd_program` - program to use to generate VNC passwords (defaults to `/usr/bin/vncpasswd`).
 * `vnc_server_program` - program to use to start VNC sessions (must be Flight Desktop compatible, defaults to `libexec/vncserver` within Flight Desktop tree).

## Operation

Display the range of available desktop types using the `avail` command.

Verify that desktop type prerequisites are met using the `verify` command. If  they are not, use the `prepare` command to fulfil the prequisites and mark
the desktop type as verified -- note that superuser (root) access is
required to execute the `prepare` command as it will need to install
distribution packages.

Once verified, a user can start a desktop session with the `start` command.

Access desktop sessions using a VNC client as instructed by the output
from the `start` and `show` commands.

See the `help` command for further details and information about other commands. Further information and examples of the `env` command are available in [the OpenFlight documentation](https://use.openflighthpc.org/en/latest/working-with-user-suite/flight-desktop.html).

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
