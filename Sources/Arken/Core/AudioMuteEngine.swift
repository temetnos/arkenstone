import Foundation
import CoreAudio
import Combine
import AppKit

public class AudioMuteEngine: ObservableObject {
    public static let shared = AudioMuteEngine()
    
    @Published public var isMuted: Bool = false
    @Published public var deviceName: String = "Mikrofon"
    
    private var currentListeningDeviceID: AudioObjectID = 0
    private var deviceChangeListenerRegistered = false
    
    public init() {
        updateMuteState()
        setupCoreAudioListeners()
    }
    
    private func setupCoreAudioListeners() {
        guard !deviceChangeListenerRegistered else { return }
        
        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddress,
            DispatchQueue.main
        ) { [weak self] (_, _) in
            self?.handleDefaultDeviceChanged()
        }
        
        if status == noErr {
            deviceChangeListenerRegistered = true
        }
        
        attachMuteListenerToCurrentDevice()
    }
    
    private func handleDefaultDeviceChanged() {
        updateMuteState()
        attachMuteListenerToCurrentDevice()
    }
    
    private func attachMuteListenerToCurrentDevice() {
        guard let deviceID = getDefaultInputDevice() else { return }
        
        if currentListeningDeviceID != deviceID {
            currentListeningDeviceID = deviceID
            
            var muteAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            _ = AudioObjectAddPropertyListenerBlock(
                deviceID,
                &muteAddress,
                DispatchQueue.main
            ) { [weak self] (_, _) in
                self?.updateMuteState()
            }
        }
    }
    
    public func toggleMute() {
        setMute(!isMuted)
    }
    
    public func setMute(_ mute: Bool) {
        guard let deviceID = getDefaultInputDevice() else { return }
        
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var muteValue: UInt32 = mute ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        
        let status = AudioObjectSetPropertyData(
            deviceID,
            &muteAddress,
            0,
            nil,
            size,
            &muteValue
        )
        
        if status == noErr {
            DispatchQueue.main.async {
                self.isMuted = mute
                if mute {
                    SoundManager.shared.play(.pop)
                } else {
                    SoundManager.shared.play(.action)
                }
            }
        }
    }
    
    public func updateMuteState() {
        guard let deviceID = getDefaultInputDevice() else { return }
        
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var isMutedVal: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        
        if AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &size, &isMutedVal) == noErr {
            DispatchQueue.main.async {
                self.isMuted = (isMutedVal != 0)
            }
        }
        
        // Query device name
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name) == noErr,
           let cfName = name?.takeRetainedValue() {
            let n = cfName as String
            DispatchQueue.main.async {
                self.deviceName = n
            }
        }
    }
    
    private func getDefaultInputDevice() -> AudioObjectID? {
        var defaultInputDevice: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &defaultInputDevice
        )
        
        return (status == noErr && defaultInputDevice != 0) ? defaultInputDevice : nil
    }
}
