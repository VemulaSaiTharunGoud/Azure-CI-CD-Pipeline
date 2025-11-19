#!/bin/bash
set -e

APP_DIR="/opt/myapp"
PIDFILE="$APP_DIR/app.pid"
LOGFILE="$APP_DIR/out.log"

# Stop existing
if [ -f "$PIDFILE" ]; then
  oldpid=$(cat $PIDFILE) || true
  if ps -p $oldpid > /dev/null 2>&1; then
    kill $oldpid || true
    sleep 1
  fi
  rm -f "$PIDFILE"
fi

# Start
nohup node $APP_DIR/server.js > "$LOGFILE" 2>&1 & echo $! > "$PIDFILE"
echo "app started, pid=$(cat $PIDFILE)"
exit 0
