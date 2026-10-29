#!/usr/bin/env bash
set -e

# Project configuration
APP_NAME="ArkenStone"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
CACHE_DIR="/tmp/swift-cache"

echo "💎 Building ${APP_NAME} for Apple Silicon (macOS 15.0+)..."

mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${CACHE_DIR}"

# Find all Swift source files
SOURCES=$(find Sources -name "*.swift")

# Compile with optimization
swiftc -parse-as-library \
    -module-cache-path "${CACHE_DIR}" \
    -target arm64-apple-macos14.0 \
    -framework AppKit \
    -framework SwiftUI \
    -framework IOKit \
    -framework UserNotifications \
    -framework CoreAudio \
    -framework Vision \
    -framework UniformTypeIdentifiers \
    -framework Carbon \
    -framework SystemConfiguration \
    -O \
    ${SOURCES} \
    -o "${MACOS_DIR}/${APP_NAME}"

# Compile Arken Power Helper for Apple Silicon SMC
echo "⚡ Compiling Arken Power Helper (SMC)..."
clang -target arm64-apple-macos14.0 -DCMD_TOOL_BUILD -O2 -framework IOKit \
    -I Sources/Arken/Helper \
    Sources/Arken/Helper/smc_lib.c \
    Sources/Arken/Helper/arken-power-helper.c \
    -o "${RESOURCES_DIR}/arken-power-helper"

# Provide legacy name in resources for seamless backward compatibility
cp "${RESOURCES_DIR}/arken-power-helper" "${RESOURCES_DIR}/palantir-power-helper" || true

# Copy AppIcon.icns if available in resources/assets
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
elif [ -f "assets/AppIcon.icns" ]; then
    cp "assets/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# Copy AppIconUI.png for in-app UI presentation
if [ -f "assets/AppIconUI.png" ]; then
    cp "assets/AppIconUI.png" "${RESOURCES_DIR}/AppIconUI.png"
fi

# Generate Info.plist (LSUIElement = true ensures Menu Bar only mode)
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ArkenStone</string>
    <key>CFBundleIdentifier</key>
    <string>com.citadel.arkenstone</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ArkenStone</string>
    <key>CFBundleDisplayName</key>
    <string>ArkenStone</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.8.6</string>
    <key>CFBundleVersion</key>
    <string>86</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>ArkenStone requires screen capture access to recognize and copy text from your screen (OCR).</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>ArkenStone uses AppleEvents to interact with Finder for actions like emptying the trash upon user request.</string>
</dict>
</plist>
EOF

# Entitlements (Stored in cache dir to keep bundle strictly clean for macOS codesign)
ENTITLEMENTS_FILE="${CACHE_DIR}/${APP_NAME}.entitlements"
cat << 'EOF' > "${ENTITLEMENTS_FILE}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.get-task-allow</key>
    <true/>
</dict>
</plist>
EOF

# Clean any residual entitlements file inside bundle
rm -f "${CONTENTS_DIR}/${APP_NAME}.entitlements"

# Sign the bundle with stable designated requirement so macOS TCC retains Screen Recording permission
codesign --force --deep --sign - \
    --entitlements "${ENTITLEMENTS_FILE}" \
    -r='designated => identifier "com.citadel.arkenstone"' \
    "${BUNDLE_DIR}"

echo "✨ ${APP_NAME}.app successfully built!"

if [ "$1" == "run" ]; then
    echo "🚀 Launching ${APP_NAME}..."
    open "${BUNDLE_DIR}"
fi
