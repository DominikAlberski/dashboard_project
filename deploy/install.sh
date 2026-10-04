#!/bin/sh
# Installs the LAN dashboard as a launchd daemon on the device.
#
# Run this script ON the device, from a copy of the repository:
#   sh /var/root/dashboard_client/deploy/install.sh
#
# The script copies the program to /var/mobile/dashboard and installs the
# daemon. The daemon serves http://127.0.0.1:8081/ at every boot. Safari on
# the device needs no computer and no terminal.
#
# The agent URL and port live in deploy/com.dominikalberski.dashboard.plist.
# One reboot is necessary after the first install: launchctl cannot reach
# launchd from an SSH session.
#
# Stop the daemon:
#   launchctl unload -w /Library/LaunchDaemons/com.dominikalberski.dashboard.plist
# Start it again:
#   launchctl load -w /Library/LaunchDaemons/com.dominikalberski.dashboard.plist

set -e

LABEL=com.dominikalberski.dashboard
SOURCE=$(cd "$(dirname "$0")/.." && pwd)
TARGET=/var/mobile/dashboard
PLIST=/Library/LaunchDaemons/$LABEL.plist

echo "source: $SOURCE"
echo "target: $TARGET"

mkdir -p "$TARGET"
cp -R "$SOURCE/bin" "$SOURCE/deploy" "$TARGET/"
cp "$SOURCE/api.rb" "$SOURCE/page.rb" "$SOURCE/serve.rb" "$TARGET/"
cp "$SOURCE/deploy/$LABEL.plist" "$PLIST"
chown -R mobile:mobile "$TARGET"
chown root:wheel "$PLIST"
chmod 644 "$PLIST"

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load -w "$PLIST" 2>/dev/null || true
sleep 2

if ruby --disable-gems -rsocket -e 'TCPSocket.new("127.0.0.1", 8081).close' 2>/dev/null
then
  echo "the daemon is running: http://127.0.0.1:8081/"
  exit 0
fi

echo "the daemon is installed, but this shell cannot start it."
echo "launchctl cannot reach launchd from an SSH session."
echo "Reboot the device one time. The daemon starts at every boot:"
echo "  reboot"
