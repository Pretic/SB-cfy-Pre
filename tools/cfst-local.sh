#!/usr/bin/env bash
set -euo pipefail

repo="XIU2/CloudflareSpeedTest"
work_dir="${CFST_DIR:-./cfst-local}"
tl="${CFST_TL:-200}"
dn="${CFST_DN:-20}"
output="${CFST_OUTPUT:-result.csv}"

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

need_cmd curl

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch_raw="$(uname -m)"
case "$arch_raw" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    i386|i686) arch="386" ;;
    armv7l) arch="armv7" ;;
    armv6l) arch="armv6" ;;
    armv5l) arch="armv5" ;;
    *) echo "Unsupported architecture: $arch_raw" >&2; exit 1 ;;
esac

mkdir -p "$work_dir"
cd "$work_dir"

if [ "$os" = "linux" ]; then
    need_cmd tar
    asset="cfst_linux_${arch}.tar.gz"
    archive="$asset"
    unpack() { tar -xzf "$archive"; }
elif [ "$os" = "darwin" ]; then
    need_cmd unzip
    asset="cfst_darwin_${arch}.zip"
    archive="$asset"
    unpack() { unzip -o -q "$archive"; }
else
    echo "Unsupported OS for this script: $os" >&2
    echo "Windows users should run tools/cfst-local.ps1 instead." >&2
    exit 1
fi

if [ ! -x ./cfst ]; then
    url="https://github.com/${repo}/releases/latest/download/${asset}"
    echo "Downloading official CloudflareSpeedTest release:"
    echo "  $url"
    curl -fL --retry 3 --connect-timeout 10 -o "$archive" "$url"
    unpack
    chmod +x ./cfst
fi

if [ "$#" -eq 0 ]; then
    set -- -tl "$tl" -dn "$dn" -o "$output"
fi

echo "Running: ./cfst $*"
./cfst "$@"

echo
echo "Result file: $(pwd)/${output}"
echo "Upload this file to your VPS, then choose menu 11 -> import local speed test result."
