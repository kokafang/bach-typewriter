import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindowController: PetWindowController?
    private var keyboardMonitor: KeyboardMonitor?
    private var statusController: StatusBarController?
    private let soundEngine = SoundEngine()
    private let melodyPlayer = MelodyPlayer()
    private var keepFrontObserver: NSObjectProtocol?
    private var typingNotesEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let petWindowController = PetWindowController(
            onPetTap: { [weak self] in
                self?.handlePetTap()
            }
        )
        self.petWindowController = petWindowController
        petWindowController.showWindow(nil)
        petWindowController.window?.makeKeyAndOrderFront(nil)

        statusController = StatusBarController(
            onShow: { [weak petWindowController] in
                petWindowController?.showWindow(nil)
                petWindowController?.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            },
            onToggleTypingNotes: { [weak self] in
                self?.toggleTypingNotes()
            },
            onPlayTestNote: { [weak self] in
                self?.playTestNote()
            },
            onToggleSound: { [weak self] in
                self?.toggleSound()
            },
            onOpenAccessibility: {
                AccessibilityGuide.openSystemSettings()
            },
            onSelectInstrument: { [weak self] instrument in
                self?.selectInstrument(instrument)
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        keyboardMonitor = KeyboardMonitor(
            onKeyPress: { [weak self] in
                self?.handleTypingKeyPress()
            },
            onTrustChanged: { [weak self] status in
                self?.petWindowController?.setState(status.keyboardAccessGranted ? .idle : .waiting)
                self?.statusController?.setPermissionStatus(status)
            },
            onSignal: { [weak self] signal in
                self?.statusController?.setLastKeySignal(Self.format(signal: signal))
            }
        )

        statusController?.setTypingNotesEnabled(typingNotesEnabled)
        statusController?.setSoundEnabled(soundEngine.isEnabled)
        statusController?.setSelectedInstrument(soundEngine.instrument)
        statusController?.setPermissionStatus(AccessibilityGuide.permissionStatus())
        statusController?.setLastKeySignal("waiting")
        petWindowController.setState(.idle)
        keepFrontObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.petWindowController?.keepInFront()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keepFrontObserver {
            NotificationCenter.default.removeObserver(keepFrontObserver)
        }
    }

    private func handleTypingKeyPress() {
        guard typingNotesEnabled else { return }
        playNextNote()
    }

    private func handlePetTap() {
        playNextNote()
    }

    private func playNextNote() {
        let note = melodyPlayer.next()
        print("Bach key press -> \(note.frequency)")
        soundEngine.play(note: note)
        petWindowController?.setState(.running)
        petWindowController?.scheduleReturnToIdle()
    }

    private func playTestNote() {
        soundEngine.playTestNote()
        petWindowController?.setState(.review)
        petWindowController?.scheduleReturnToIdle()
    }

    private func toggleTypingNotes() {
        typingNotesEnabled.toggle()
        statusController?.setTypingNotesEnabled(typingNotesEnabled)
        petWindowController?.setState(typingNotesEnabled ? .idle : .review)
        petWindowController?.scheduleReturnToIdle()
    }

    private func toggleSound() {
        soundEngine.isEnabled.toggle()
        statusController?.setSoundEnabled(soundEngine.isEnabled)
        petWindowController?.setState(soundEngine.isEnabled ? .review : .failed)
        petWindowController?.scheduleReturnToIdle()
    }

    private func selectInstrument(_ instrument: SoundEngine.Instrument) {
        soundEngine.instrument = instrument
        statusController?.setSelectedInstrument(instrument)
        playTestNote()
    }

    private static func format(signal: KeyboardMonitor.Signal) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "\(signal.source) @ \(formatter.string(from: signal.timestamp))"
    }
}
