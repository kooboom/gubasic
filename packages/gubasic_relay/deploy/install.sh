#!/usr/bin/env bash
# Installs the GuBASIC relay server on a Linux server with systemd
# (docs/RELAY_SERVER.md): the executable in /opt/gubasic-relay, its
# settings in /etc/gubasic-relay/relay.yaml (kept when already there), a
# system user gubasic-relay, and the service gubasic-relay, started and
# started again with the computer. It listens on 127.0.0.1:7071, for
# Apache in front of it; the end shows the lines to add to Apache.
#
#   sudo ./install.sh                       # the latest release's executable
#   sudo ./install.sh --version v0.6.0      # a given release's
#   sudo ./install.sh --from-source DIR     # built here with Dart, from
#                                           # packages/gubasic_relay in DIR
#   sudo ./install.sh --uninstall           # removes it; keeps relay.yaml
#   sudo ./install.sh --uninstall --purge   # removes relay.yaml too
#
# Run it again with a newer version to update: the settings are kept.
set -euo pipefail

repo="kooboom/gubasic"
version=""
source_dir=""
uninstall=false
purge=false

while [ $# -gt 0 ]; do
  case "$1" in
    --version) version="${2:?--version needs a release, as v0.6.0}"; shift 2 ;;
    --from-source) source_dir="${2:?--from-source needs the repository folder}"; shift 2 ;;
    --uninstall) uninstall=true; shift ;;
    --purge) purge=true; shift ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: no option $1 (see --help)" >&2; exit 64 ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "install.sh: run it as root, with sudo" >&2
  exit 1
fi
command -v systemctl >/dev/null || {
  echo "install.sh: this needs systemd (systemctl)" >&2
  exit 1
}

here="$(cd "$(dirname "$0")" && pwd)"
bin_dir=/opt/gubasic-relay
etc_dir=/etc/gubasic-relay
unit=/etc/systemd/system/gubasic-relay.service

if $uninstall; then
  systemctl disable --now gubasic-relay 2>/dev/null || true
  rm -f "$unit"
  systemctl daemon-reload
  rm -rf "$bin_dir"
  if $purge; then
    rm -rf "$etc_dir"
  fi
  if id gubasic-relay >/dev/null 2>&1; then
    userdel gubasic-relay
  fi
  echo "The GuBASIC relay server is removed.$($purge || echo " Its settings stay in $etc_dir.")"
  exit 0
fi

# The executable: built here, or the release's for this processor.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
if [ -n "$source_dir" ]; then
  command -v dart >/dev/null || {
    echo "install.sh: --from-source needs Dart (https://dart.dev/get-dart)" >&2
    exit 1
  }
  (cd "$source_dir/packages/gubasic_relay" && dart pub get >/dev/null &&
    dart compile exe bin/gubasic_relay.dart -o "$work/gubasic-relay")
else
  case "$(uname -m)" in
    x86_64|amd64) arch=x64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "install.sh: no release for $(uname -m); use --from-source" >&2; exit 1 ;;
  esac
  if [ -z "$version" ]; then
    version="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" |
      sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)"
    [ -n "$version" ] || { echo "install.sh: cannot find the latest release" >&2; exit 1; }
  fi
  base="https://github.com/$repo/releases/download/$version"
  name="gubasic-relay-linux-$arch"
  echo "Downloading $name of $version"
  curl -fsSL -o "$work/$name" "$base/$name"
  curl -fsSL -o "$work/SHA256SUMS.txt" "$base/SHA256SUMS.txt"
  (cd "$work" && grep " $name\$" SHA256SUMS.txt | sha256sum -c -) || {
    echo "install.sh: the download does not match SHA256SUMS.txt" >&2
    exit 1
  }
  mv "$work/$name" "$work/gubasic-relay"
fi
"$work/gubasic-relay" --version

id gubasic-relay >/dev/null 2>&1 ||
  useradd --system --no-create-home --shell /usr/sbin/nologin gubasic-relay
install -d -m 755 "$bin_dir" "$etc_dir"
systemctl stop gubasic-relay 2>/dev/null || true
install -m 755 "$work/gubasic-relay" "$bin_dir/gubasic-relay"
if [ ! -f "$etc_dir/relay.yaml" ]; then
  install -m 644 "$here/relay.yaml.example" "$etc_dir/relay.yaml"
  echo "Wrote $etc_dir/relay.yaml: put your app's address in allowedOrigins."
else
  echo "Kept $etc_dir/relay.yaml."
fi
install -m 644 "$here/gubasic-relay.service" "$unit"
systemctl daemon-reload
systemctl enable --now gubasic-relay

# Is it there?
for _ in $(seq 1 25); do
  if curl -fsS http://127.0.0.1:7071/room/health >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done
if ! curl -fsS http://127.0.0.1:7071/room/health; then
  echo
  echo "install.sh: the service does not answer; see journalctl -u gubasic-relay" >&2
  exit 1
fi
echo
cat <<APACHE

The relay server runs on 127.0.0.1:7071. Put Apache in front of it, with
your server's name instead of relay.example.com (the whole file:
$here/apache-relay.conf.example):

    sudo a2enmod ssl proxy proxy_http
    # in the <VirtualHost *:443> of relay.example.com:
    ProxyPass        "/room" "http://127.0.0.1:7071/room" upgrade=websocket
    ProxyPassReverse "/room" "http://127.0.0.1:7071/room"
    ProxyTimeout 300

Then check from anywhere:

    curl https://relay.example.com/room/health

and set Room.Server in your app to wss://relay.example.com/room.
APACHE
