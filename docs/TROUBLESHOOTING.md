# 🛡️ ArkenStone Troubleshooting & Permissions Guide

This guide provides in-depth explanations and solutions for macOS security permissions, hardware power features, and common questions.

---

## 📑 Table of Contents
1. [macOS Gatekeeper: "ArkenStone is damaged or cannot be opened"](#1-macos-gatekeeper-arkenstone-is-damaged-or-cannot-be-opened)
2. [Power Guard: Hardware SMC Battery Bypass Authorization](#2-power-guard-hardware-smc-battery-bypass-authorization)
3. [Clamshell Mode: Lid-Closed Sleep Prevention & AC Power Lock](#3-clamshell-mode-lid-closed-sleep-prevention--ac-power-lock)
4. [Screen OCR: Screen Recording Permission (TCC)](#4-screen-ocr-screen-recording-permission-tcc)
5. [Uninstalling the Privileged Power Helper](#5-uninstalling-the-privileged-power-helper)

---

## 1. macOS Gatekeeper: "ArkenStone is damaged or cannot be opened"

### Why does this happen?
When an application is downloaded outside the Mac App Store from the internet (e.g. from Whop, GitHub, or direct download), macOS applies an extended quarantine attribute (`com.apple.quarantine`). Because independent open-source developers often distribute without paying Apple's annual $99/year Developer ID notarization fee, macOS Gatekeeper may display a dialog claiming the application is *"damaged and can't be opened"* or from an unidentified developer.

### The 1-Second Solution:
Open **Terminal** and strip the quarantine flag:

```bash
xattr -cr /Applications/ArkenStone.app
```

Then launch **ArkenStone.app** normally. It will open immediately without warnings.

---

## 2. Power Guard: Hardware SMC Battery Bypass Authorization

### How it works:
Standard software tools cannot disconnect your MacBook's charging circuit because Apple Silicon PMU / SMC (System Management Controller) registers are protected at the kernel level. 

ArkenStone includes a lightweight, secure C helper binary (`arken-power-helper`) that communicates directly with the Apple Silicon SMC to toggle charging registers on and off. 

### Why is Root / Administrator permission required?
Writing to hardware SMC keys requires `root` privileges. To allow seamless, non-intrusive background regulation (so you aren't asked for your Mac password every time battery hits 80%), the helper is installed with SUID root permissions and a secure sudoers entry.

### How to install:
You can either click **"Install Helper"** directly inside the Battery tab in ArkenStone, or run this single terminal command:

```bash
sudo ./scripts/install_power_helper.sh
```

### Verifying installation:
In Terminal, run:
```bash
/usr/local/bin/arken-power-helper check-root
# Should return: ROOT_OK
```

---

## 3. Clamshell Mode: Lid-Closed Sleep Prevention & AC Power Lock

### Why does it only activate when plugged in?
By default, macOS forces a MacBook into sleep mode when the lid is closed unless an external monitor, mouse, and keyboard are connected. 

ArkenStone integrates hardware-level `pmset -a disablesleep 1` support, allowing your Mac to stay awake with the lid closed even without an external display (perfect for overnight renders, large downloads, or running server tasks).

> ⚠️ **Critical Safety Lock:** ArkenStone strictly **prohibits** lid-closed sleep prevention when running on battery power alone. If you unplug your charger, Clamshell Mode **deactivates immediately**. This prevents battery drain and protects your laptop from accidental overheating inside a backpack.

### When ArkenStone Quits:
ArkenStone listens to `NSApplication.willTerminateNotification`. Whenever the app quits, crashes, or is updated, normal macOS sleep behavior (`pmset -a disablesleep 0`) and power assertions are automatically and cleanly restored.

---

## 4. Screen OCR: Screen Recording Permission (TCC)

### Why does OCR need screen capture access?
The Screen OCR feature uses Apple's native **Vision Framework** (`VNRecognizeTextRequest`) running 100% on-device via the Neural Engine. To allow you to select a rectangle of text from your screen, macOS requires explicit Screen Recording permission under **Transparency, Consent, and Control (TCC)**.

### How to enable:
1. Open **System Settings** > **Privacy & Security** > **Screen Recording**.
2. Locate **ArkenStone** in the list and toggle the switch **ON**.
3. If prompted, click **"Quit & Reopen"** to apply the permission.

> 🔒 **Privacy Guarantee:** ArkenStone does not record videos, take periodic snapshots, or send any image data to external servers. Screen capture is executed solely when you manually click the crosshair tool or press the hotkey (`⌥O`).

---

## 5. Uninstalling the Privileged Power Helper

If you ever wish to remove the hardware power helper and its sudoers configuration, run:

```bash
sudo ./scripts/uninstall_power_helper.sh
```

This completely removes `/usr/local/bin/arken-power-helper` and `/private/etc/sudoers.d/arken-power`.
