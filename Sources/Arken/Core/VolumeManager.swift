import Foundation
import AppKit

public struct MountedVolumeItem: Identifiable, Equatable {
    public var id: String { url.path }
    public let url: URL
    public let name: String
    public let isRemovable: Bool
    public let isEjectable: Bool
}

public class VolumeManager: ObservableObject {
    public static let shared = VolumeManager()
    
    @Published public var ejectableVolumes: [MountedVolumeItem] = []
    @Published public var lastErrorMessage: String? = nil
    
    public init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(onVolumeChanged), name: NSWorkspace.didMountNotification, object: nil)
        center.addObserver(self, selector: #selector(onVolumeChanged), name: NSWorkspace.didUnmountNotification, object: nil)
    }
    
    @objc private func onVolumeChanged() {
        DispatchQueue.main.async {
            self.refresh()
        }
    }
    
    public func refresh() {
        let keys: [URLResourceKey] = [.volumeLocalizedNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey]
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            ejectableVolumes = []
            return
        }
        
        var items: [MountedVolumeItem] = []
        for url in urls {
            guard let vals = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            let isRemovable = vals.volumeIsRemovable ?? false
            let isEjectable = vals.volumeIsEjectable ?? false
            if isRemovable || isEjectable {
                let name = vals.volumeLocalizedName ?? url.lastPathComponent
                items.append(MountedVolumeItem(url: url, name: name, isRemovable: isRemovable, isEjectable: isEjectable))
            }
        }
        self.ejectableVolumes = items
    }
    
    public func eject(volume: MountedVolumeItem) {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
            self.lastErrorMessage = nil
            SoundManager.shared.play(.pop)
        } catch {
            self.lastErrorMessage = error.localizedDescription
            SoundManager.shared.play(.warning)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }
    
    public func ejectAll() {
        var firstError: Error? = nil
        for v in ejectableVolumes {
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: v.url)
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }
        if let err = firstError {
            self.lastErrorMessage = err.localizedDescription
            SoundManager.shared.play(.warning)
        } else {
            self.lastErrorMessage = nil
            SoundManager.shared.play(.pop)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }
}
