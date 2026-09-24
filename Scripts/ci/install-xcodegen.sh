#!/usr/bin/env bash
set -euo pipefail

install_root="${1:?Usage: install-xcodegen.sh INSTALL_ROOT}"
xcodegen_version="2.46.0"
xcodegen_sha256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"
archive="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/xcodegen-${xcodegen_version}.zip"

mkdir -p "$install_root"
curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 \
	--max-time 180 \
	"https://github.com/yonaskolb/XcodeGen/releases/download/${xcodegen_version}/xcodegen.zip" \
	--output "$archive"
printf '%s  %s\n' "$xcodegen_sha256" "$archive" | shasum --algorithm 256 --check
unzip -oq "$archive" -d "$install_root/extracted"
cp -R "$install_root/extracted/xcodegen/" "$install_root/"
"$install_root/bin/xcodegen" version
