#!/system/bin/sh
# DSH Keep Alive control helper. All actions are called by webroot/app.js as root.
export PATH=/system/bin:/system/xbin:$PATH

if [ "${0%/*}" = "$0" ]; then
  MODDIR=$(pwd)
else
  MODDIR=${0%/*}
fi
CONF="$MODDIR/config.conf"
PKG=io.github.ccch1mneyyy.dsh_app
LOG=/sdcard/Download/DSH-Go/keepalive.log

mkdir -p /sdcard/Download/DSH-Go 2>/dev/null
touch "$LOG" 2>/dev/null
chmod 644 "$LOG" 2>/dev/null

log() { echo "$(date '+%F %T') $*" >> "$LOG" 2>/dev/null; }

defaults() {
  PHANTOM=1
  DOZE=1
  BATTERY=1
  SWIPE=1
  AUTOCHECK=1
  INTERVAL=300
  SHOW_ADVANCED=1
}

load() {
  defaults
  [ -f "$CONF" ] && . "$CONF"
  case "$INTERVAL" in
    ''|*[!0-9]*) INTERVAL=300 ;;
  esac
  [ "$INTERVAL" -lt 30 ] && INTERVAL=30
  [ "$INTERVAL" -gt 3600 ] && INTERVAL=3600
}

save_key() {
  k="$1"; v="$2"
  if [ -f "$CONF" ] && grep -q "^$k=" "$CONF"; then
    sed -i "s#^$k=.*#$k=$v#" "$CONF" 2>/dev/null
  else
    echo "$k=$v" >> "$CONF" 2>/dev/null
  fi
  chmod 644 "$CONF" 2>/dev/null
}

app_running() { pidof "$PKG" >/dev/null 2>&1; }
engine_running() { ps -A 2>/dev/null | grep -q '[l]ibproot\.so'; }

launch_app() {
  monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  if ! app_running; then
    ACT=$(cmd package resolve-activity --brief "$PKG" 2>/dev/null | tail -1)
    [ -n "$ACT" ] && am start -n "$ACT" >/dev/null 2>&1
  fi
}

apply_all() {
  load

  if [ "$PHANTOM" = "1" ]; then
    settings put global settings_enable_monitor_phantom_procs false >/dev/null 2>&1
    device_config put activity_manager max_phantom_processes 2147483647 >/dev/null 2>&1 \
      || cmd device_config put activity_manager max_phantom_processes 2147483647 >/dev/null 2>&1
  else
    settings put global settings_enable_monitor_phantom_procs true >/dev/null 2>&1
    device_config delete activity_manager max_phantom_processes >/dev/null 2>&1 \
      || cmd device_config delete activity_manager max_phantom_processes >/dev/null 2>&1
  fi

  if [ "$DOZE" = "1" ]; then
    dumpsys deviceidle whitelist +$PKG >/dev/null 2>&1
  else
    dumpsys deviceidle whitelist -$PKG >/dev/null 2>&1
  fi

  if [ "$BATTERY" = "1" ]; then
    cmd appops set "$PKG" RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1
    cmd appops set "$PKG" RUN_IN_BACKGROUND allow >/dev/null 2>&1
    am set-standby-bucket "$PKG" active >/dev/null 2>&1
  else
    cmd appops set "$PKG" RUN_ANY_IN_BACKGROUND default >/dev/null 2>&1
    cmd appops set "$PKG" RUN_IN_BACKGROUND default >/dev/null 2>&1
    am set-standby-bucket "$PKG" rare >/dev/null 2>&1
  fi

  if [ "$SWIPE" = "1" ]; then
    cmd appops set "$PKG" START_FOREGROUND allow >/dev/null 2>&1
    am set-inactive "$PKG" false >/dev/null 2>&1
  fi

  log "apply phantom=$PHANTOM doze=$DOZE battery=$BATTERY swipe=$SWIPE autocheck=$AUTOCHECK interval=$INTERVAL"
}

check_now() {
  load
  NOW=$(date +%s)
  if ! app_running; then
    launch_app
    log "manual check: app missing, launched"
    sleep 3
  fi
  if app_running && ! engine_running; then
    log "manual check: engine missing, force-stop + relaunch"
    am force-stop "$PKG" >/dev/null 2>&1
    sleep 2
    launch_app
    sleep 5
  fi
  echo "app=$(app_running && echo 1 || echo 0) engine=$(engine_running && echo 1 || echo 0) watchdog=$(watchdog_running && echo 1 || echo 0)"
}

watchdog_running() {
  [ -f "$MODDIR/watchdog.pid" ] || return 1
  WPID=$(cat "$MODDIR/watchdog.pid" 2>/dev/null)
  [ -n "$WPID" ] && kill -0 "$WPID" >/dev/null 2>&1
}

status_json() {
  load
  PH_SET=$(settings get global settings_enable_monitor_phantom_procs 2>/dev/null | head -1)
  MAX_PH=$(device_config get activity_manager max_phantom_processes 2>/dev/null | head -1)
  [ -z "$MAX_PH" ] && MAX_PH=$(cmd device_config get activity_manager max_phantom_processes 2>/dev/null | head -1)
  BUCKET=$(am get-standby-bucket "$PKG" 2>/dev/null | tail -1)
  DOZE_LISTED=0
  dumpsys deviceidle whitelist 2>/dev/null | grep -q "$PKG" && DOZE_LISTED=1
  APP=0; app_running && APP=1
  ENG=0; engine_running && ENG=1
  WD=0; watchdog_running && WD=1
  printf '{"phantom":%s,"doze":%s,"battery":%s,"swipe":%s,"autocheck":%s,"interval":%s,"showAdvanced":%s,"app":%s,"engine":%s,"watchdog":%s,"phantomSetting":"%s","maxPhantom":"%s","bucket":"%s","dozeListed":%s}' \
    "$PHANTOM" "$DOZE" "$BATTERY" "$SWIPE" "$AUTOCHECK" "$INTERVAL" "$SHOW_ADVANCED" \
    "$APP" "$ENG" "$WD" "$PH_SET" "$MAX_PH" "$BUCKET" "$DOZE_LISTED"
}

case "$1" in
  status)
    status_json
    ;;
  set)
    load
    key="$2"; val="$3"
    case "$key" in
      phantom) ckey=PHANTOM;;
      doze) ckey=DOZE;;
      battery) ckey=BATTERY;;
      swipe) ckey=SWIPE;;
      autocheck) ckey=AUTOCHECK;;
      interval) ckey=INTERVAL;;
      show_advanced) ckey=SHOW_ADVANCED;;
      *) echo "unknown key: $key" >&2; exit 2;;
    esac
    case "$key" in
      phantom|doze|battery|swipe|autocheck|show_advanced)
        [ "$val" = "1" ] && val=1 || val=0
        save_key "$ckey" "$val"
        ;;
      interval)
        case "$val" in ''|*[!0-9]*) val=300 ;; esac
        [ "$val" -lt 30 ] && val=30
        [ "$val" -gt 3600 ] && val=3600
        save_key "$ckey" "$val"
        ;;
      *)
        echo "unknown key: $key" >&2
        exit 2
        ;;
    esac
    [ "$key" != "show_advanced" ] && apply_all
    ;;
  apply)
    apply_all
    echo ok
    ;;
  check)
    check_now
    ;;
  launch)
    launch_app
    echo ok
    ;;
  log)
    tail -n 40 "$LOG" 2>/dev/null
    ;;
  *)
    echo "usage: control.sh status|set <key> <value>|apply|check|launch|log" >&2
    exit 2
    ;;
esac
