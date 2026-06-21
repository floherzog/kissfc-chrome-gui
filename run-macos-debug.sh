#!/bin/sh
# Launch the built native-arm64 KISS GUI with logging enabled, so the app's
# console output (drone protocol, backup/restore messages, JS errors) is
# captured to a file for diagnosis.
#
# Usage: ./run-macos-debug.sh   then watch:  tail -f ~/kiss-gui-build/kiss-session.log

APP="$HOME/kiss-gui-build/out/KISS GUI.app"
LOG="$HOME/kiss-gui-build/kiss-session.log"

if [ ! -d "$APP" ]; then
    echo "Build first: ./build-macos-arm64.sh"; exit 1
fi

echo "Logging to: $LOG"
: > "$LOG"
# --enable-logging=stderr routes renderer console.log/console.error to stderr
# (look for lines containing CONSOLE).
"$APP/Contents/MacOS/nwjs" --enable-logging=stderr >"$LOG" 2>&1 &
echo "Launched (pid $!). Console output is being captured to the log above."
