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
if ! apt -qq --installed list tigervnc-common | grep -q tigervnc-common; then
  desktop_miss 'Package: tigervnc-common'
fi
if ! apt -qq --installed list xauth | grep -q xauth; then
  desktop_miss 'Package: xauth'
fi

desktop_stage "Package: x11-xserver-utils"
if ! apt -qq --installed list x11-xserver-utils | grep -q x11-xserver-utils; then
  desktop_miss 'Package: x11-xserver-utils'
fi

desktop_stage "Package: xterm"
if ! apt -qq --installed list xterm | grep -q xterm; then
  desktop_miss 'Package: xterm'
fi
