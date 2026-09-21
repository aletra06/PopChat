import AppKit

/// A location, independent of panel height. The horizontal center follows the
/// display when its resolution changes; the top edge stays the same distance
/// below the menu bar. Display origins can move without invalidating the anchor.
struct PanelAnchor: Codable {
    var displayID: UInt32
    var centerFraction: Double
    var topInset: Double

    init(frame: NSRect, visibleFrame: NSRect, displayID: UInt32) {
        self.displayID = displayID
        centerFraction = (frame.midX - visibleFrame.minX) / visibleFrame.width
        topInset = visibleFrame.maxY - frame.maxY
    }

    func frame(size: NSSize, on visible: NSRect) -> NSRect {
        let size = NSSize(width: min(size.width, visible.width), height: min(size.height, visible.height))
        let x = visible.minX + centerFraction * visible.width - size.width / 2
        let y = visible.maxY - topInset - size.height
        return NSRect(x: min(max(x, visible.minX), visible.maxX - size.width),
                      y: min(max(y, visible.minY), visible.maxY - size.height),
                      width: size.width, height: size.height)
    }
}

/// Snap decisions use the unsnapped pointer position, so the window can leave
/// either target naturally. A wider release radius prevents boundary jitter.
struct PanelSnap {
    private(set) var atDefault = false
    private(set) var atCenter = false

    mutating func frame(for proposed: NSRect, defaultFrame: NSRect, screen: NSRect) -> NSRect {
        let distance = hypot(proposed.midX - defaultFrame.midX, proposed.maxY - defaultFrame.maxY)
        atDefault = distance <= (atDefault ? 30 : 18)
        if atDefault {
            atCenter = false
            return defaultFrame
        }
        atCenter = abs(proposed.midX - screen.midX) <= (atCenter ? 22 : 12)
        var result = proposed
        if atCenter { result.origin.x = screen.midX - proposed.width / 2 }
        return result
    }
}

@MainActor
final class PanelPlacement {
    static let defaultsKey = "panelDefaultLocation"
    private unowned let window: FloatingPanel
    private let state: PanelState
    private let defaults: UserDefaults
    private var anchor: PanelAnchor?
    private var dragStart: (point: NSPoint, frame: NSRect)?
    private var snap = PanelSnap()
    private var screenObserver: NSObjectProtocol?
    private var fallbackDisplayID: UInt32?
    private let outline = PlacementGuide(centerline: false)
    private let centerline = PlacementGuide(centerline: true)

    init(window: FloatingPanel, state: PanelState, defaults: UserDefaults = .standard) {
        self.window = window
        self.state = state
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(PanelAnchor.self, from: data),
           saved.centerFraction.isFinite, saved.topInset.isFinite {
            anchor = saved
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.window.isVisible else { return }
                self.endDrag()
                self.fallbackDisplayID = nil
                self.keepOnAvailableDisplay()
            }
        }
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    private static func displayID(_ screen: NSScreen) -> UInt32 {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    var defaultScreen: NSScreen? {
        guard let anchor else { return nil }
        if let saved = NSScreen.screens.first(where: { Self.displayID($0) == anchor.displayID }) { return saved }
        if let fallback = NSScreen.screens.first(where: { Self.displayID($0) == fallbackDisplayID }) { return fallback }
        let fallback = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        fallbackDisplayID = fallback.map(Self.displayID)
        return fallback
    }

    private var defaultFrame: NSRect? {
        guard let anchor, let screen = defaultScreen else { return nil }
        return anchor.frame(size: window.frame.size, on: screen.visibleFrame)
    }

    func restoreDefault() {
        guard let frame = defaultFrame else { return }
        window.setFrame(frame, display: window.isVisible)
        refreshLocationStatus()
    }

    /// Preserve the session position unless its display disappeared and the
    /// window is no longer reachable. Recover onto a screen without using the
    /// default location or changing the saved anchor.
    func keepOnAvailableDisplay() {
        let reachable = NSScreen.screens.contains { screen in
            let overlap = window.frame.intersection(screen.visibleFrame)
            return overlap.width >= 120 && overlap.height >= 80
        }
        if !reachable, let screen = NSScreen.main ?? NSScreen.screens.first {
            let current = PanelAnchor(frame: window.frame, visibleFrame: screen.visibleFrame, displayID: 0)
            window.setFrame(current.frame(size: window.frame.size, on: screen.visibleFrame), display: window.isVisible)
        }
        refreshLocationStatus()
    }

    func saveDefault() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        anchor = PanelAnchor(frame: window.frame, visibleFrame: screen.visibleFrame, displayID: Self.displayID(screen))
        if let data = try? JSONEncoder().encode(anchor) { defaults.set(data, forKey: Self.defaultsKey) }
        state.awayFromDefaultLocation = false
    }

