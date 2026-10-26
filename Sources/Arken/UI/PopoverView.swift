import SwiftUI

public enum ArkenTab: String, CaseIterable, Identifiable {
    case overview = "overview"
    case cpu = "cpu"
    case gpu = "gpu"
    case ram = "ram"
    case network = "network"
    case ports = "ports"
    case thermal = "thermal"
    case battery = "battery"
    case shelf = "shelf"
    case clipboard = "clipboard"
    case scratchpad = "scratchpad"
    case cleaner = "cleaner"
    case settings = "settings"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .overview: return L10n.tr("Overview", "Genel")
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .ram: return "RAM"
        case .network: return L10n.tr("Network", "Ağ")
        case .ports: return L10n.tr("Ports", "Portlar")
        case .thermal: return L10n.tr("Thermals", "Sıcaklık")
        case .battery: return L10n.tr("Power", "Güç")
        case .shelf: return L10n.tr("Shelf", "Dosya Rafı")
        case .clipboard: return L10n.tr("Clipboard", "Pano")
        case .scratchpad: return L10n.tr("Notes", "Notlar")
        case .cleaner: return L10n.tr("Cleaner", "Temizlik")
        case .settings: return L10n.tr("Settings", "Ayarlar")
        }
    }
    
    public var icon: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.bottom.50percent"
        case .cpu: return "cpu"
        case .gpu: return "square.2.layers.3d"
        case .ram: return "memorychip"
        case .network: return "network"
        case .ports: return "point.3.connected.trianglepath.dotted"
        case .thermal: return "flame"
        case .battery: return "bolt.batteryblock"
        case .shelf: return "hand.draw"
        case .clipboard: return "doc.on.clipboard"
        case .scratchpad: return "note.text"
        case .cleaner: return "sparkles"
        case .settings: return "gearshape"
        }
    }
}

public struct PopoverView: View {
    @ObservedObject var monitor: HardwareMonitor
    @ObservedObject var shelf = DropShelfEngine.shared
    @ObservedObject var clipboard = ClipboardEngine.shared
    @ObservedObject var audioMute = AudioMuteEngine.shared
    @ObservedObject var ocrEngine = ScreenOCREngine.shared
    @ObservedObject var l10n = LocalizationManager.shared
    @State private var selectedTab: ArkenTab = .overview
    @State private var keyMonitor: Any? = nil
    
