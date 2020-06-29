#!/bin/bash
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
set -e

if ! rpm -qa tigervnc-server-minimal | grep -q tigervnc-server-minimal ||
   ! rpm -qa xorg-x11-xauth | grep -q xorg-x11-xauth; then
  desktop_stage "Installing Flight Desktop prerequisites"
  yum -y install tigervnc-server-minimal xorg-x11-xauth
fi

if ! rpm -qa xorg-x11-server-utils | grep -q xorg-x11-server-utils; then
  desktop_stage "Installing package: xorg-x11-server-utils"
  yum -y install xorg-x11-server-utils
fi

if ! rpm -qa xterm | grep -q xterm; then
  desktop_stage "Installing package: xterm"
  yum -y install xterm
fi

desktop_stage "Prequisites met"
