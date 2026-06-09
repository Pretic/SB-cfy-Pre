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

print_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file"
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file"
    else
        echo "sha256 unavailable: install sha256sum or shasum to verify $file"
    fi
}

install_cfst() {
    local url="$1" asset="$2" extract_cmd="$3"
    local tmp_dir extract_dir archive cfst_bin

    tmp_dir="$(mktemp -d)"
    CFST_TMP_DIR="$tmp_dir"
    trap 'rm -rf "$CFST_TMP_DIR"' EXIT
    extract_dir="${tmp_dir}/extract"
    archive="${tmp_dir}/${asset}"
    mkdir -p "$extract_dir"

    echo "Downloading official CloudflareSpeedTest release:"
    echo "  $url"
    curl -fL --retry 3 --connect-timeout 10 --proto '=https' --tlsv1.2 -o "$archive" "$url"
    print_sha256 "$archive"

    case "$extract_cmd" in
        tar) tar -xzf "$archive" -C "$extract_dir" ;;
        unzip) unzip -o -q "$archive" -d "$extract_dir" ;;
        *) echo "Unsupported extract command: $extract_cmd" >&2; rm -rf "$tmp_dir"; exit 1 ;;
    esac

    cfst_bin="$(find "$extract_dir" -type f -name cfst | head -n 1)"
    if [ -z "$cfst_bin" ]; then
        echo "cfst binary not found in downloaded archive." >&2
        rm -rf "$tmp_dir"
        exit 1
    fi

    cp "$cfst_bin" ./cfst
    chmod 0755 ./cfst
    print_sha256 ./cfst
    rm -rf "$tmp_dir"
    CFST_TMP_DIR=""
    trap - EXIT
}

if [ "${CFST_ALLOW_ROOT:-0}" != "1" ] && [ "$(id -u 2>/dev/null || echo 1)" = "0" ]; then
    echo "Refusing to run as root. Run as a normal local user, or set CFST_ALLOW_ROOT=1 to override." >&2
    exit 1
fi

need_cmd curl
need_cmd find
need_cmd mktemp

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
    extractor="tar"
elif [ "$os" = "darwin" ]; then
    need_cmd unzip
    asset="cfst_darwin_${arch}.zip"
    extractor="unzip"
else
    echo "Unsupported OS for this script: $os" >&2
    echo "Windows users should run tools/cfst-local.ps1 instead." >&2
    exit 1
fi

if [ ! -x ./cfst ]; then
    install_cfst "https://github.com/${repo}/releases/latest/download/${asset}" "$asset" "$extractor"
else
    print_sha256 ./cfst
fi

if [ "$#" -eq 0 ]; then
    set -- -tl "$tl" -dn "$dn" -o "$output"
fi

echo "Running: ./cfst $*"
./cfst "$@"

echo
echo "Result file: $(pwd)/${output}"
echo "Upload this file to your VPS, then choose menu 11 -> import local speed test result."
