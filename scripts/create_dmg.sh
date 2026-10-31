#!/usr/bin/env bash
set -e

# ArkenStone DMG Packaging Script for macOS
# Creates a clean, distributable ArkenStone-v0.8.3.dmg ready for Whop / GitHub Releases.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_NAME="ArkenStone"
APP_BUNDLE="${PROJECT_ROOT}/${APP_NAME}.app"
if [ -f "${APP_BUNDLE}/Contents/Info.plist" ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || echo "0.8.6")
else
    VERSION="0.8.6"
fi
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
DMG_OUTPUT="${PROJECT_ROOT}/${DMG_NAME}"
STAGING_DIR="/tmp/arkenstone_dmg_staging_$$"

echo "💎 Packaging ${APP_NAME} into ${DMG_NAME}..."

# 1. Verify app bundle exists; if not, build it first
if [ ! -d "${APP_BUNDLE}" ]; then
    echo "⚠️ ${APP_BUNDLE} not found. Running ./build.sh first..."
    (cd "${PROJECT_ROOT}" && ./build.sh)
fi

# 2. Prepare clean staging directory
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

# 3. Copy application bundle
echo "📦 Copying ${APP_BUNDLE} to staging..."
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/${APP_NAME}.app"

# 4. Create symlink to /Applications for standard drag-and-drop install
echo "🔗 Creating Applications symlink..."
ln -s /Applications "${STAGING_DIR}/Applications"

# 5. Create Gatekeeper helper note & copy License / Volume icon if available
cat << 'EOF' > "${STAGING_DIR}/HOW_TO_OPEN.txt"
============================================================
              ArkenStone - Quick Start Guide
============================================================

Thank you for downloading ArkenStone!

1. Installation:
   • Drag "ArkenStone.app" into the "Applications" shortcut.

2. First Launch on macOS (Gatekeeper Notice):
   Since ArkenStone is distributed outside the Mac App Store,
   macOS may show a security notice upon first open.

   To open it the first time:
   • Right-click (or Control-click) ArkenStone in Applications.
   • Click "Open" from the context menu.
   • Click "Open" in the system confirmation prompt.

   (You only need to do this once. Subsequent launches will
   open instantly from Spotlight, Launchpad, or login!)

3. Global Keyboard Shortcuts:
   • ⌥ Space / ⌥ A : Toggle Main Popover Control Center
   • ⌥ C           : Keep Awake (Caffeine) Toggle
   • ⌥ P           : Screen Color Eyedropper (Pipette)
   • ⌥ O           : Screen Text & QR OCR Capture
   • ⌥ M           : Global Microphone Mute Toggle
   • ⌥ D           : Floating File Shelf Window
   • ⌥ N           : Floating Quick Notes Window
   • ⌥ H           : Toggle Desktop Icons (Focus Mode)
   • ⌥ V           : Quick Clipboard History Menu
   • ⌥ K           : Clean Lock (Keyboard & Screen)
   • ⌘1..0         : Switch Dashboard Tabs Quickly

Enjoy your pure, native, and ultra-lightweight macOS power tool!
============================================================
EOF

if [ -f "${PROJECT_ROOT}/LICENSE" ]; then
    cp "${PROJECT_ROOT}/LICENSE" "${STAGING_DIR}/LICENSE.txt"
fi

# Copy volume icon to root of DMG
if [ -f "${PROJECT_ROOT}/assets/AppIcon.icns" ]; then
    cp "${PROJECT_ROOT}/assets/AppIcon.icns" "${STAGING_DIR}/.VolumeIcon.icns" || true
fi

# 6. Remove any existing DMG output
rm -f "${DMG_OUTPUT}"

# 7. Generate compressed DMG using hdiutil
echo "🚀 Building compressed UDZO disk image..."
hdiutil create \
    -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_OUTPUT}"

# 8. Clean up staging directory
rm -rf "${STAGING_DIR}"

# 9. Verify generated DMG
echo "🔍 Verifying disk image..."
hdiutil verify "${DMG_OUTPUT}"

# 10. Display checksum and size
FILE_SIZE=$(ls -lh "${DMG_OUTPUT}" | awk '{print $5}')
SHA256=$(shasum -a 256 "${DMG_OUTPUT}" | awk '{print $1}')

echo ""
echo "✨ Successfully created release-ready DMG!"
echo "📍 Location: ${DMG_OUTPUT}"
echo "📊 Size:     ${FILE_SIZE}"
echo "🔒 SHA256:   ${SHA256}"
echo "🎉 Ready for Whop / GitHub Releases distribution!"
