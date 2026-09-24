#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEAM_ID="P8T2366K8X"
ASC_PROFILE="${ASC_PROFILE:-}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build/macos-release-$(date +%Y%m%d%H%M%S)}"
ARCHIVE_PATH="$OUTPUT_DIR/XcodeMini.xcarchive"
EXPORT_DIR="$OUTPUT_DIR/export"
APP_PATH="$EXPORT_DIR/Xcode Mini.app"

if [[ -z "$ASC_PROFILE" ]]; then
	echo "Set ASC_PROFILE to the App Store Connect API profile authorized for notarization." >&2
	exit 2
fi

if ! security find-identity -v -p codesigning | grep -F "Developer ID Application:" | grep -F "($TEAM_ID)" >/dev/null; then
	echo "No Developer ID Application identity for team $TEAM_ID is installed in the keychain." >&2
	exit 2
fi

mkdir -p "$OUTPUT_DIR"

xcodebuild archive \
	-project "$ROOT_DIR/XcodeMini.xcodeproj" \
	-scheme XcodeMini \
	-configuration Release \
	-destination "generic/platform=macOS" \
	-archivePath "$ARCHIVE_PATH" \
	CODE_SIGNING_ALLOWED=YES \
	CODE_SIGN_STYLE=Manual \
	CODE_SIGN_IDENTITY="Developer ID Application" \
	DEVELOPMENT_TEAM="$TEAM_ID" \
	ENABLE_HARDENED_RUNTIME=YES

xcodebuild -exportArchive \
	-archivePath "$ARCHIVE_PATH" \
	-exportPath "$EXPORT_DIR" \
	-exportOptionsPlist "$ROOT_DIR/ExportOptions-DeveloperID.plist"

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
ZIP_PATH="$OUTPUT_DIR/XcodeMini-$APP_VERSION-macos-notarized.zip"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -E '^(Authority|Timestamp)='

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
xcrun asc --profile "$ASC_PROFILE" notarization submit --file "$ZIP_PATH" --wait

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
rm "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Notarized release ZIP: $ZIP_PATH"