    func refreshLocationStatus() {
        guard let target = defaultFrame else { return }
        state.awayFromDefaultLocation = abs(window.frame.midX - target.midX) > 2
            || abs(window.frame.maxY - target.maxY) > 2
    }

    func prepareDrag(at point: NSPoint) {
        endDrag()
        dragStart = (point, window.frame)
        snap = PanelSnap()
    }

    func drag(to point: NSPoint) {
        guard let start = dragStart, let target = defaultFrame else { return }
        if !state.draggingWindow {
            guard hypot(point.x - start.point.x, point.y - start.point.y) >= 2 else { return }
            state.draggingWindow = true
            state.defaultLocationPromptDismissed = false
        }
        // The composer or a first response can change the height mid-drag.
        // Keep the grabbed top edge under the pointer using the current size.
        let size = window.frame.size
        var proposed = NSRect(x: start.frame.midX + point.x - start.point.x - size.width / 2,
                              y: start.frame.maxY + point.y - start.point.y - size.height,
                              width: size.width, height: size.height)
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })
            ?? window.screen else { return }
        // Keep the drag strip reachable, including on displays above or left of
        // the primary display. Do not clamp x: the window can cross displays.
        proposed.origin.y = min(proposed.origin.y, screen.visibleFrame.maxY - proposed.height)
        proposed.origin.y = max(proposed.origin.y, screen.visibleFrame.minY + 40 - proposed.height)
        let frame = snap.frame(for: proposed, defaultFrame: target, screen: screen.frame)
        window.setFrameOrigin(frame.origin)
        outline.show(frame: target.insetBy(dx: -4, dy: -4), above: window, highlighted: snap.atDefault)
        if snap.atCenter {
            centerline.show(frame: NSRect(x: screen.frame.midX - 1, y: screen.visibleFrame.minY,
                                         width: 2, height: screen.visibleFrame.height), above: window, highlighted: true)
        } else {
            centerline.hide()
        }
    }

    func endDrag() {
        dragStart = nil
        outline.hide()
        centerline.hide()
        state.draggingWindow = false
        refreshLocationStatus()
    }
}

/// Noninteractive guide windows never take focus or intercept the drag.
@MainActor
private final class PlacementGuide {
    private let panel: NSPanel
    private let drawing: GuideDrawing

    init(centerline: Bool) {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        drawing = GuideDrawing(centerline: centerline)
        panel.contentView = drawing
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.level = .floating
    }

    func show(frame: NSRect, above window: NSWindow, highlighted: Bool) {
        drawing.highlighted = highlighted
        panel.setFrame(frame, display: true)
        panel.order(drawing.centerline ? .below : .above, relativeTo: window.windowNumber)
    }

    func hide() { panel.orderOut(nil) }
}

private final class GuideDrawing: NSView {
    let centerline: Bool
    var highlighted = false { didSet { if oldValue != highlighted { needsDisplay = true } } }

    init(centerline: Bool) {
        self.centerline = centerline
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let path: NSBezierPath
        if centerline {
            path = NSBezierPath()
            path.move(to: NSPoint(x: bounds.midX, y: bounds.minY))
            path.line(to: NSPoint(x: bounds.midX, y: bounds.maxY))
        } else {
            path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 26, yRadius: 26)
        }
        path.setLineDash([6, 5], count: 2, phase: 0)
        NSColor.black.withAlphaComponent(0.45).setStroke()
        path.lineWidth = centerline ? 2 : 3
        path.stroke()
        let accent = Theme.nsColor(UserDefaults.standard.string(forKey: "accentColor") ?? Theme.defaultAccentHex)
        (highlighted ? accent : NSColor.white.withAlphaComponent(0.9)).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }
}
