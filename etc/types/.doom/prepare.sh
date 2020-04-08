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

if [ -f /etc/redhat-release ] && grep -q 'release 8' /etc/redhat-release; then
  distro=rhel8
fi

if ! rpm -qa tigervnc-server-minimal | grep -q tigervnc-server-minimal ||
   ! rpm -qa xorg-x11-xauth | grep -q xorg-x11-xauth; then
  desktop_stage "Installing Flight Desktop prerequisites"
  yum -y install tigervnc-server-minimal xorg-x11-xauth
fi

if ! rpm -qa xorg-x11-server-utils | grep -q xorg-x11-server-utils; then
  desktop_stage "Installing package: xorg-x11-server-utils"
  yum -y install xorg-x11-server-utils
fi

if ! rpm -qa gcc | grep -q gcc; then
  desktop_stage "Installing package: gcc"
  yum -y install gcc
fi

if [ "$distro" == "rhel8" ]; then
  if ! yum --enablerepo=epel --disablerepo=epel-* repolist | grep -q '^*epel'; then
    desktop_stage "Enabling repository: EPEL"
    yum -y install epel-release
    yum makecache
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
else
  if ! yum --enablerepo=epel --disablerepo=epel-* repolist | grep -q ^epel; then
    desktop_stage "Enabling repository: EPEL"
    yum -y install epel-release
    yum makecache
  fi
  if ! rpm -qa libpng12-devel | grep -q libpng12-devel; then
    desktop_stage "Installing package: libpng12-devel"
    yum -y install libpng12-devel
  fi
  CPPFLAGS=-I/usr/include/libpng12
fi

if ! rpm -qa SDL-devel | grep -q SDL-devel; then
  desktop_stage "Installing package: SDL-devel"
  yum -y install SDL-devel
fi

if ! rpm -qa SDL_net-devel | grep -q SDL_net-devel; then
  desktop_stage "Installing package: SDL_net-devel"
  yum --enablerepo=epel --disablerepo=epel-* -y install SDL_net-devel
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
