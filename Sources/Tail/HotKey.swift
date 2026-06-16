import Carbon.HIToolbox
import Foundation

// Global hotkey via Carbon RegisterEventHotKey. Works system-wide with NO
// Accessibility / Input Monitoring permission (NSEvent monitors need those).
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    // keyCode: virtual key (C = 8). modifiers: Carbon mask (controlKey|optionKey).
    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        let hotKeyID = EventHotKeyID(signature: OSType(0x5441_494C), id: 1) // 'TAIL'

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            me.action()
            _ = event
            return noErr
        }, 1, &spec, selfPtr, &handler)

        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
