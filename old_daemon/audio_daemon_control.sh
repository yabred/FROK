#!/bin/bash

PLIST_NAME="com.user.keyclick.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"

case "$1" in
    start)
        if [ -f "$PLIST_PATH" ]; then
            launchctl load "$PLIST_PATH" 2>/dev/null || echo "Daemon may already be running"
            echo "Audio daemon started"
        else
            echo "ERROR: LaunchAgent not found. Run install_audio_daemon.sh first."
            exit 1
        fi
        ;;
    stop)
        if [ -f "$PLIST_PATH" ]; then
            launchctl unload "$PLIST_PATH" 2>/dev/null || echo "Daemon may not be running"
            echo "Audio daemon stopped"
        else
            echo "ERROR: LaunchAgent not found."
            exit 1
        fi
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        if launchctl list | grep -q "com.user.keyclick"; then
            echo "Audio daemon is running"
            echo ""
            echo "Recent logs:"
            echo "--- stdout ---"
            tail -n 5 /tmp/keyclick.log 2>/dev/null || echo "No log file"
            echo ""
            echo "--- stderr ---"
            echo "Error logging disabled (redirected to /dev/null)"
        else
            echo "Audio daemon is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac




