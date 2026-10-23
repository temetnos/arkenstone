<div align="center">

<img src="assets/AppIcon_1024.png" width="128" height="128" alt="ArkenStone App Icon" />

# 💎 ArkenStone (Arken)

### *The Native All-in-One macOS System Monitor, Power Guard & Productivity Suite*

[![macOS 14+](https://img.shields.io/badge/macOS-14.0%2B%20%7C%2015.0%2B%20Sequoia-black?style=for-the-badge&logo=apple)](https://apple.com)
[![Apple Silicon](https://img.shields.io/badge/Architecture-Apple%20Silicon%20(M1--M4)-orange?style=for-the-badge&logo=apple)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-5.10%2B%20%2F%20SwiftUI-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Zero Dependencies](https://img.shields.io/badge/Dependencies-0%20(Pure%20Native)-brightgreen?style=for-the-badge)]()
[![Baseline RAM](https://img.shields.io/badge/Baseline%20RAM-%3C%2075%20MB-blue?style=for-the-badge)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-purple?style=for-the-badge)](LICENSE)

<br/>

### [ 🍏 Download Ready-to-Run Binary ($4.99 on Whop) ](https://whop.com) &nbsp;&nbsp;•&nbsp;&nbsp; [ 🛠️ Build from Source (100% Free) ](#-building-from-source-100-free--open-source)

*Get instant pre-compiled `.dmg` downloads, lifetime free updates, and support independent software development — or clone and build it yourself from source.*

</div>

---

## 📸 Visual Overview & Core Workflows

<div align="center">

### 1. Overview Dashboard & 2-Tier Glass Control Center Hub
<img src="assets/screenshot-overview.png" width="480" alt="Overview Dashboard & System Telemetry" />

<br/><br/>

### 2. Dynamic Drop Shelf & Detachable Floating Window
<img src="assets/screenshot-shelf.png" width="480" alt="Dynamic Drop Shelf & Detachable Floating Window" />

<br/><br/>

### 3. Power Guard & Hardware Battery Bypass
<img src="assets/screenshot-power.png" width="480" alt="Power Guard & Motherboard Bypass" />

<br/><br/>

### 4. Smart RAM-Only Clipboard History & Color Loupe
<img src="assets/screenshot-clipboard.png" width="480" alt="Smart RAM-Only Clipboard History" />

<br/><br/>

### 5. App Leftover Cleaner & Deep Uninstaller
<img src="assets/screenshot-cleaner.png" width="480" alt="App Leftover Cleaner & Deep Uninstaller" />

</div>

---

## 🎯 The Curation Philosophy: Niche Essentials, Zero Bloat

Commercial macOS utilities often come bundled with dozens of esoteric settings, heavy background daemons, analytics tracking, and monthly subscriptions that drain your battery and system memory. You don't need a heavy 300 MB background suite just to safely clean app caches, nor an overengineered daemon with 50 obscure toggles just to limit battery charging to 80%.

**ArkenStone takes a laser-focused, curated approach to everyday desktop productivity:**
We do not attempt to clone every fringe, rarely-used toggle from bloated commercial software. Instead, we analyzed the everyday services Mac users actually need and frequently pay separate software for. We **trimmed away the excess bloat and unnecessary complexity**, extracted the essential 20% that delivers 80% of real daily value, and fused these high-utility functions into a single, unified, ultra-lightweight Swift & AppKit menubar hub.

### 💰 Standalone Market Alternatives vs. ArkenStone

| Everyday Niche Workflow | Average Standalone Market Price | ArkenStone Curated Solution | Why This Laser-Focused Curation Wins |
| :--- | :--- | :--- | :--- |
| **Hardware Battery Charging Limiter (SMC)** | ~$15 – $25 (or annual sub) | **Power Guard & Motherboard Bypass** | True Apple Silicon PMU register cut-off without heavy background services |
| **Multi-Core System & Thermal Telemetry** | ~$10 – $15 | **Mach Kernel & IOKit Telemetry** | Pure C kernel calls with °C/°F toggle; zero shell commands; < 0.1% CPU |
| **Drag & Drop File Staging Shelf** | ~$8 – $10 | **Dynamic Shelf & Floating Window** | Transient menubar shelf or detachable always-on-top floating panel with ⌘Z undo |
| **Privacy-First Clipboard History** | ~$10 – $20 / yr | **RAM-Only Clipboard & Color Pipette** | Volatile RAM-only security; automatic image downsampling with 30 MB ceiling |
| **Screen OCR Text Extractor** | ~$10 – $15 | **Apple Vision On-Device OCR** | Native Apple Neural Engine offline text recognition with no cloud roundtrip |
| **App Leftover & Cache Cleaner** | ~$30 – $40 / yr | **Deep Leftover & Developer Cleaner** | Pinpoint Bundle ID discovery that safely moves real leftover caches to Trash |
| **Lid-Closed Sleep & Caffeine Inhibit** | ~$5 – $10 | **AC-Aware Keep Awake Engine** | Clamshell mode with strict AC power safety lock to prevent backpack overheating |
| **Developer TCP Port Manager** | ~$10 (or terminal commands) | **One-Click Port & Conflict Killer** | Rapid socket discovery with real-time port filter and graceful SIGTERM/SIGKILL |
| **Quick DNS Switcher & Cache Flush** | ~$5 – $10 | **Dynamic Network Resolver** | Automatic default gateway detection (Wi-Fi/Ethernet) + `mDNSResponder` reset |
| **Global Mic Mute & Desktop Focus** | ~$5 – $10 | **CoreAudio Input & Finder Toggles** | Single-click global hardware mic mute and instant clean desktop presentations |
| **TOTAL MARKET VALUE** | **~$105 – $170+** | **Included in ArkenStone ($4.99 / $5)** | **1 lightweight app, 1 menubar icon, zero subscriptions** |

---

## ⚡ 14 Core Superpowers & Technical Deep Dive

### 1. 🛡️ Power Guard (Hardware SMC Battery Bypass & Clamshell Awake)
* **True Hardware Charging Cut-Off:** Communicates directly with the Apple Silicon SMC (System Management Controller) via a lightweight, secure C helper binary (`arken-power-helper`).
* **Motherboard Power Bypass:** When battery charge reaches your configured threshold (e.g., 80%), the motherboard's charging circuit is physically switched off. Your Mac runs strictly on AC adapter current, preventing battery degradation during prolonged desk use.
* **Clamshell (Lid-Closed) Sleep Prevention:** Allows running downloads or server tasks with your MacBook lid closed without needing an external monitor.
* **Failsafe AC Lock:** Clamshell Mode **strictly requires AC power**; unplugging the charger deactivates it immediately to protect battery life and prevent backpack overheating.
* **Desktop Mac Compatibility:** Automatically identifies desktop Apple Silicon hardware (Mac mini, Mac Studio, Mac Pro, iMac) and seamlessly renders an **AC Direct Power** status card instead of misleading missing-battery indicators.

### 2. 📊 High-Precision Low-Overhead Hardware Telemetry
* **CPU & Per-Core Load:** Real-time visualization of individual Performance (P) and Efficiency (E) cores via native Mach kernel calls (`host_processor_info`).
* **Apple Silicon GPU & Metal Utilization:** Live monitoring of integrated GPU renderer/tiler load and allocated VRAM via IOKit accelerator registries.
* **Memory Pressure & Architecture:** Granular breakdown of Active, Wired, Compressed, and Swap memory, complete with Apple memory pressure telemetry (`Normal`, `Warning`, `Critical`).
* **50+ Hardware Thermal Sensors (°C / °F):** Real-time readout of CPU, GPU, and SoC Die temperatures with instant dynamic switching between Celsius and Fahrenheit.
* **Live Network Bandwidth & IP:** Continuous download and upload sparklines with session totals, dynamic detection of active non-virtual interfaces (Ethernet adapters, docks, Wi-Fi), and sleep/wake bandwidth spike dampening.
* **Top Process Spotter:** Instantly identifies CPU- or memory-intensive background processes, with one-click termination capability.

### 3. 🏝️ Dynamic Drop Shelf & Floating Workspace
* **Zero Desktop Clutter:** Staging area stays out of sight until needed.
* **Menu Bar Drop Target:** Drag any file, image, or folder directly over the menu bar icon to reveal the staging shelf instantly.
* **Detachable Floating Window:** Pop out the shelf into an independent, always-on-top floating `NSPanel` (`[↗]`) to freely organize and stage files across multiple full-screen spaces.
* **Copy vs. Move Semantics:** Hold `⌥ Option` or `⌘ Command` during drag-out to toggle between non-destructive copying and moving.
* **Multi-Level Undo (`⌘Z`):** Accidentally cleared a file? Restore it immediately with full undo support.
* **Direct Bridge to App Cleaner:** Dropping a `.app` bundle onto the shelf automatically presents a shortcut to inspect and remove all orphaned files.

### 4. 📋 Smart RAM-Only Clipboard History
* **Volatile Memory Privacy:** Clipboard history is held strictly in volatile RAM and is never written to disk or sent across the network.
* **Automatic Content Classification:**
  - 💻 **Code:** Syntax snippets, functions, and structured configuration blocks.
  - 🔗 **URLs:** Web links and domains.
  - 🎨 **Colors:** Hexadecimal (`#HEX`) and RGB color codes with live circular color swatch indicators.
  - 📄 **Text:** Plain text, paragraphs, and sensitive credentials.
* **Right-Click Quick Menu:** Access your most recent clips right from the macOS menu bar context menu with instant keyboard accelerators (`1`–`8`).
* **Live Search & Pinning:** Pin essential tokens with instant visual updates; search through clips in milliseconds with a one-click clear button (`xmark.circle.fill`).
* **Memory Protection Ceiling:** High-resolution screenshots are automatically compressed into optimized thumbnails with a strict 30 MB cache ceiling.

### 5. 🎨 Magnifier Screen Eyedropper (Color Pipette)
* **Pixel-Accurate Sampling:** Invokes the native macOS circular magnifying loupe with an overlaid pixel grid.
* **Instant Clipboard Formatting:** Sample any pixel on your displays to automatically copy its standard sRGB `#HEX` and `rgb()` values directly to your clipboard and history.
* **Sound Confirmation:** Subtle audio chime feedback upon successful sampling.

### 6. 🔍 Apple Vision On-Device Screen OCR
* **Neural Engine Text Extraction:** Capture any non-selectable text, error dialog, video frame, or image with an interactive crosshair selection tool (`⌥O` or menu button).
* **100% Offline & Private:** Powered on-device by Apple's Vision Framework (`VNRecognizeTextRequest`). Zero cloud latency, zero external data sharing.
* **Multi-Language & Code Support:** Automatically parses alphanumerics, punctuation, Latin scripts, and formatted code blocks.

### 7. 🧹 Safe Developer & System Cleaner + App Leftover Uninstaller
* **App Leftover Deep Cleaner (AppCleaner Parity):**
  - Drag and drop any `.app` bundle or pick from Applications.
  - Scans `~/Library/Application Support`, `~/Library/Caches`, `~/Library/Preferences`, `~/Library/Saved Application State`, `~/Library/Logs`, and `~/Library/Containers` for matching Bundle IDs and vendor identifiers.
  - Displays application binary and leftover sizes with exact precision.
  - Moves items safely to the macOS Trash (`~/.Trash/`) using native workspace operations and privileged trashing fallbacks.
* **Safe Developer Caches:** One-click cleanup for Xcode `DerivedData`, CocoaPods caches, Homebrew package downloads, and `npm`/`yarn`/`pip` caches. Never touches documents, personal files, or desktop directories.

### 8. 🌐 Quick DNS Switcher & Cache Flush
* **One-Click DNS Presets:** Seamlessly toggle your active network interface between:
  - **Cloudflare** (`1.1.1.1` & `1.0.0.1`) — High speed & privacy focus.
  - **Google Public DNS** (`8.8.8.8` & `8.8.4.4`) — Ultra-reliable global resolution.
  - **Quad9** (`9.9.9.9` & `149.112.112.112`) — Built-in malware and phishing blocking.
  - **Automatic (DHCP)** — Default router-assigned DNS with dynamic default gateway detection.
* **Instant Cache Flush:** Executes atomic cache flushing via `dscacheutil -flushcache` and signals `killall -HUP mDNSResponder` to resolve network routing anomalies immediately.

### 9. 🔌 Developer Port & Process Manager
* **Active Listener Discovery:** Rapidly scans active TCP sockets on development ports (3000, 5173, 8000, 8080, etc.) without requiring terminal commands.
* **Real-Time Port & Process Filter:** Instantly filter listeners by port number, PID, or process name.
* **Conflict Resolution (`EADDRINUSE`):** Free stubborn ports locked by crashed Node, Python, or Go servers with one click using graceful SIGTERM and automatic SIGKILL fallbacks.

### 10. 🖥️ Desktop Focus Mode (Hide Desktop Icons)
* **Instant Screen Decluttering:** Hide all desktop files, folders, and drives in a single click for clean presentations, screen recordings, or distraction-free workspaces.
* **Zero Re-indexing Overhead:** Interacts directly with macOS Finder preferences (`CreateDesktop = false`), keeping files in their original locations without moving them.

### 11. 📝 Quick Scratchpad & Note Buffer
* **Fast Ephemeral Notes:** Instantly jot down API tokens, temporary snippets, or shell commands.
* **Live Word & Character Counters:** Real-time metrics displayed right below the editor.
* **One-Click Desktop Export:** Instantly export notes directly to your desktop (`~/Desktop/Arken_Notes.txt`).
* **Accidental Clear Protection:** Includes instant "Undo" recovery if text is cleared inadvertently.

### 12. 🔊 Centralized Audio Feedback System
* **Cohesive Sound Schemes:** Offers two sound design profiles:
  - **Classic Mac:** Familiar glass, pop, and tink chimes.
  - **Minimalist:** Subtle, soft feedback tones.
* **Global Toggle:** Master audio toggle in Settings with an instant sound test preview.

### 13. 🎛️ Dynamic 2-Tier Glass Control Center & Status Bar Modes
* **Balanced 2-Tier Layout:** Features an ergonomic quick utility command hub that groups productivity tools (Shelf & Clipboard) and system toggles (Caffeine, Desktop Focus, Power Guard) without text wrapping or layout distortion.
* **Power-User Keyboard Navigation:** Switch between tabs instantly with `⌘1` through `⌘9`, open Settings with `⌘,`, and dismiss the popover with `ESC`.
* **12+ Menu Bar Formats:** Customize your menu bar display with compact icons, CPU percentages, RAM load, thermal metrics, wattage draw, download/upload rates, or composite telemetry.
* **Adaptive Polling:** The telemetry engine automatically throttles down to relaxed 3-second intervals when the popover is closed via `NSPopoverDelegate`, drawing negligible energy.

### 14. 🌍 Native Bilingual Localization
* **Instant Language Switching:** Seamlessly toggle between **English** and **Turkish (Türkçe)** on the fly without restarting the application.

---

## 🏗️ Architecture & Philosophy

```
ArkenStone.app
├── Mach Kernel / BSD C-APIs  → CPU, RAM, Network, Thermals (Zero Shell Spawns)
├── IOKit & SMC C-Helper       → Hardware PMU Battery Bypass & Clamshell Control
├── Apple Vision Framework     → On-Device Neural OCR Engine
├── CoreAudio HAL              → Global Hardware Microphone Input Control
├── SystemConfiguration / DNS  → Dynamic Network Service Resolver
└── SwiftUI & AppKit           → Liquid-Smooth Frosted Glass Interface (60/120 Hz)
```

- **Zero Third-Party Dependencies:** 100% pure Swift, C, and Apple native frameworks. No SPM dependencies, no CocoaPods, no Electron bloat.
- **Resource Footprint & Memory Management:** 
  - **Baseline Idle Footprint:** Consistently consumes **under 75 MB of RAM** (typically 50–70 MB idle) and **~0.0% CPU** on fresh launch.
  - **Dynamic Scaling & Memory Protection:** Active memory naturally scales when copying high-resolution Retina screenshots or staging multiple items in the file shelf. To prevent background bloat, ArkenStone features automatic image downsampling and a strict **30 MB memory ceiling** that continuously trims old unpinned cache data.
- **Security & Privacy:** Network telemetry, clipboard history, OCR recognition, and file staging run strictly locally on your machine with zero remote tracking or analytics.

---

## 🛠️ Building from Source (100% Free & Open Source)

If you prefer to compile ArkenStone yourself, you are completely free to do so:

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- Apple Silicon Mac (M1, M2, M3, M4)
- Xcode Command Line Tools (`xcode-select --install`)

### Compile
Clone the repository and compile using the optimized build script:

```bash
git clone https://github.com/temetnos/arkenstone.git
cd arkenstone

# Build the optimized .app bundle
./build.sh

# Run directly
open ArkenStone.app
```

---

## ❓ Troubleshooting & Permissions

Encountering an issue or permission prompt? Check our detailed guide:
👉 **[Full Permissions & Troubleshooting Guide (docs/TROUBLESHOOTING.md)](docs/TROUBLESHOOTING.md)**

* **macOS Gatekeeper Warning:** If macOS shows an unidentified developer dialog upon downloading, run:
  ```bash
  xattr -cr /Applications/ArkenStone.app
  ```
* **Hardware SMC Battery Limiter:** To enable hardware battery charging cut-off without third-party daemons, install the privileged helper once:
  ```bash
  sudo ./scripts/install_power_helper.sh
  ```
* **Screen OCR Permissions:** Requires Screen Recording permission in **System Settings > Privacy & Security > Screen Recording**.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
