import Carbon.HIToolbox
import AppKit

class HotkeyManager {
    var onToggle: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var selfPtr: UnsafeMutableRawPointer?

    /// Returns nil on success, or the OSStatus from RegisterEventHotKey on failure
    /// (commonly -9878 / eventHotKeyExistsErr when another app owns ⌥Space).
    @discardableResult
    func register() -> OSStatus? {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let ptr = Unmanaged.passRetained(self).toOpaque()
        selfPtr = ptr

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let ptr = userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { manager.onToggle?() }
                return noErr
            },
            1,
            &eventType,
            ptr,
            &eventHandler
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4441), id: UInt32(1))
        // kVK_Space = 49, optionKey modifier
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        return status == noErr ? nil : status
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ptr = selfPtr {
            Unmanaged<HotkeyManager>.fromOpaque(ptr).release()
            selfPtr = nil
        }
    }
}
