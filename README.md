# Flight Desktop

Manage interactive GUI desktop sessions.

## Overview

Flight Desktop facilitates the creation of and access to
interactive GUI desktop sessions within HPC enviornments. A user may
select the type of desktop they wish to use and access it via the VNC
protocol.

## Installation

### From source

Flight Desktop requires a recent version of Ruby and `bundler`.

The following will install from source using `git`:

```
git clone https://github.com/alces-flight/flight-desktop.git
cd flight-desktop
bundle install --path=vendor
```

Use the script located at `bin/desktop` to execute the tool.

### Installing with Flight Runway

Flight Runway provides a Ruby environment and command-line helpers for
running openflightHPC tools.  Flight Desktop integrates with Flight
Runway to provide an easy way for multiple users of an
HPC environment to use the tool.

To install Flight Runway, see the [Flight Runway installation
docs](https://github.com/openflighthpc/flight-runway#installation).

These instructions assume that `flight-runway` has been installed from
the openflightHPC yum repository and that either [system-wide
integration](https://github.com/openflighthpc/flight-runway#system-wide-integration) has been enabled or the
[`flight-starter`](https://github.com/openflighthpc/flight-starter) tool has been
installed and the environment activated with the `flight start` command.

 * Enable the Alces Flight RPM repository:

    ```
    yum install https://repo.openflighthpc.org/openflight/centos/7/x86_64/openflighthpc-release-2-1.noarch.rpm
    ```

 * Rebuild your `yum` cache:

    ```
    yum makecache
    ```
    
 * Install the `flight-desktop` RPM:

    ```
    [root@myhost ~]# yum install flight-desktop
    ```

Flight Desktop is now available via the `flight` tool:

```
[root@myhost ~]# flight desktop
  NAME:

    flight desktop

  DESCRIPTION:

    Manage interactive GUI desktop sessions.

  COMMANDS:

    avail  Show available desktop types
    clean  Clean up one or more exited desktop sessions
    help   Display global or [command] help documentation
    <snip>
```

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

See the `help` command for further details and information about other commands.

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
