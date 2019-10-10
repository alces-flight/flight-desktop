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
set_policies() {
  local group=$1
  # disable authentication prompts for admin users
  mkdir -p /etc/polkit-1/localauthority/10-vendor.d
  cat <<EOF > /etc/polkit-1/localauthority/10-vendor.d/20-flight-desktop-gnome.pkla
[Flight Desktop - disable create color managed device auth prompt for admins]
Identity=unix-group:${group}
Action=org.freedesktop.color-manager.create-device
ResultAny=yes
ResultInactive=yes
ResultActive=yes

[Flight Desktop - disable network proxy auth prompt for admins]
Identity=unix-group:${group}
Action=org.freedesktop.packagekit.system-network-proxy-configure
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF
}

if ! [ -f /etc/polkit-1/localauthority/10-vendor.d/20-flight-desktop-gnome.pkla ]; then
  policy_group=wheel
  if [ "${policy_group}" ]; then
    desktop_stage "Setting up polkit policies"
    set_policies "${policy_group}"
  fi
fi

contains() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

IFS=$'\n' groups=(
  $(
    yum grouplist hidden | \
      sed '/^Installed Groups:/,$!d;/^Available Groups:/,$d;/^Installed Groups:/d;s/^[[:space:]]*//'
  )
)

if ! contains 'X Window System' "${groups[@]}"; then
  desktop_stage "Installing package group: X Window System"
  yum -e0 -y groupinstall 'X Window System'
fi

if ! contains 'Fonts' "${groups[@]}"; then
  desktop_stage "Installing package group: Fonts"
  yum -e0 -y groupinstall 'Fonts'
fi

if ! contains 'GNOME' "${groups[@]}"; then
  desktop_stage "Installing package group: GNOME"
  yum -e0 -y groupinstall 'GNOME'
fi

if ! rpm -qa evince | grep -q evince; then
  desktop_stage "Installing package: evince"
  yum -e0 -y install evince
fi

if ! rpm -qa firefox | grep -q firefox; then
  desktop_stage "Installing package: firefox"
  yum -e0 -y install firefox
fi

if rpm -qa gnome-packagekit; then
  desktop_stage "Removing package: gnome-packagekit"
  yum -e0 -y remove gnome-packagekit
fi

desktop_stage "Prequisites met"