    public init(monitor: HardwareMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                // Official App Icon (ArkenStone Squircle)
                Image(nsImage: AppInfo.appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5.5, style: .continuous))
                    .shadow(color: ArkenTheme.cpuColor.opacity(0.35), radius: 4, x: 0, y: 1)
                    .help("ArkenStone \(AppInfo.formattedVersion)")
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text("ARKEN")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .tracking(1.2)
                        Text(AppInfo.formattedVersion)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(ArkenTheme.cpuColor)
                    }
                    Text("\(monitor.macModel) • \(monitor.chipName)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Screen OCR Button
                Button(action: {
                    StatusBarController.shared?.closeMainPopover()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        ocrEngine.startCaptureAndRecognize()
                    }
                }) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ArkenTheme.cpuColor)
                        .frame(width: 22, height: 22)
                        .background(ArkenTheme.cpuColor.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.tr("Capture & Recognize Text on Screen (OCR)", "Ekrandan Metin Kopyala (Apple Vision OCR)"))
                
                // Global Mic Mute Button
                Button(action: {
                    audioMute.toggleMute()
                }) {
                    Image(systemName: audioMute.isMuted ? "microphone.slash.fill" : "microphone.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(audioMute.isMuted ? .red : .green)
                        .frame(width: 22, height: 22)
                        .background(audioMute.isMuted ? Color.red.opacity(0.18) : Color.green.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help(audioMute.isMuted ? L10n.tr("Unmute Microphone", "Mikrofonu Aç") : L10n.tr("Mute Microphone (Global Mute)", "Mikrofonu Sustur (Global Mute)"))
                
                // Uptime Badge
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(monitor.uptimeString)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                
                // Quit Button
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.tr("Quit ArkenStone", "ArkenStone'dan Çık"))
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Tab Selector Pill Bar (Smooth Horizontal Scrolling with Auto-Scroll)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(ArkenTab.allCases) { tab in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedTab = tab
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(tab.title)
                                        .font(.system(size: 10, weight: .medium))
                                    
                                    if tab == .shelf && !shelf.items.isEmpty {
                                        Text("\(shelf.items.count)")
                                            .font(.system(size: 8, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(ArkenTheme.accentColor)
                                            .foregroundColor(.white)
                                            .clipShape(Capsule())
                                    } else if tab == .clipboard && !clipboard.items.isEmpty {
                                        Text("\(clipboard.items.count)")
                                            .font(.system(size: 8, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.white.opacity(0.2))
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    selectedTab == tab
                                    ? Color.white.opacity(0.16)
                                    : Color.clear
                                )
                                .foregroundColor(selectedTab == tab ? .white : .secondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .id(tab)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .onChange(of: selectedTab) { _, newTab in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newTab, anchor: .center)
                    }
                }
            }
            .padding(.bottom, 10)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Active Tab Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    switch selectedTab {
                    case .overview:
                        OverviewTab(monitor: monitor, onSelectTab: { tab in
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedTab = tab
                            }
                        })
                    case .cpu:
                        CPUTab(monitor: monitor)
                    case .gpu:
                        GPUTab(monitor: monitor)
                    case .ram:
                        MemoryTab(monitor: monitor)
                    case .network:
                        NetworkTab(monitor: monitor)
                    case .ports:
                        PortManagerTab()
                    case .thermal:
                        ThermalTab(monitor: monitor)
                    case .battery:
                        BatteryTab(monitor: monitor)
                    case .shelf:
                        ShelfTab()
                    case .clipboard:
                        ClipboardTab()
                    case .scratchpad:
                        ScratchpadTab()
                    case .cleaner:
                        DiskCleanerTab()
                    case .settings:
                        SettingsTab()
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 385, height: 460)
        .background(VisualEffectBackground())
        .background(
            Group {
                Button("") { selectedTab = .overview }.keyboardShortcut("1", modifiers: .command)
                Button("") { selectedTab = .cpu }.keyboardShortcut("2", modifiers: .command)
                Button("") { selectedTab = .gpu }.keyboardShortcut("3", modifiers: .command)
                Button("") { selectedTab = .ram }.keyboardShortcut("4", modifiers: .command)
                Button("") { selectedTab = .network }.keyboardShortcut("5", modifiers: .command)
                Button("") { selectedTab = .ports }.keyboardShortcut("6", modifiers: .command)
                Button("") { selectedTab = .thermal }.keyboardShortcut("7", modifiers: .command)
                Button("") { selectedTab = .battery }.keyboardShortcut("8", modifiers: .command)
                Button("") { selectedTab = .shelf }.keyboardShortcut("9", modifiers: .command)
                Button("") { selectedTab = .clipboard }.keyboardShortcut("0", modifiers: .command)
                Button("") { selectedTab = .scratchpad }.keyboardShortcut("n", modifiers: .command)
                Button("") { selectedTab = .cleaner }.keyboardShortcut("k", modifiers: .command)
                Button("") { selectedTab = .settings }.keyboardShortcut(",", modifiers: .command)
                Button("") { StatusBarController.shared?.closeMainPopover() }.keyboardShortcut(.cancelAction)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        )
        .onAppear {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // ESC key (code 53)
                if event.keyCode == 53 {
                    StatusBarController.shared?.closeMainPopover()
                    return nil
                }
                // Command shortcuts (⌘1..⌘9, ⌘0, ⌘N, ⌘K, ⌘,)
                if event.modifierFlags.contains(.command) {
                    if let chars = event.charactersIgnoringModifiers {
                        var targetTab: ArkenTab?
                        switch chars {
                        case "1": targetTab = .overview
                        case "2": targetTab = .cpu
                        case "3": targetTab = .gpu
                        case "4": targetTab = .ram
                        case "5": targetTab = .network
                        case "6": targetTab = .ports
                        case "7": targetTab = .thermal
                        case "8": targetTab = .battery
                        case "9": targetTab = .shelf
                        case "0": targetTab = .clipboard
                        case "n", "N": targetTab = .scratchpad
                        case "k", "K": targetTab = .cleaner
                        case ",": targetTab = .settings
                        default: break
                        }
                        if let tab = targetTab {
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    self.selectedTab = tab
                                }
                            }
                            return nil
                        }
                    }
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ArkenSelectTab"))) { notif in
            if let tab = notif.object as? ArkenTab {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedTab = tab
                }
            }
        }
    }
}

// macOS Frosted Glass Background
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
