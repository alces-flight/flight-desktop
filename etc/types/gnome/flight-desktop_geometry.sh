current_geometry=$(xrandr -q | awk -F 'current' -F',' 'NR==1 {gsub("( |current)",""); print $2}')
desired="${flight_DESKTOP_geometry:-1024x768}"
if [ "$current_geometry" != "$desired" ] ; then
    if ! xrandr -q | tail -n+3 | grep -q "$desired"; then
      desired="1024x768"
    fi
    xrandr --output VNC-0 --mode $desired
fi
