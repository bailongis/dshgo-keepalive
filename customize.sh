#!/system/bin/sh
# Upgrade helper: keep config.conf (not shipped in the zip) and stop the old
# watchdog so the new service can take over after the module is installed.
ps -A -o PID,ARGS 2>/dev/null | while read -r pid args; do
  case "$args" in
    *dsh_keepalive*)
      case "$args" in
        *customize.sh*|*service.sh*|*control.sh*|*uninstall.sh*) ;;
        *) kill "$pid" 2>/dev/null ;;
      esac ;;
  esac
done
