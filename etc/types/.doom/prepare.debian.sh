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
set -e

if ! apt -qq --installed list tigervnc-common | grep -q tigervnc-common ||
    ! apt -qq --installed list xauth | grep -q xauth; then
  desktop_stage "Installing Flight Desktop prerequisites"
  apt -y install tigervnc-common xauth
fi

if ! apt -qq --installed list x11-xserver-utils | grep -q x11-xserver-utils; then
  desktop_stage "Installing package: x11-xserver-utils"
  apt -y install x11-xserver-utils
fi

if ! apt -qq --installed list gcc | grep -q gcc; then
  desktop_stage "Installing package: gcc"
  apt -y install gcc
fi

if ! apt -qq --installed list zlib1g-dev | grep -q zlib1g-dev; then
  desktop_stage "Installing package: zlib1g-dev"
  apt -y install zlib1g-dev
fi

if ! apt -qq --installed list make | grep -q make; then
  desktop_stage "Installing package: make"
  apt -y install make
fi

if [ ! -f "${flight_ROOT}/opt/libpng12/lib/libpng12.so" ]; then
  desktop_stage "Installing source package: libpng12"
  d="$(mktemp -d /tmp/flight-desktop.XXXXXXXX)"
  curl -o "${d}/libpng-1.2.59.tar.gz" \
       -L https://downloads.sourceforge.net/project/libpng/libpng12/1.2.59/libpng-1.2.59.tar.gz
  pushd "${d}"
  tar xzf libpng-1.2.59.tar.gz
  cd libpng-1.2.59
  ./configure --prefix="${flight_ROOT}/opt/libpng12"
  make
  make install
  popd
  rm -rf "$d"
fi
CPPFLAGS="-I${flight_ROOT}/opt/libpng12/include"

if ! apt -qq --installed list libsdl1.2-dev | grep -q libsdl1.2-dev; then
  desktop_stage "Installing package: libsdl1.2-dev"
  apt -y install libsdl1.2-dev
fi

if [ ! -x "${flight_ROOT}/opt/prboom/games/prboom" ]; then
  desktop_stage "Installing source package: prboom"
  d="$(mktemp -d /tmp/flight-desktop.XXXXXXXX)"
  curl -o "${d}/prboom-2.5.0.tar.gz" \
       -L https://downloads.sourceforge.net/project/prboom/prboom%20stable/2.5.0/prboom-2.5.0.tar.gz
  pushd "${d}"
  tar xzf prboom-2.5.0.tar.gz
  cd prboom-2.5.0
  ./configure CPPFLAGS="$CPPFLAGS" --prefix="${flight_ROOT}/opt/prboom"
  make
  make install
  popd
  rm -rf "$d"
fi

if [ ! -f "${flight_ROOT}/opt/prboom/share/games/doom/doom1.wad" ]; then
  desktop_stage "Installing asset: doom1.wad"
  curl -o "${flight_ROOT}/opt/prboom/share/games/doom/doom1.wad" \
       -L http://distro.ibiblio.org/pub/linux/distributions/slitaz/sources/packages/d/doom1.wad
fi

desktop_stage "Prequisites met"
