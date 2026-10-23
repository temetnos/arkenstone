#!/usr/bin/env bash
set -e

# Arken Power Guard Helper Installer
# This script must run with root/sudo privileges.

echo "🛡️ Installing Arken Power Helper..."

HELPER_BIN_DIR="/usr/local/bin"
HELPER_TARGET="${HELPER_BIN_DIR}/arken-power-helper"
LEGACY_HELPER="${HELPER_BIN_DIR}/palantir-power-helper"
SUDOERS_FILE="/private/etc/sudoers.d/arken-power"

# Ensure /usr/local/bin exists
mkdir -p "${HELPER_BIN_DIR}"

# Compile helper if source exists or copy from resources
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -f "${PROJECT_ROOT}/ArkenStone.app/Contents/Resources/arken-power-helper" ]; then
    cp "${PROJECT_ROOT}/ArkenStone.app/Contents/Resources/arken-power-helper" "${HELPER_TARGET}"
elif [ -f "${PROJECT_ROOT}/Palantir.app/Contents/Resources/palantir-power-helper" ]; then
    cp "${PROJECT_ROOT}/Palantir.app/Contents/Resources/palantir-power-helper" "${HELPER_TARGET}"
elif [ -f "/tmp/arken-power-helper" ]; then
    cp "/tmp/arken-power-helper" "${HELPER_TARGET}"
elif [ -f "/tmp/palantir-power-helper" ]; then
    cp "/tmp/palantir-power-helper" "${HELPER_TARGET}"
else
    # Compile on the fly
    clang -DCMD_TOOL_BUILD -O2 -framework IOKit \
        -I "${PROJECT_ROOT}/Sources/Arken/Helper" \
        "${PROJECT_ROOT}/Sources/Arken/Helper/smc_lib.c" \
        "${PROJECT_ROOT}/Sources/Arken/Helper/arken-power-helper.c" \
        -o "${HELPER_TARGET}"
fi

# Set root ownership and setuid permissions
chown root:wheel "${HELPER_TARGET}"
chmod 4755 "${HELPER_TARGET}"

# Create legacy symlink so older versions or caches keep functioning
ln -sf "${HELPER_TARGET}" "${LEGACY_HELPER}" || true

# Also configure sudoers.d rule as fallback
mkdir -p /private/etc/sudoers.d
chmod 755 /private/etc/sudoers.d

cat << 'EOF' > "${SUDOERS_FILE}"
# Arken Power Guard hardware charging control
ALL ALL = NOPASSWD: /usr/local/bin/arken-power-helper
ALL ALL = NOPASSWD: /usr/local/bin/palantir-power-helper
EOF

chmod 440 "${SUDOERS_FILE}"

echo "✨ Arken Power Helper successfully installed to ${HELPER_TARGET}!"
"${HELPER_TARGET}" check-root || true
