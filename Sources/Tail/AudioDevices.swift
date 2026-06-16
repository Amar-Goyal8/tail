import Foundation
import AVFoundation
import CoreAudio

struct AudioDev: Identifiable, Hashable, Sendable {
    let id: String      // uniqueID (input) or CoreAudio UID (output)
    let name: String
}

enum AudioDevices {
    // Microphone / input devices (AVFoundation gives uniqueIDs usable by capture).
    static func inputs() -> [AudioDev] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified)
        return session.devices.map { AudioDev(id: $0.uniqueID, name: $0.localizedName) }
    }

    // Output devices via Core Audio. Selecting one sets it as the system default
    // output, which is the mix ScreenCaptureKit records.
    static func outputs() -> [AudioDev] {
        deviceIDs().compactMap { id in
            guard hasStreams(id, scope: kAudioObjectPropertyScopeOutput),
                  let name = name(id), let uid = uid(id) else { return nil }
            return AudioDev(id: uid, name: name)
        }
    }

    static func defaultOutputUID() -> String? {
        var id = AudioDeviceID(0); var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id) == noErr
        else { return nil }
        return uid(id)
    }

    static func setDefaultOutput(uid: String) {
        guard let id = deviceID(forUID: uid) else { return }
        var dev = id
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
                                   UInt32(MemoryLayout<AudioDeviceID>.size), &dev)
    }

    // MARK: Core Audio plumbing
    private static func deviceIDs() -> [AudioDeviceID] {
        var size = UInt32(0)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr
        else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr
        else { return [] }
        return ids
    }

    private static func hasStreams(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var size = UInt32(0)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
                                              mScope: scope, mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size)
        return size > 0
    }

    private static func name(_ id: AudioDeviceID) -> String? { cfString(id, kAudioObjectPropertyName) }
    private static func uid(_ id: AudioDeviceID) -> String? { cfString(id, kAudioDevicePropertyDeviceUID) }

    private static func cfString(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var str: CFString? = nil
        var size = UInt32(MemoryLayout<CFString?>.size)
        var addr = AudioObjectPropertyAddress(mSelector: selector,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &str) == noErr else { return nil }
        return str as String?
    }

    private static func deviceID(forUID uid: String) -> AudioDeviceID? {
        deviceIDs().first { self.uid($0) == uid }
    }
}
