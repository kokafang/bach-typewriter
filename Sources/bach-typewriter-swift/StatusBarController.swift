import AppKit

final class StatusBarController {
    typealias Instrument = SoundEngine.Instrument

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let typingNotesItem = NSMenuItem()
    private let testNoteItem = NSMenuItem()
    private let soundItem = NSMenuItem()
    private let trustItem = NSMenuItem()
    private let signalItem = NSMenuItem()
    private let instrumentMenuItem = NSMenuItem(title: "Instrument", action: nil, keyEquivalent: "")
    private let instrumentMenu = NSMenu()
    private var instrumentItems: [Instrument: NSMenuItem] = [:]

    init(
        onShow: @escaping () -> Void,
        onToggleTypingNotes: @escaping () -> Void,
        onPlayTestNote: @escaping () -> Void,
        onToggleSound: @escaping () -> Void,
        onOpenAccessibility: @escaping () -> Void,
        onSelectInstrument: @escaping (Instrument) -> Void,
        onQuit: @escaping () -> Void
    ) {
        statusItem.button?.title = "Bach"

        menu.addItem(withTitle: "Show Bach", action: #selector(CallbackTarget.handleShow), keyEquivalent: "")
        menu.items.last?.target = CallbackTarget.shared
        CallbackTarget.shared.onShow = onShow

        typingNotesItem.title = "Pause Typing Notes"
        typingNotesItem.action = #selector(CallbackTarget.handleToggleTypingNotes)
        typingNotesItem.target = CallbackTarget.shared
        CallbackTarget.shared.onToggleTypingNotes = onToggleTypingNotes
        menu.addItem(typingNotesItem)

        testNoteItem.title = "Play Test Note"
        testNoteItem.action = #selector(CallbackTarget.handlePlayTestNote)
        testNoteItem.target = CallbackTarget.shared
        CallbackTarget.shared.onPlayTestNote = onPlayTestNote
        menu.addItem(testNoteItem)

        soundItem.title = "Mute Sound"
        soundItem.action = #selector(CallbackTarget.handleToggleSound)
        soundItem.target = CallbackTarget.shared
        CallbackTarget.shared.onToggleSound = onToggleSound
        menu.addItem(soundItem)

        instrumentMenuItem.submenu = instrumentMenu
        menu.addItem(instrumentMenuItem)
        CallbackTarget.shared.onSelectInstrument = onSelectInstrument
        configureInstrumentMenu()

        menu.addItem(.separator())
        signalItem.title = "Last Key Signal: waiting"
        signalItem.isEnabled = false
        menu.addItem(signalItem)

        menu.addItem(.separator())
        trustItem.title = "Accessibility Not Granted"
        trustItem.action = #selector(CallbackTarget.handleAccessibility)
        trustItem.target = CallbackTarget.shared
        CallbackTarget.shared.onOpenAccessibility = onOpenAccessibility
        menu.addItem(trustItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(CallbackTarget.handleQuit), keyEquivalent: "q")
        menu.items.last?.target = CallbackTarget.shared
        CallbackTarget.shared.onQuit = onQuit

        statusItem.menu = menu
    }

    func setSoundEnabled(_ enabled: Bool) {
        soundItem.title = enabled ? "Mute Sound" : "Unmute Sound"
    }

    func setTypingNotesEnabled(_ enabled: Bool) {
        typingNotesItem.title = enabled ? "Pause Typing Notes" : "Resume Typing Notes"
    }

    func setPermissionStatus(_ status: AccessibilityGuide.PermissionStatus) {
        trustItem.title = status.menuTitle
        trustItem.isEnabled = !status.keyboardAccessGranted
    }

    func setLastKeySignal(_ text: String) {
        signalItem.title = "Last Key Signal: \(text)"
    }

    func setSelectedInstrument(_ instrument: Instrument) {
        for (candidate, item) in instrumentItems {
            item.state = candidate == instrument ? .on : .off
        }
    }

    private func configureInstrumentMenu() {
        for instrument in Instrument.allCases {
            let item = NSMenuItem(
                title: instrument.menuTitle,
                action: #selector(CallbackTarget.handleInstrumentSelection(_:)),
                keyEquivalent: ""
            )
            item.target = CallbackTarget.shared
            item.tag = instrument.rawValue
            instrumentMenu.addItem(item)
            instrumentItems[instrument] = item
        }
    }
}

private final class CallbackTarget: NSObject {
    static let shared = CallbackTarget()

    var onShow: (() -> Void)?
    var onToggleTypingNotes: (() -> Void)?
    var onPlayTestNote: (() -> Void)?
    var onToggleSound: (() -> Void)?
    var onOpenAccessibility: (() -> Void)?
    var onSelectInstrument: ((SoundEngine.Instrument) -> Void)?
    var onQuit: (() -> Void)?

    @objc func handleShow() { onShow?() }
    @objc func handleToggleTypingNotes() { onToggleTypingNotes?() }
    @objc func handlePlayTestNote() { onPlayTestNote?() }
    @objc func handleToggleSound() { onToggleSound?() }
    @objc func handleAccessibility() { onOpenAccessibility?() }
    @objc func handleInstrumentSelection(_ sender: NSMenuItem) {
        guard let instrument = SoundEngine.Instrument(rawValue: sender.tag) else { return }
        onSelectInstrument?(instrument)
    }
    @objc func handleQuit() { onQuit?() }
}
