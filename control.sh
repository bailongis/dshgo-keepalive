#!/system/bin/sh
# DSH Go Keep Alive control helper. All actions are called by webroot/app.js as root.
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
  STRATEGY=auto
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
  case "$STRATEGY" in
    auto|proot|tawcroot) ;;
    *) STRATEGY=auto ;;
  esac
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

# Under tawcroot the loader may not appear in ps at all, while the engine is
# still serving 127.0.0.1:3080. Check the listening socket first, then fall
# back to process names. 0C08 = 3080.
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
  else
    cmd appops set "$PKG" START_FOREGROUND default >/dev/null 2>&1
    am set-inactive "$PKG" true >/dev/null 2>&1
  fi

  log "apply strategy=$STRATEGY backend=$(backend) phantom=$PHANTOM doze=$DOZE battery=$BATTERY swipe=$SWIPE autocheck=$AUTOCHECK interval=$INTERVAL"
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
    if strategy_mismatch; then
      log "manual check: strategy mismatch strategy=$STRATEGY backend=$(backend), skip restart"
    else
      log "manual check: engine missing strategy=$STRATEGY backend=$(backend), force-stop + relaunch"
      am force-stop "$PKG" >/dev/null 2>&1
      sleep 2
      launch_app
      sleep 5
    fi
  fi
  echo "app=$(app_running && echo 1 || echo 0) engine=$(engine_running && echo 1 || echo 0) backend=$(backend) watchdog=$(watchdog_running && echo 1 || echo 0) strategy=$STRATEGY"
}

watchdog_running() {
  [ -f "$MODDIR/watchdog.pid" ] || return 1
  WPID=$(cat "$MODDIR/watchdog.pid" 2>/dev/null)
  [ -n "$WPID" ] && kill -0 "$WPID" >/dev/null 2>&1
}

status_json() {
  load
  BE=$(backend)
  MATCH=1
  [ "$STRATEGY" = "auto" ] || [ "$BE" = "auto" ] || [ "$STRATEGY" = "$BE" ] || MATCH=0
  PH_SET=$(settings get global settings_enable_monitor_phantom_procs 2>/dev/null | head -1)
  MAX_PH=$(device_config get activity_manager max_phantom_processes 2>/dev/null | head -1)
  [ -z "$MAX_PH" ] && MAX_PH=$(cmd device_config get activity_manager max_phantom_processes 2>/dev/null | head -1)
  BUCKET=$(am get-standby-bucket "$PKG" 2>/dev/null | tail -1)
  DOZE_LISTED=0
  dumpsys deviceidle whitelist 2>/dev/null | grep -q "$PKG" && DOZE_LISTED=1
  APP=0; app_running && APP=1
  ENG=0; engine_running && ENG=1
  WD=0; watchdog_running && WD=1
  printf '{"strategy":"%s","backend":"%s","strategyMatch":%s,"phantom":%s,"doze":%s,"battery":%s,"swipe":%s,"autocheck":%s,"interval":%s,"showAdvanced":%s,"app":%s,"engine":%s,"watchdog":%s,"phantomSetting":"%s","maxPhantom":"%s","bucket":"%s","dozeListed":%s}' \
    "$STRATEGY" "$BE" "$MATCH" "$PHANTOM" "$DOZE" "$BATTERY" "$SWIPE" "$AUTOCHECK" "$INTERVAL" "$SHOW_ADVANCED" \
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
      strategy) ckey=STRATEGY;;
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
      strategy)
        case "$val" in
          auto|proot|tawcroot) ;;
          *) echo "invalid strategy: $val" >&2; exit 2 ;;
        esac
        save_key "$ckey" "$val"
        ;;
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
    tail -n 60 "$LOG" 2>/dev/null
    ;;
  *)
    echo "usage: control.sh status|set <key> <value>|apply|check|launch|log" >&2
    exit 2
    ;;
esac
