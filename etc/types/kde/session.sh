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
# 'Xterm*vt100.pointerMode: 0' is to ensure that the pointer does not
# disappear when a user types into the xterm.  In this situation, some
# VNC clients experience a 'freeze' due to a bug with handling
# invisible mouse pointers (e.g. OSX Screen Sharing).
echo 'XTerm*vt100.pointerMode: 0' | xrdb -merge
vncconfig -nowin &

if which startkde &>/dev/null; then
  startkde &
  kdepid=$!
elif which startplasma-x11 &>/dev/null; then
  startplasma-x11 &
  kdepid=$!
else
  echo "Unable to find KDE starter"
  exit 1
fi
bg_image="${flight_DESKTOP_bg_image:-${flight_DESKTOP_root}/etc/assets/backgrounds/default.jpg}"
if [ -f "${bg_image}" ]; then
  if [ -f /etc/redhat-release ] && grep -q 'release 7' /etc/redhat-release; then
    while [ ! -f ~/.kde/share/config/plasma-desktop-appletsrc ]; do
      sleep 1
    done
    echo "Sleeping [1/3]..."
    sleep 5
    python "${flight_DESKTOP_root}"/etc/types/kde/set_kde_wallpaper.py "$bg_image" "$HOME"
    echo "Sleeping [2/3]..."
    sleep 2
    kquitapp plasma-desktop
    echo "Sleeping [3/3]..."
    sleep 2
    kstart plasma-desktop
  else
    sleep 5
    dbus-send --session --dest=org.kde.plasmashell \
              --type=method_call /PlasmaShell \
              org.kde.PlasmaShell.evaluateScript \
              'string:
                var Desktops = desktops();
                for (i=0;i<Desktops.length;i++) {
                  d = Desktops[i];
                  d.wallpaperPlugin = "org.kde.image";
                  d.currentConfigGroup = Array("Wallpaper",
                                               "org.kde.image",
                                               "General");
                  d.writeConfig("Image", "file://'$bg_image'");
                }'
  fi
fi
wait $kdepid
