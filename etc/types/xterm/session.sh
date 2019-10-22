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
xsetroot -fg '#2794d8' -bitmap <(
cat <<EOF
#define root_weave_width 4
#define root_weave_height 4
static char root_weave_bits[] = {
   0x07, 0x0d, 0x0b, 0x0e};
EOF
)
xterm
