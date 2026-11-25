#!/system/bin/sh
MODDIR=/data/adb/modules/dsh_keepalive
if [ -f "$MODDIR/watchdog.pid" ]; then
  kill "$(cat "$MODDIR/watchdog.pid")" 2>/dev/null
  rm -f "$MODDIR/watchdog.pid"
fi
# The pid file can be stale; also stop any watchdog still holding this path.
ps -A -o PID,ARGS 2>/dev/null | while read -r pid args; do
  case "$args" in
    *dsh_keepalive*)
      case "$args" in
        *uninstall.sh*) ;;
        *) kill "$pid" 2>/dev/null ;;
      esac ;;
  esac
done
