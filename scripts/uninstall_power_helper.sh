#!/usr/bin/env bash
set -e

# Arken Power Guard Helper Uninstaller
# This script must run with root/sudo privileges.

echo "🧹 Uninstalling Arken Power Helper..."

rm -f /usr/local/bin/arken-power-helper
rm -f /usr/local/bin/palantir-power-helper
rm -f /private/etc/sudoers.d/arken-power
rm -f /private/etc/sudoers.d/palantir-power

echo "✨ Arken Power Helper successfully removed!"
