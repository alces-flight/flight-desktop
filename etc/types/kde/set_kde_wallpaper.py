#!/usr/bin/env python
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
import sys
import dbus
from PyKDE4 import kdecore

wallpaper_path = sys.argv[1]
konf_path = '%s/.kde/share/config/plasma-desktop-appletsrc' % (sys.argv[2])
print('Patching %s' % konf_path)
activity_manager = dbus.SessionBus().get_object(
    'org.kde.ActivityManager', '/ActivityManager/Activities')
current_activity_id = dbus.Interface(
    activity_manager, 'org.kde.ActivityManager.Activities').CurrentActivity()
konf = kdecore.KConfig(konf_path, kdecore.KConfig.SimpleConfig)
containments = konf.group('Containments')
for group_name in containments.groupList():
    group = containments.group(group_name)
    # http://api.kde.org/pykde-4.7-api/kdecore/KConfigGroup.html
    if (group.readEntry('activity') == 'Desktop' and
            group.readEntry('activityId') == current_activity_id):
        group.group('Wallpaper').group('image').writeEntry('wallpaper', wallpaper_path)
        print wallpaper_path
