#!/system/bin/sh
# SukiSU/KernelSU module: DSH Go Keep Alive (late_start service)
export PATH=/system/bin:/system/xbin:$PATH

PKG=io.github.ccch1mneyyy.dsh_app
MODDIR=/data/adb/modules/dsh_keepalive
CONF="$MODDIR/config.conf"
LOGDIR=/sdcard/Download/DSH-Go
LOG=$LOGDIR/keepalive.log

mkdir -p "$LOGDIR" 2>/dev/null
chmod 755 "$LOGDIR" 2>/dev/null
touch "$LOG" 2>/dev/null
chmod 644 "$LOG" 2>/dev/null

log() { echo "$(date '+%F %T') $*" >> "$LOG" 2>/dev/null; }

log "service.sh start"

# Default config for fresh installs; the WebUI rewrites this file.
if [ ! -f "$CONF" ]; then
  cat > "$CONF" <<'EOF'
STRATEGY=auto
PHANTOM=1
DOZE=1
BATTERY=1
SWIPE=1
AUTOCHECK=1
INTERVAL=300
SHOW_ADVANCED=1
EOF
  chmod 644 "$CONF" 2>/dev/null
fi

# Apply current toggles once at boot.
sh "$MODDIR/control.sh" apply >> "$LOG" 2>&1

# Kill every previous watchdog whose cmdline points at this module; the pid
# file can be stale after a crash or a manual service run.
OLD=$(cat "$MODDIR/watchdog.pid" 2>/dev/null)
if [ -n "$OLD" ] && [ -r "/proc/$OLD/cmdline" ] && tr '\0' ' ' < "/proc/$OLD/cmdline" | grep -q "dsh_keepalive"; then
  kill "$OLD" 2>/dev/null
fi
ps -A -o PID,ARGS 2>/dev/null | while read -r pid args; do
  case "$args" in
    *dsh_keepalive*)
      case "$args" in
        *service.sh*|*control.sh*|*uninstall.sh*) ;;
        *) [ "$pid" != "$$" ] && kill "$pid" 2>/dev/null ;;
      esac ;;
  esac
done

# Detached watchdog; reads config.conf every loop so WebUI changes take effect.
setsid /system/bin/sh -c '
  PKG=io.github.ccch1mneyyy.dsh_app
  MODDIR=/data/adb/modules/dsh_keepalive
  CONF=$MODDIR/config.conf
  LOG=/sdcard/Download/DSH-Go/keepalive.log
  PIDFILE=$MODDIR/watchdog.pid
  echo $$ > "$PIDFILE"
  log() { echo "$(date "+%F %T") $*" >> "$LOG" 2>/dev/null; }
  launch() {
    monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    if ! pidof "$PKG" >/dev/null 2>&1; then
      ACT=$(cmd package resolve-activity --brief "$PKG" 2>/dev/null | tail -1)
      [ -n "$ACT" ] && am start -n "$ACT" >/dev/null 2>&1
    fi
  }
  # Under tawcroot the loader may not appear in ps; the engine listening
  # socket is the reliable signal. 0C08 = 3080.
  port_open() {
    for f in /proc/net/tcp /proc/net/tcp6; do
      [ -r "$f" ] || continue
      while read -r line; do
        case "$line" in
          *":0C08 "*" 0A "*) return 0 ;;
        esac
      done < "$f"
    done
    return 1
  }
  has_tawcroot() { ps -A -o NAME 2>/dev/null | grep -q "tawcroot"; }
  has_proot() { ps -A -o NAME 2>/dev/null | grep -q "proot"; }
  backend() {
    if has_tawcroot; then
      echo tawcroot
    elif has_proot; then
      echo proot
    elif port_open; then
      echo auto
    else
      echo none
    fi
  }
  engine_running() {
    if port_open; then return 0; fi
    case "$STRATEGY" in
      proot) has_proot ;;
      tawcroot) has_tawcroot ;;
      *) has_tawcroot || has_proot ;;
    esac
  }
  strategy_mismatch() {
    BE=$(backend)
    [ "$STRATEGY" != "auto" ] && [ "$BE" != "none" ] && [ "$BE" != "auto" ] && [ "$BE" != "$STRATEGY" ]
  }
  APP_START=$(date +%s)
  log "watchdog started pid=$$"
  while true; do
    STRATEGY=auto; PHANTOM=1; DOZE=1; BATTERY=1; SWIPE=1; AUTOCHECK=1; INTERVAL=300; SHOW_ADVANCED=1
    [ -f "$CONF" ] && . "$CONF"
    case "$STRATEGY" in
      auto|proot|tawcroot) ;;
      *) STRATEGY=auto ;;
    esac
    case "$INTERVAL" in ""|*[!0-9]*) INTERVAL=300 ;; esac
    [ "$INTERVAL" -lt 30 ] && INTERVAL=30
    [ "$INTERVAL" -gt 3600 ] && INTERVAL=3600
    if [ "$AUTOCHECK" = "1" ]; then
      NOW=$(date +%s)
      if ! pidof "$PKG" >/dev/null 2>&1; then
        launch
        APP_START=$NOW
        log "watchdog relaunch app strategy=$STRATEGY"
      elif [ $((NOW - APP_START)) -gt 180 ] && ! engine_running; then
        if strategy_mismatch; then
          log "engine missing but strategy mismatch strategy=$STRATEGY backend=$(backend), skip restart"
        else
          log "engine missing strategy=$STRATEGY backend=$(backend), force-stop and relaunch"
          am force-stop "$PKG" >/dev/null 2>&1
          sleep 2
          launch
          APP_START=$NOW
        fi
      fi
    fi
    sleep "$INTERVAL"
  done
' >/dev/null 2>&1 < /dev/null &

sleep 1
log "watchdog spawned pid=$(cat "$MODDIR/watchdog.pid" 2>/dev/null)"
