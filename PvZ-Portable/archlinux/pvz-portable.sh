#!/usr/bin/env sh

# Default to Wayland SDL video driver if running in a Wayland session and $SDL_VIDEODRIVER is not set
if [ -n "$WAYLAND_DISPLAY" ] && [ -z "$SDL_VIDEODRIVER" ]; then
    export SDL_VIDEODRIVER="wayland,x11"
fi

exec /usr/share/pvz-portable/pvz-portable "$@"
