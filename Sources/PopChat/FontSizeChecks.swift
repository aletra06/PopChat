import AppKit
import SwiftUI

/// A real panel and editor, with local fixture messages and no model requests.
@MainActor
func runFontSizeChecks() async -> Never {
    var log = CheckLog()
    let defaults = UserDefaults.standard
    let savedSize = defaults.object(forKey: ChatTextSize.key)
    defaults.set(16.0, forKey: ChatTextSize.key)
    let scratch = installBenchmarkConversation(minLength: 1)
    let controller = PanelController(providerStore: ProviderStore(), shortcutStore: ShortcutStore())
    controller.show()
    try? await Task.sleep(for: .seconds(1))
    guard let panel = NSApp.windows.first(where: { $0 is FloatingPanel }),
          let editor = composerTextView(in: panel.contentView) else {
        defaults.set(savedSize, forKey: ChatTextSize.key)
        try? FileManager.default.removeItem(at: scratch)
        log.check("panel and composer exist", false)
        log.finish()
    }

    func key(_ character: String, modifiers: NSEvent.ModifierFlags = .command) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                        timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                        characters: character, charactersIgnoringModifiers: character,
                        isARepeat: false, keyCode: 0)!
    }
    func textFields(_ view: NSView?) -> [NSTextField] {
        guard let view else { return [] }
        return (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap { textFields($0) }
    }
    func answerFont() -> CGFloat? {
        guard let field = textFields(panel.contentView).first(where: { $0.stringValue.contains("Some bold prose") }) else { return nil }
        return (field.attributedStringValue.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize
    }
    let beforeFont = answerFont()
    log.check("fixture answer is rendered", beforeFont != nil)
    panel.makeFirstResponder(editor)
    editor.insertText("Keep this draft", replacementRange: NSRange(location: NSNotFound, length: 0))
    editor.setSelectedRange(NSRange(location: 5, length: 4))
    log.check("Command plus is handled by the panel", panel.performKeyEquivalent(with: key("+", modifiers: [.command, .shift])))
    try? await Task.sleep(for: .milliseconds(300))
    log.check("composer grows immediately", editor.font?.pointSize == 17)
    log.check("existing answer grows through Equatable rows", (answerFont() ?? 0) > (beforeFont ?? 0))
    log.check("draft and selection survive", editor.string == "Keep this draft" && editor.selectedRange() == NSRange(location: 5, length: 4))
    log.check("size is persisted", defaults.double(forKey: ChatTextSize.key) == 17)
    log.check("Swedish unshifted plus works", panel.performKeyEquivalent(with: key("+")))
    log.check("unshifted equals works", panel.performKeyEquivalent(with: key("=")))
    log.check("Command minus works", panel.performKeyEquivalent(with: key("-")))
    try? await Task.sleep(for: .milliseconds(300))
    log.check("successive shortcuts reach 18 pt", editor.font?.pointSize == 18)

    editor.undoManager?.undo()
    log.check("resizing preserves native text undo", editor.string.isEmpty)
    editor.undoManager?.redo()
    log.check("redo restores the draft", editor.string == "Keep this draft")

    editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
    editor.setMarkedText("候補", selectedRange: NSRange(location: 2, length: 0),
                         replacementRange: NSRange(location: NSNotFound, length: 0))
    let marked = editor.markedRange()
    _ = panel.performKeyEquivalent(with: key("+"))
    try? await Task.sleep(for: .milliseconds(300))
    log.check("IME composition survives resizing", editor.hasMarkedText() && editor.markedRange() == marked)
    editor.unmarkText()

    _ = panel.performKeyEquivalent(with: key("0"))
    try? await Task.sleep(for: .milliseconds(300))
    log.check("Command zero resets the live composer", editor.font?.pointSize == CGFloat(ChatTextSize.defaultSize))
    log.check("plain typing is not intercepted", !ChatTextSize.handle(key("+", modifiers: [])))
    log.check("Option shortcuts are not intercepted", !ChatTextSize.handle(key("+", modifiers: [.command, .option])))
    defaults.set(32.0, forKey: ChatTextSize.key)
    _ = panel.performKeyEquivalent(with: key("+"))
    try? await Task.sleep(for: .milliseconds(300))
    log.check("upper limit holds", defaults.double(forKey: ChatTextSize.key) == 32)
    log.check("preference changes resize the existing composer", editor.font?.pointSize == 32)
    defaults.set(11.0, forKey: ChatTextSize.key)
    _ = panel.performKeyEquivalent(with: key("-"))
    log.check("lower limit holds", defaults.double(forKey: ChatTextSize.key) == 11)

    let small = MarkdownRenderer.attributedProse("A **bold** word and `code`.", fontSize: 16)
    let large = MarkdownRenderer.attributedProse("A **bold** word and `code`.", fontSize: 24)
    log.check("size changes invalidate prose cache", small !== large)
    log.check("unchanged size retains cached identity", large === MarkdownRenderer.attributedProse("A **bold** word and `code`.", fontSize: 24))
    let rendered = [
        large, MarkdownRenderer.attributedReasoning("Thought", fontSize: 24),
        MarkdownRenderer.highlightedCode("let x = 1", fontSize: 24),
        MarkdownRenderer.tableCell("Cell", fontSize: 24),
        MarkdownRenderer.plain("Pasteable", size: 24),
    ]
    log.check("prose, reasoning, code, tables and plain text use requested size", rendered.allSatisfy {
        ($0.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == 24
    })
    let smallMath = MarkdownRenderer.mathImage("x^2", fontSize: 16, display: false)
    let largeMath = MarkdownRenderer.mathImage("x^2", fontSize: 24, display: false)
    log.check("math grows with text", (largeMath?.size.height ?? 0) > (smallMath?.size.height ?? 0))

    defaults.set(savedSize, forKey: ChatTextSize.key)
    panel.orderOut(nil)
    try? FileManager.default.removeItem(at: scratch)
    withExtendedLifetime(controller) { log.finish() }
}
