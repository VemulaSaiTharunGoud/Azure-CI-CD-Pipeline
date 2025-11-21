#!/bin/bash
set -e

APP_DIR="/opt/myapp"
PIDFILE="$APP_DIR/app.pid"
LOGFILE="$APP_DIR/out.log"

# Kill any node process from current AND previous deployment
pkill -f "/opt/myapp/server.js" || true
pkill -f "/opt/myapp_prev/server.js" || true
sleep 1

# Remove old PID file
rm -f "$PIDFILE"

# Start new app
nohup node $APP_DIR/server.js > "$LOGFILE" 2>&1 & echo $! > "$PIDFILE"
echo "app started, pid=$(cat $PIDFILE)"
exit 0
