import AppKit

@MainActor
func runPlacementChecks(preview: Bool = false) async -> Never {
    var log = CheckLog()
    let suite = "PopChat.PlacementChecks.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let scratch = installBenchmarkConversation(minLength: 1)
    let controller = PanelController(providerStore: ProviderStore(), shortcutStore: ShortcutStore(), placementDefaults: defaults)
    controller.state.pinned = true
    controller.show()
    try? await Task.sleep(for: .milliseconds(500))
    guard let window = NSApp.windows.first(where: { $0 is FloatingPanel }) as? FloatingPanel,
          let placement = window.placement, let screen = window.screen else {
        log.check("real panel and placement controller exist", false)
        log.finish()
    }
    let visible = screen.visibleFrame
    window.setFrame(NSRect(x: visible.midX - 290, y: visible.midY - 150, width: 580, height: 320), display: true)
    placement.saveDefault()
    if preview {
        controller.onUserDismiss = {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: scratch)
            exit(0)
        }
        if CommandLine.arguments.contains("--show-guide") {
            placement.prepareDrag(at: NSPoint(x: visible.midX, y: visible.midY))
            placement.drag(to: NSPoint(x: visible.midX + 150, y: visible.midY + 100))
        }
        // Retain the real controller and report positions during manual checks.
        var lastFrame = NSRect.zero
        while true {
            if window.frame != lastFrame {
                lastFrame = window.frame
                print("preview frame=\(lastFrame) dragging=\(controller.state.draggingWindow) away=\(controller.state.awayFromDefaultLocation)")
                fflush(stdout)
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    let original = window.frame
    let saved = defaults.data(forKey: PanelPlacement.defaultsKey)
    let pointer = NSPoint(x: original.midX, y: original.maxY - 15)
    let keyBeforeDrag = NSApp.keyWindow
    placement.prepareDrag(at: pointer)
    placement.drag(to: NSPoint(x: pointer.x + 110, y: pointer.y - 60))
    log.check("drag moves the real window", abs(window.frame.minX - original.minX - 110) < 1)
    let guides = NSApp.windows.filter { $0 !== window && $0.isVisible && $0.ignoresMouseEvents }
    log.check("default outline appears without intercepting mouse events", !guides.isEmpty)
    log.check("guide does not take keyboard focus", NSApp.keyWindow === keyBeforeDrag && guides.allSatisfy { !$0.isKeyWindow })
    placement.endDrag()
    log.check("guide disappears on release", guides.allSatisfy { !$0.isVisible })
    log.check("moving away offers saving", controller.state.awayFromDefaultLocation)
    log.check("dragging never overwrites the default", defaults.data(forKey: PanelPlacement.defaultsKey) == saved)

    let movedFrame = window.frame
    controller.hide()
    try? await Task.sleep(for: .milliseconds(200))
    controller.show()
    try? await Task.sleep(for: .milliseconds(250))
    log.check("hide and reopen preserve the temporary location", window.frame.origin == movedFrame.origin)
    log.check("hide and reopen dismiss the save action", controller.state.defaultLocationPromptDismissed)
    placement.prepareDrag(at: pointer)
    placement.endDrag()
    log.check("clicking the header does not reshow the action", controller.state.defaultLocationPromptDismissed)

    placement.prepareDrag(at: pointer)
    placement.drag(to: NSPoint(x: pointer.x - 102, y: pointer.y + 54))
    log.check("nearby drop snaps exactly to default", window.frame.origin == original.origin)
    placement.endDrag()
    log.check("saving prompt disappears at default", !controller.state.awayFromDefaultLocation)

    // A new drag starts from the snapped frame, and pulls away without trapping
    // the pointer at the target. The unsnapped y remains free on the centerline.
    placement.prepareDrag(at: pointer)
    placement.drag(to: NSPoint(x: pointer.x + 7, y: pointer.y - 90))
    log.check("display center snaps independently of default", abs(window.frame.midX - screen.frame.midX) < 1)
    log.check("center snapping preserves vertical movement", abs(window.frame.maxY - original.maxY + 90) < 1)
    placement.drag(to: NSPoint(x: pointer.x + 50, y: pointer.y - 90))
    log.check("pulling away releases the snap", abs(window.frame.midX - original.midX - 50) < 1)
    let draggedTop = window.frame.maxY
    var grown = window.frame
    grown.origin.y -= 50
    grown.size.height += 50
    window.setFrame(grown, display: true)
    placement.drag(to: NSPoint(x: pointer.x + 50, y: pointer.y - 90))
    log.check("content growth during drag preserves the grabbed top edge", window.frame.maxY == draggedTop)
    placement.endDrag()
    log.check("moving again restores the save action", controller.state.awayFromDefaultLocation && !controller.state.defaultLocationPromptDismissed)
    placement.saveDefault()
    log.check("explicit save replaces default and hides prompt", defaults.data(forKey: PanelPlacement.defaultsKey) != saved && !controller.state.awayFromDefaultLocation)
    let newDefault = window.frame
    window.setFrameOrigin(NSPoint(x: original.minX + 180, y: original.minY))
    placement.restoreDefault()
    log.check("explicit restore uses chosen default", window.frame == newDefault)
    let reloaded = PanelPlacement(window: window, state: controller.state, defaults: defaults)
    window.setFrameOrigin(original.origin)
    reloaded.restoreDefault()
    log.check("default survives a new controller", window.frame == newDefault)

    let foreign = NSRect(x: -1800, y: 900, width: 1600, height: 1000)
    let frame = NSRect(x: -1290, y: 1400, width: 580, height: 320)
    let anchor = PanelAnchor(frame: frame, visibleFrame: foreign, displayID: 42)
    let movedDisplay = foreign.offsetBy(dx: 2300, dy: -700)
    let migrated = anchor.frame(size: frame.size, on: movedDisplay)
    log.check("display rearrangement preserves relative location", migrated.origin == frame.offsetBy(dx: 2300, dy: -700).origin)
    let taller = anchor.frame(size: NSSize(width: 680, height: 500), on: foreign)
    log.check("size changes preserve top and horizontal center", taller.maxY == frame.maxY && taller.midX == frame.midX)
    let small = NSRect(x: 0, y: 0, width: 800, height: 600)
    let fitted = anchor.frame(size: NSSize(width: 2000, height: 1500), on: small)
    log.check("missing or smaller display keeps the entire panel reachable", small.contains(fitted))

    var snapping = PanelSnap()
    let target = NSRect(x: 200, y: 200, width: 580, height: 320)
    _ = snapping.frame(for: target.offsetBy(dx: 16, dy: 0), defaultFrame: target, screen: small)
    log.check("snap enters at 18 points", snapping.atDefault)
    _ = snapping.frame(for: target.offsetBy(dx: 26, dy: 0), defaultFrame: target, screen: small)
    log.check("snap holds near boundary", snapping.atDefault)
    _ = snapping.frame(for: target.offsetBy(dx: 40, dy: 0), defaultFrame: target, screen: small)
    log.check("snap releases beyond 30 points", !snapping.atDefault)

    window.setFrameOrigin(NSPoint(x: newDefault.minX + 80, y: newDefault.minY))
    placement.refreshLocationStatus()
    let savedHistory = UserDefaults.standard.object(forKey: "promptHistory")
    if let editor = composerTextView(in: window.contentView) {
        window.makeFirstResponder(editor)
        // Unknown shortcuts fail locally, so this exercises the real send
        // action without contacting a provider or spending model quota.
        editor.insertText("/__placement_check_unknown__", replacementRange: NSRange(location: NSNotFound, length: 0))
        _ = sendKey("\r", keyCode: 36, to: window)
        try? await Task.sleep(for: .milliseconds(200))
        log.check("sending a prompt dismisses the location action", controller.state.defaultLocationPromptDismissed)
    } else {
        log.check("composer exists for the send check", false)
    }
    UserDefaults.standard.set(savedHistory, forKey: "promptHistory")
    controller.hide()
    try? await Task.sleep(for: .milliseconds(200))
    controller.show()
    try? await Task.sleep(for: .milliseconds(250))
    log.check("reopening does not reshow the dismissed action", controller.state.defaultLocationPromptDismissed)
    placement.prepareDrag(at: pointer)
    placement.drag(to: NSPoint(x: pointer.x + 40, y: pointer.y))
    placement.endDrag()
    log.check("another drag offers saving the location again", !controller.state.defaultLocationPromptDismissed && controller.state.awayFromDefaultLocation)
    let beforeNewChat = window.frame
    controller.chatStore.newChat()
    try? await Task.sleep(for: .milliseconds(500))
    log.check("new chat preserves horizontal center and top edge",
              abs(window.frame.midX - beforeNewChat.midX) < 1 && abs(window.frame.maxY - beforeNewChat.maxY) < 1)
    let emptyFrame = window.frame
    controller.hide()
    try? await Task.sleep(for: .milliseconds(200))
    controller.show()
    try? await Task.sleep(for: .milliseconds(250))
    log.check("empty chat keeps its top edge and center when the link disappears",
              abs(window.frame.midX - emptyFrame.midX) < 1 && abs(window.frame.maxY - emptyFrame.maxY) < 1)

    controller.hide()
    try? await Task.sleep(for: .milliseconds(200))
    let restarted = PanelController(providerStore: ProviderStore(), shortcutStore: ShortcutStore(), placementDefaults: defaults)
    restarted.state.pinned = true
    restarted.show()
    try? await Task.sleep(for: .milliseconds(500))
    let restartedWindow = NSApp.windows.first { $0 is FloatingPanel && $0 !== window && $0.isVisible }
    log.check("a fresh app controller restores the default", restartedWindow.map {
        abs($0.frame.midX - newDefault.midX) < 1 && abs($0.frame.maxY - newDefault.maxY) < 1
    } ?? false)
    restarted.hide()

    controller.hide()
    try? await Task.sleep(for: .milliseconds(200))
    defaults.removePersistentDomain(forName: suite)
    try? FileManager.default.removeItem(at: scratch)
    log.finish()
}
