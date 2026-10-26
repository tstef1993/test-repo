#!/bin/sh
# ---------------------------------------------------------------------------
# Custom Home autostart  -  launches our custom launcher on every boot.
#
# The Homebrew Channel runs every executable script in
#   /var/lib/webosbrew/init.d/
# at boot, as root, WHEN the "Run startup scripts" toggle is enabled in the
# Homebrew Channel app. This script waits for the TV UI to come up and then
# brings the custom home app to the foreground.
#
# Install target:
#   /var/lib/webosbrew/init.d/30-custom-home.sh   (chmod +x)
# ---------------------------------------------------------------------------

APP_ID="com.tstef.customhome"
LOG="/var/log/custom-home-autostart.log"
APPMGR="luna://com.webos.applicationManager"

# Max time to wait for the UI (seconds) before giving up.
MAX_WAIT=90
# How long the app must stay foreground before we consider it "settled".
SETTLE=3

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG" 2>/dev/null; }

log "=== autostart start (pid $$) for $APP_ID ==="

# ---- 1. Wait until applicationManager answers --------------------------------
i=0
while [ "$i" -lt "$MAX_WAIT" ]; do
  if luna-send -n 1 -w 2000 -f "$APPMGR/getForegroundAppInfo" '{}' 2>/dev/null \
       | grep -q '"returnValue":true'; then
    log "applicationManager is up after ${i}s"
    break
  fi
  i=$((i + 2))
  sleep 2
done

if [ "$i" -ge "$MAX_WAIT" ]; then
  log "WARN applicationManager never became ready within ${MAX_WAIT}s; launching anyway"
fi

# Small extra grace so we land ON TOP of the stock boot app, not under it.
sleep 4

# ---- 2. Launch + verify, retry a few times -----------------------------------
attempt=1
while [ "$attempt" -le 5 ]; do
  log "launch attempt $attempt"
  luna-send -n 1 -w 5000 -f "$APPMGR/launch" \
    "{\"id\":\"$APP_ID\",\"params\":{\"autostart\":true}}" >> "$LOG" 2>&1

  sleep "$SETTLE"

  FG="$(luna-send -n 1 -w 3000 -f "$APPMGR/getForegroundAppInfo" '{}' 2>/dev/null)"
  if echo "$FG" | grep -q "\"appId\":\"$APP_ID\""; then
    log "SUCCESS $APP_ID is foreground"
    exit 0
  fi

  log "not foreground yet (got: $(echo "$FG" | grep -o '"appId":"[^"]*"' | head -n1))"
  attempt=$((attempt + 1))
  sleep 3
done

log "ERROR gave up after $((attempt - 1)) attempts"
exit 1
