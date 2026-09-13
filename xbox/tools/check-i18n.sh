#!/usr/bin/env bash
# i18n check for the Xbox extension.
#
#   tools/check-i18n.sh            # static coverage check + compile catalogs
#   tools/check-i18n.sh --runtime  # additionally verify gettext in a nested GNOME Shell
#
# The runtime check launches a throw-away nested GNOME Shell with XBOX_I18N_CHECK=1,
# which makes the extension itself log a few translated samples.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME=0
[[ "${1:-}" == "--runtime" ]] && RUNTIME=1

cd "$REPO"

echo "== static coverage =="
python3 tools/extract-i18n.py

echo "== compile catalogs =="
make -s locales

if [[ "$RUNTIME" -eq 0 ]]; then
    echo "done (static). pass --runtime to also check inside GNOME Shell."
    exit 0
fi

command -v gnome-shell >/dev/null || { echo "gnome-shell not found"; exit 1; }

XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
TMP="$(mktemp -d /tmp/xbox-i18n-check.XXXXXX)"
BUS_PID=""
SHELL_PID=""

# Isolated config/data so the check never touches the user's real
# dconf extension lists or installed extensions.
export XDG_CONFIG_HOME="$TMP/config"
export XDG_DATA_HOME="$TMP/data"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME/gnome-shell/extensions"
ln -sfn "$REPO" "$XDG_DATA_HOME/gnome-shell/extensions/xbox"

cleanup() {
    [[ -n "$SHELL_PID" ]] && kill "$SHELL_PID" 2>/dev/null || true
    [[ -n "$BUS_PID" ]] && kill "$BUS_PID" 2>/dev/null || true
    rm -rf "$TMP"
    rm -f "$XDG_RUNTIME_DIR/gnome-shell-disable-extensions"
}
trap cleanup EXIT

check_locale() {
    local lang="$1" expected="$2" tag="$3"
    local base="$TMP/$tag"
    mkdir -p "$base"

    dbus-daemon --session --fork --print-address=1 --print-pid=1 > "$base/bus.info"
    BUS_PID="$(sed -n 2p "$base/bus.info")"
    local addr
    addr="$(sed -n 1p "$base/bus.info")"

    rm -f "$XDG_RUNTIME_DIR/gnome-shell-disable-extensions"
    env DBUS_SESSION_BUS_ADDRESS="$addr" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        LANG="$lang" LC_ALL="$lang" LANGUAGE= XBOX_I18N_CHECK=1 \
        nohup gnome-shell --nested --wayland > "$base/shell.log" 2>&1 &
    SHELL_PID=$!
    sleep 13

    env DBUS_SESSION_BUS_ADDRESS="$addr" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        gnome-extensions enable xbox >/dev/null 2>&1 || true
    sleep 2

    local line
    line="$(grep -m1 'xbox:i18n' "$base/shell.log" || true)"

    kill "$SHELL_PID" 2>/dev/null || true; SHELL_PID=""
    kill "$BUS_PID" 2>/dev/null || true; BUS_PID=""
    sleep 1

    if [[ -z "$line" ]]; then
        echo "FAIL [$tag] no 'xbox:i18n' line in $base/shell.log"
        tail -n 20 "$base/shell.log" || true
        return 1
    fi
    echo "$line"
    if [[ "$line" != *"$expected"* ]]; then
        echo "FAIL [$tag] expected to contain: $expected"
        return 1
    fi
    echo "PASS [$tag]"
}

check_locale "zh_CN.UTF-8" "Show Overview => 显示总览" zh
check_locale "en_US.UTF-8" "Show Overview => Show Overview" en
echo "runtime i18n check OK"
