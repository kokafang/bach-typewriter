import AppKit

final class PetView: NSView {
    private let imageView = NSImageView()
    private let resizeHandle = ResizeHandleView()
    var onClick: (() -> Void)?
    private let onResize: (NSPoint) -> Void
    private let cellWidth = 192
    private let cellHeight = 208
    private let horizontalInsetRatio: CGFloat = 18.0 / 230.0
    private let bottomInsetRatio: CGFloat = 18.0 / 260.0
    private let topInsetRatio: CGFloat = 34.0 / 260.0
    private var frameImages: [PetState: [NSImage]] = [:]
    private var animationTimer: Timer?
    private var thinkingTimer: Timer?
    private var frameIndex = 0
    private(set) var currentState: PetState = .waiting
    private var isResizing = false
    private var resizeStartLocation: NSPoint = .zero

    init(frame frameRect: NSRect, onResize: @escaping (NSPoint) -> Void) {
        self.onResize = onResize
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setupImageView()
        setupResizeHandle()
        loadFrames()
        setState(.waiting)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if resizeHandle.frame.insetBy(dx: -6, dy: -6).contains(location) {
            isResizing = true
            resizeStartLocation = event.locationInWindow
            return
        }
        onClick?()
        window?.performDrag(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isResizing else {
            super.mouseDragged(with: event)
            return
        }

        let delta = NSPoint(
            x: event.locationInWindow.x - resizeStartLocation.x,
            y: resizeStartLocation.y - event.locationInWindow.y
        )
        resizeStartLocation = event.locationInWindow
        onResize(delta)
    }

    override func mouseUp(with event: NSEvent) {
        isResizing = false
        super.mouseUp(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(resizeHandle.frame.insetBy(dx: -4, dy: -4), cursor: .crosshair)
    }

    override func layout() {
        super.layout()
        layoutImageView()
        layoutResizeHandle()
    }

    func setState(_ state: PetState) {
        currentState = state
        frameIndex = 0
        updateFrame()
        animationTimer?.invalidate()
        thinkingTimer?.invalidate()

        if state.isQuietThinking {
            scheduleThinkingShift()
            return
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: state.frameDuration, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }
    }

    private func setupImageView() {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.magnificationFilter = .nearest
        imageView.layer?.minificationFilter = .nearest
        addSubview(imageView)
        layoutImageView()
    }

    private func setupResizeHandle() {
        resizeHandle.toolTip = "Resize Bach"
        addSubview(resizeHandle)
        layoutResizeHandle()
    }

    private func advanceFrame() {
        guard let frames = frameImages[currentState], !frames.isEmpty else { return }
        frameIndex = (frameIndex + 1) % frames.count
        imageView.image = frames[frameIndex]
    }

    private func updateFrame() {
        imageView.image = frameImages[currentState]?.first
    }

    private func scheduleThinkingShift() {
        let delay = TimeInterval.random(in: 4.5...8.0)
        thinkingTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.brieflyShiftThinkingFrame()
        }
    }

    private func brieflyShiftThinkingFrame() {
        guard currentState.isQuietThinking else { return }
        guard let frames = frameImages[currentState], frames.count > 1 else {
            scheduleThinkingShift()
            return
        }

        frameIndex = (frameIndex % (frames.count - 1)) + 1
        imageView.image = frames[frameIndex]

        thinkingTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            guard let self, self.currentState.isQuietThinking else { return }
            self.frameIndex = 0
            self.updateFrame()
            self.scheduleThinkingShift()
        }
    }

    private func loadFrames() {
        guard
            let url = Bundle.module.url(forResource: "spritesheet", withExtension: "png"),
            let source = NSImage(contentsOf: url),
            let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return
        }

        let totalHeight = cgImage.height
        let totalWidth = cgImage.width
        guard totalWidth >= cellWidth * 8, totalHeight >= cellHeight * 9 else {
            return
        }

        for state in [PetState.idle, .runningRight, .runningLeft, .waving, .jumping, .failed, .waiting, .running, .review] {
            var frames: [NSImage] = []
            for column in 0..<state.frames {
                let x = column * cellWidth
                let y = totalHeight - ((state.row + 1) * cellHeight)
                let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                guard let cropped = cgImage.cropping(to: rect) else { continue }
                let image = NSImage(cgImage: cropped, size: NSSize(width: cellWidth, height: cellHeight))
                frames.append(image)
            }
            frameImages[state] = frames
        }
    }

    private func layoutImageView() {
        let horizontalInset = bounds.width * horizontalInsetRatio
        let bottomInset = bounds.height * bottomInsetRatio
        let topInset = bounds.height * topInsetRatio
        let availableWidth = max(bounds.width - (horizontalInset * 2), 1)
        let availableHeight = max(bounds.height - bottomInset - topInset, 1)
        let spriteAspect = CGFloat(cellWidth) / CGFloat(cellHeight)
        let width = min(availableWidth, availableHeight * spriteAspect)
        let height = width / spriteAspect
        let x = (bounds.width - width) / 2.0
        let y = bottomInset + max((availableHeight - height) / 2.0, 0)
        imageView.frame = NSRect(x: x, y: y, width: width, height: height)
    }

    private func layoutResizeHandle() {
        let size: CGFloat = 20
        resizeHandle.frame = NSRect(
            x: bounds.width - size - 6,
            y: 6,
            width: size,
            height: size
        )
    }
}

private final class ResizeHandleView: NSView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath()
        path.lineWidth = 1.6
        path.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.82).setStroke()

        let inset: CGFloat = 3
        let spacing: CGFloat = 5
        let maxX = bounds.maxX - inset
        let minY = bounds.minY + inset
        let maxY = bounds.maxY - inset

        path.move(to: NSPoint(x: maxX, y: minY))
        path.line(to: NSPoint(x: bounds.minX + inset, y: maxY))

        path.move(to: NSPoint(x: maxX, y: minY + spacing))
        path.line(to: NSPoint(x: bounds.minX + inset + spacing, y: maxY))

        path.move(to: NSPoint(x: maxX, y: minY + spacing * 2))
        path.line(to: NSPoint(x: bounds.minX + inset + spacing * 2, y: maxY))
        path.stroke()
    }
}
