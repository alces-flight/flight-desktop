---
# Directories containing desktop type definitions
#type_paths:
#  - etc/types
# Directory containing global desktop verification state
#global_state_path: var/lib/desktop
# Directory containing log files from state operations
#global_log_path: var/log/desktop
# Global setting for default desktop type
#desktop_type: gnome
# Global setting for default geometry
#geometry: 1024x768
# Background image to use for (some) desktop types
#bg_image: etc/assets/backgrounds/default.jpg
# Host addresses or network ranges for machines to be considered
# "access hosts" i.e. hosts that can be logged into from outside the
# cluster
#access_hosts:
#  - 10.10.6.0/24
# A specific IP address that this specific machine can be accessed
# from externally to the cluster.
#access_ip: 192.168.56.101
# A hostname that can be used when logging into the cluster
# externally.
#access_host: mycluster.example.com
# Program to use for generating VNC passwords
#vnc_passwd_program: /usr/bin/vncpasswd
# Program to use to launch VNC sessions
#vnc_server_program: libexec/vncserver
# Whether the environment should be blanked when starting a desktop
# session.
#session_env_override: true
# The PATH to set when blanking the environment for a desktop session
#session_env_path: /usr/bin:/usr/sbin
