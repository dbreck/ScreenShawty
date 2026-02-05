#!/bin/bash
set -euo pipefail

# ScreenShawty Release Build Script
# Builds, signs, notarizes, and packages the app into a DMG for distribution.
#
# Usage:
#   ./scripts/build-release.sh
#
# Prerequisites:
#   - Apple Developer ID Application certificate in Keychain
#   - App Store Connect API key stored in notarytool keychain profile "ScreenShawty"
#     Set it up once with:
#       xcrun notarytool store-credentials "ScreenShawty" \
#         --apple-id YOUR_APPLE_ID \
#         --team-id 7DMXWUCLVN \
#         --password APP_SPECIFIC_PASSWORD

APP_NAME="ScreenShawty"
SCHEME="ScreenShawty"
PROJECT="ScreenShawty.xcodeproj"
BUNDLE_ID="com.clearph.screenshawty"
TEAM_ID="7DMXWUCLVN"
NOTARYTOOL_PROFILE="ScreenShawty"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"

# Read version from project
VERSION=$(grep -A1 'MARKETING_VERSION' "${PROJECT_DIR}/${PROJECT}/project.pbxproj" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
DMG_FINAL="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"

echo "=== Building ${APP_NAME} v${VERSION} ==="
echo ""

# ── Step 1: Clean build directory ──
echo "▸ Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ── Step 2: Archive ──
echo "▸ Archiving (Release)..."
xcodebuild archive \
    -project "${PROJECT_DIR}/${PROJECT}" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=macOS' \
    | tail -1

echo "  ✓ Archive created at ${ARCHIVE_PATH}"

# ── Step 3: Export signed app ──
echo "▸ Exporting signed app..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "${PROJECT_DIR}/ExportOptions.plist" \
    -exportPath "$EXPORT_DIR" \
    | tail -1

if [ ! -d "$APP_PATH" ]; then
    echo "  ✗ Export failed — ${APP_PATH} not found"
    exit 1
fi
echo "  ✓ Signed app exported to ${APP_PATH}"

# ── Step 4: Verify code signature ──
echo "▸ Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"
echo "  ✓ Code signature valid"

# ── Step 5: Notarize ──
echo "▸ Creating temporary ZIP for notarization..."
NOTARIZE_ZIP="${BUILD_DIR}/${APP_NAME}-notarize.zip"
ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"

echo "▸ Submitting to Apple for notarization (this may take a few minutes)..."
xcrun notarytool submit "$NOTARIZE_ZIP" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait

rm -f "$NOTARIZE_ZIP"
echo "  ✓ Notarization complete"

# ── Step 6: Staple ──
echo "▸ Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"
echo "  ✓ Ticket stapled"

# ── Step 7: Create DMG ──
echo "▸ Creating DMG..."
DMG_STAGING="${BUILD_DIR}/dmg-staging"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING"

# Rename with version
mv "$DMG_PATH" "$DMG_FINAL"
echo "  ✓ DMG created at ${DMG_FINAL}"

# ── Step 8: Notarize the DMG too ──
echo "▸ Notarizing DMG..."
xcrun notarytool submit "$DMG_FINAL" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait

xcrun stapler staple "$DMG_FINAL"
echo "  ✓ DMG notarized and stapled"

# ── Step 9: Final verification ──
echo ""
echo "▸ Final verification..."
spctl --assess --verbose "$APP_PATH" 2>&1
spctl --assess --type open --context context:primary-signature --verbose "$DMG_FINAL" 2>&1

echo ""
echo "=== Build complete ==="
echo "  DMG: ${DMG_FINAL}"
echo "  Size: $(du -h "$DMG_FINAL" | cut -f1)"
echo ""
echo "Next: Create a GitHub release with:"
echo "  gh release create v${VERSION} \"${DMG_FINAL}\" --title \"ScreenShawty v${VERSION}\" --notes \"Initial release\""
