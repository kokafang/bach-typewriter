import AppKit
import ApplicationServices

enum AccessibilityGuide {
    struct PermissionStatus {
        let accessibilityTrusted: Bool
        let inputMonitoringTrusted: Bool

        var keyboardAccessGranted: Bool {
            accessibilityTrusted && inputMonitoringTrusted
        }

        var menuTitle: String {
            if keyboardAccessGranted {
                return "Keyboard Access Granted"
            }
            if !inputMonitoringTrusted {
                return "Open Input Monitoring Settings"
            }
            return "Open Accessibility Settings"
        }
    }

    static func isTrusted() -> Bool {
        permissionStatus().keyboardAccessGranted
    }

    static func permissionStatus() -> PermissionStatus {
        PermissionStatus(
            accessibilityTrusted: AXIsProcessTrusted(),
            inputMonitoringTrusted: isInputMonitoringTrusted()
        )
    }

    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func promptIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        requestInputMonitoringIfNeeded()
    }

    static func openSystemSettings() {
        let status = permissionStatus()
        let urlString: String
        if !status.inputMonitoringTrusted {
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        } else {
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func isInputMonitoringTrusted() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightListenEventAccess()
        }
        return true
    }

    private static func requestInputMonitoringIfNeeded() {
        guard #available(macOS 10.15, *) else { return }
        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
    }
}
