#!/bin/bash
# =============================================================================
# Copyright (C) 2020-present Alces Flight Ltd.
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
desktop_stage "Flight Desktop prerequisites"
if ! rpm -qa tigervnc-server-minimal | grep -q tigervnc-server-minimal; then
  desktop_miss 'Package: tigervnc-server-minimal'
fi
if ! rpm -qa xorg-x11-xauth | grep -q xorg-x11-xauth; then
  desktop_miss 'Package: xorg-x11-xauth'
fi

desktop_stage "Package: xorg-x11-server-utils"
if ! rpm -qa xorg-x11-server-utils | grep -q xorg-x11-server-utils; then
  desktop_miss 'Package: xorg-x11-server-utils'
fi

desktop_stage "Source package: prboom"
if [ ! -x "${flight_ROOT}/opt/prboom/games/prboom" ]; then
  desktop_miss "Source package: prboom"
fi

desktop_stage "Asset: doom1.wad"
if [ ! -f "${flight_ROOT}/opt/prboom/share/games/doom/doom1.wad" ]; then
  desktop_miss "Asset: doom1.wad"
fi
