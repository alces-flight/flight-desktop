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
xdg_cache_home() {
    echo "${XDG_CACHE_HOME:-$HOME/.cache}"
}

xdg_config_home() {
    echo "${XDG_CONFIG_HOME:-$HOME/.config}"
}

xdg_config_dirs() {
    echo "${XDG_CONFIG_DIRS:-/etc/xdg}"
}

xdg_config_search() {
    xdg_search "$(xdg_config_home):$(xdg_config_dirs)" "$@"
}

xdg_data_home() {
    echo "${XDG_DATA_HOME:-$HOME/.local/share}"
}

xdg_data_dirs() {
    echo "${XDG_DATA_DIRS:-/usr/local/share/:/usr/share/}"
}

xdg_data_search() {
    xdg_search "$(xdg_data_home):$(xdg_data_dirs)" "$@"
}

xdg_search() {
    local haystack_paths xdg_dirs
    haystack_paths="$1"
    needle="$2"
    fn="$3"
    shift
    IFS=: read -a xdg_dirs <<< "${haystack_paths}"
    xdg_find_needle "$needle" "$fn" "${xdg_dirs[@]}"
}

xdg_find_needle() {
    local a needle fn
    needle="$1"
    fn="$2"
    shift 2
    for a in "$@"; do
        if [ -e "${a}"/"${needle}" ]; then
            if [ "$fn" ]; then
                $fn "${a}"/"${needle}"
            else
                echo "${a}"/"${needle}"
            fi
            return 0
        fi
    done
    return 1
}

# 'Xterm*vt100.pointerMode: 0' is to ensure that the pointer does not
# disappear when a user types into the xterm.  In this situation, some
# VNC clients experience a 'freeze' due to a bug with handling
# invisible mouse pointers (e.g. OSX Screen Sharing).
echo 'XTerm*vt100.pointerMode: 0' | xrdb -merge
vncconfig -nowin &

xsetroot -solid '#081f2e'

# Use different directory for each display, otherwise cannot have multiple
# Chrome sessions running at same time as Chrome will detect it is already
# running and open a new tab in the existing session (see
# http://superuser.com/a/491360).
destdir="$(xdg_cache_home)/google-chrome/session${DISPLAY}"
if [ ! -d "${destdir}" ]; then
    mkdir -p "${destdir}"
    touch "${destdir}/First Run"
fi

geometry="${flight_DESKTOP_geometry:-1024x768}"
window_size="$(echo "${geometry}" | sed 's/x/,/' )"

google-chrome \
    --window-position=0,0 \
    --window-size="${window_size}" \
    --user-data-dir="${destdir}"
