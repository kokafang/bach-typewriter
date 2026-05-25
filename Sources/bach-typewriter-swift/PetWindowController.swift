import AppKit

final class PetWindowController: NSWindowController {
    private let baseSize = NSSize(width: 230, height: 260)
    private lazy var petView = PetView(
        frame: NSRect(origin: .zero, size: baseSize),
        onResize: { [weak self] delta in
            self?.resizePet(by: delta)
        }
    )
    private var idleTimer: Timer?
    private var keepFrontTimer: Timer?

    init(onPetTap: @escaping () -> Void) {
        let panel = FloatingPetPanel(
            contentRect: NSRect(x: 100, y: 100, width: 230, height: 260),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.onKeyPress = onPetTap
        super.init(window: panel)
        petView.onClick = onPetTap
        setupWindow(panel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setState(_ state: PetState) {
        petView.setState(state)
    }

    func scheduleReturnToIdle() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { [weak self] _ in
            self?.petView.setState(.idle)
        }
    }

    func keepInFront() {
        guard let window else { return }
        window.level = .screenSaver
        window.orderFrontRegardless()
    }

    private func setupWindow(_ window: NSPanel) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isFloatingPanel = true
        window.canHide = false
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 138, height: 156)
        window.maxSize = NSSize(width: 552, height: 624)
        window.contentView = petView
        window.makeFirstResponder(window.contentView)
        window.orderFrontRegardless()
        startKeepFrontTimer()
    }

    private func resizePet(by delta: NSPoint) {
        guard let window else { return }

        let widthFromHeight = delta.y * (baseSize.width / baseSize.height)
        let widthDelta = max(delta.x, widthFromHeight)
        var newWidth = window.frame.width + widthDelta
        newWidth = min(max(newWidth, window.minSize.width), window.maxSize.width)
        let newHeight = newWidth * (baseSize.height / baseSize.width)

        var frame = window.frame
        frame.size = NSSize(width: newWidth, height: newHeight)
        frame.origin.y = window.frame.maxY - newHeight
        window.setFrame(frame, display: true)
    }

    private func startKeepFrontTimer() {
        keepFrontTimer?.invalidate()
        let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.keepInFront()
        }
        keepFrontTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}

final class FloatingPetPanel: NSPanel {
    var onKeyPress: (() -> Void)?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        onKeyPress?()
        super.keyDown(with: event)
    }
}
