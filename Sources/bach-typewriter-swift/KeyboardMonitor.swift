import AppKit
import ApplicationServices

final class KeyboardMonitor {
    struct Signal {
        let source: String
        let timestamp: Date
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var refreshTimer: Timer?
    private let onKeyPress: () -> Void
    private let onTrustChanged: (AccessibilityGuide.PermissionStatus) -> Void
    private let onSignal: (Signal) -> Void
    private(set) var isTrusted: Bool = false
    private var lastAcceptedKeyTime: TimeInterval = 0

    init(
        onKeyPress: @escaping () -> Void,
        onTrustChanged: @escaping (AccessibilityGuide.PermissionStatus) -> Void,
        onSignal: @escaping (Signal) -> Void
    ) {
        self.onKeyPress = onKeyPress
        self.onTrustChanged = onTrustChanged
        self.onSignal = onSignal
        refreshTrust()
        AccessibilityGuide.promptIfNeeded()
        start()
    }

    deinit {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        refreshTimer?.invalidate()
    }

    private func start() {
        startEventTap()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.handleKeyPress(source: "global-monitor")
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyPress(source: "local-monitor")
            return event
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshTrust()
            self?.ensureEventTapIsRunning()
        }
        refreshTimer = timer
    }

    private func startEventTap() {
        guard eventTap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else {
                    return Unmanaged.passUnretained(event)
                }

                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                guard type == .keyDown else {
                    return Unmanaged.passUnretained(event)
                }

                DispatchQueue.main.async {
                    monitor.handleKeyPress(source: "event-tap")
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            let status = AccessibilityGuide.permissionStatus()
            print(
                "Bach keyboard event tap unavailable. accessibility=\(status.accessibilityTrusted) inputMonitoring=\(status.inputMonitoringTrusted)"
            )
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("Bach keyboard event tap started.")
    }

    private func ensureEventTapIsRunning() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            return
        }

        let status = AccessibilityGuide.permissionStatus()
        guard status.keyboardAccessGranted else { return }
        startEventTap()
    }

    private func refreshTrust() {
        let status = AccessibilityGuide.permissionStatus()
        let trusted = status.keyboardAccessGranted
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        onTrustChanged(status)
    }

    private func emitSignal(source: String) {
        onSignal(Signal(source: source, timestamp: Date()))
    }

    private func handleKeyPress(source: String) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastAcceptedKeyTime > 0.035 else { return }
        lastAcceptedKeyTime = now
        emitSignal(source: source)
        onKeyPress()
    }
}
