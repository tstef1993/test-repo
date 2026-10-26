#!/usr/bin/env bash
# Install Custom Home onto a ROOTED webOS TV (Homebrew Channel present).
#
# This does two things:
#   1. copies + installs the app .ipk
#   2. installs the autostart script into /var/lib/webosbrew/init.d/
#
# Prereqs on the TV:
#   - Rooted via RootMyTV, Homebrew Channel installed
#   - SSH enabled (Homebrew Channel > Settings > "SSH") — root login over port 22
#
# Usage:
#   TV_HOST=192.168.1.50 ./scripts/install.sh
#   TV_HOST=192.168.1.50 TV_PORT=22 ./scripts/install.sh
#
# If you use key auth, point SSH_OPTS at your key, e.g.
#   SSH_OPTS="-i ~/.ssh/id_tv" TV_HOST=... ./scripts/install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${TV_HOST:?set TV_HOST=<tv-ip>}"
TV_PORT="${TV_PORT:-22}"
TV_USER="${TV_USER:-root}"
SSH_OPTS="${SSH_OPTS:-}"
IPK="$(ls -1 "$ROOT"/dist/*.ipk 2>/dev/null | head -n1 || true)"
AUTOSTART_SRC="$ROOT/autostart/webosbrew-autostart.sh"
AUTOSTART_DST="/var/lib/webosbrew/init.d/30-custom-home.sh"

ssh_tv()  { ssh $SSH_OPTS -p "$TV_PORT" "$TV_USER@$TV_HOST" "$@"; }
scp_tv()  { scp $SSH_OPTS -P "$TV_PORT" "$1" "$TV_USER@$TV_HOST:$2"; }

if [ -z "$IPK" ]; then
  echo " No .ipk found in dist/. Run ./scripts/build-ipk.sh first." >&2
  exit 1
fi

echo "==> Copying app package to TV"
scp_tv "$IPK" "/tmp/customhome.ipk"

echo "==> Installing app"
# Install the ipk via the dev install service. If it fails, the package is
# still at /tmp/customhome.ipk and can be installed from the Homebrew Channel app.
INSTALL_JSON='{"id":"com.tstef.customhome","ipkUrl":"/tmp/customhome.ipk","subscribe":false}'
# Wrap the JSON in single quotes so the TV's login shell passes it as one arg.
INSTALL_CMD="luna-send -n 1 -w 60000 -f luna://com.webos.appInstallService/dev/install '$INSTALL_JSON'"
ssh_tv "$INSTALL_CMD" \
  || echo "  (if that failed, install /tmp/customhome.ipk from the Homebrew Channel app)"

echo "==> Installing autostart script to $AUTOSTART_DST"
ssh_tv "mkdir -p /var/lib/webosbrew/init.d"
scp_tv "$AUTOSTART_SRC" "$AUTOSTART_DST"
ssh_tv "chmod +x '$AUTOSTART_DST'"

echo "==> Verifying"
ssh_tv "ls -l '$AUTOSTART_DST'"

cat <<EOF

Done.

Final step (once, on the TV):
  Open the Homebrew Channel app and enable "Run startup scripts".

Then reboot the TV. Check the log over SSH if it doesn't appear:
  tail -n 50 /var/log/custom-home-autostart.log

To test the launch without rebooting:
  ssh ${TV_USER}@${TV_HOST} 'sh $AUTOSTART_DST'
EOF
