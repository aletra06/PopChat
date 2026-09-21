import AppKit

let highlightingExample = #"""
Here's a breadth-first search class in Python:

<pasteable title="BFS search class">
from collections import deque

class BFS:
    def __init__(self, graph):
        self.graph = graph

    def search(self, start, target):
        queue = deque([start])
        visited = {start}
        while queue:
            node = queue.popleft()
            if node == target:
                return True
            for neighbor in self.graph.get(node, []):
                if neighbor not in visited:
                    visited.add(neighbor)
                    queue.append(neighbor)
        return False

print(BFS({"A": ["B"]}).search("A", "B"))
</pasteable>

This ordinary copyable note stays plain:

<pasteable title="Note">
Hi Alex, thanks for your help. See you tomorrow!
</pasteable>
"""#

func highlightingColors(_ text: NSAttributedString) -> Set<NSColor> {
    var colors = Set<NSColor>()
    text.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: text.length)) { value, _, _ in
        if let color = value as? NSColor { colors.insert(color) }
    }
    return colors
}

/// Check the last glyph in the real card, independently of its sizing routine.
@MainActor
func highlightingCardFits(in view: NSView) -> Bool {
    if let field = view as? NSTextField, field.stringValue.hasPrefix("from collections") {
        guard field.stringValue.hasSuffix(#"print(BFS({"A": ["B"]}).search("A", "B"))"#) else { return false }
        let storage = NSTextStorage(attributedString: field.attributedStringValue)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: field.bounds.width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        layout.ensureLayout(for: container)
        return layout.usedRect(for: container).height <= field.bounds.height
    }
    return view.subviews.contains { highlightingCardFits(in: $0) }
}

@MainActor
func runHighlightingChecks() -> Never {
    var log = CheckLog()
    let python = "from collections import deque\n\nclass BFS:\n    def search(self, start):\n        return [start, None, True, 42, \"🧮 <tag> &amp; é\"] # comment\n"
    let oldCard = "<pasteable title=\"BFS search class\">\n\(python)</pasteable>"
    let segments = MarkdownRenderer.segments(oldCard)
    if case .pasteable(let title, let language, let content) = segments.first {
        log.check("old card parses without language metadata", title == "BFS search class" && language == nil)
        let rendered = MarkdownRenderer.pasteableText(content, fontSize: 18)
        log.check("existing Python cards gain highlighting", highlightingColors(rendered).count >= 4)
        log.check("display and copy source stay identical", rendered.string == content)
        log.check("find searches the original code", MarkdownRenderer.searchableStrings(segments[0]) == [content])
        log.check("stable cards reuse cached attributed text", rendered === MarkdownRenderer.pasteableText(content, fontSize: 18))
        let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        log.check("code uses the saved size and a monospaced font", font?.pointSize == 18 && font?.isFixedPitch == true)
    } else {
        log.check("old card parses", false)
    }
    let tagged = MarkdownRenderer.segments("<pasteable title=\"Example\" language='js'>\nconst greeting = \"hello\";\n</pasteable>")
    if case .pasteable(_, let language, let content) = tagged.first {
        log.check("language attribute reaches the card", language == "js")
        log.check("JavaScript alias highlights", highlightingColors(MarkdownRenderer.pasteableText(content, language: language, fontSize: 18)).count >= 3)
    } else {
        log.check("tagged card parses", false)
    }
    for (language, code) in [
        ("python", python),
        ("typescript", "interface Person { name: string }\nconst person: Person = { name: 'Alex' };"),
        ("swift", "func greet() -> String { return \"Hello\" }"),
        ("json", "{\"name\": \"Alex\", \"count\": 42, \"active\": true}"),
        ("bash", "#!/bin/bash\necho \"Hello $USER\" # greeting"),
        ("rust", "fn main() { let n = 42; println!(\"{}\", n); }"),
        ("html", "<div class=\"test\">&amp; &lt; 😀</div>"),
    ] {
        let dark = MarkdownRenderer.highlightedCode(code, language: language, fontSize: 18)
        let light = MarkdownRenderer.highlightedCode(code, language: language, dark: false, fontSize: 24)
        log.check("\(language) renders in both themes", highlightingColors(dark).count >= 3 && highlightingColors(light).count >= 3)
        log.check("\(language) preserves every source character", dark.string == code && light.string == code)
        log.check("\(language) theme and size invalidate cache", dark !== light && (light.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == 24)
    }
    for prose in ["Hi Alex, thanks for your help. See you tomorrow!", "Write a class that searches a graph.\nReturn the shortest path.", "Price: $42.\nPlease import the documents."] {
        let text = MarkdownRenderer.pasteableText(prose, fontSize: 18)
        log.check("copyable prose stays plain", text.string == prose && highlightingColors(text).count == 1 && CodeHighlighting.pasteableLanguage(prose, hint: nil) == nil)
    }
    let explicitText = MarkdownRenderer.pasteableText(python, language: "text", fontSize: 18)
    log.check("explicit plain text disables detection", highlightingColors(explicitText).count == 1)
    let unknown = MarkdownRenderer.highlightedCode(python, language: "not-a-language")
    log.check("unknown language falls back safely", unknown.string == python && highlightingColors(unknown).count == 1)
    log.check("anonymous fenced code can detect a language", highlightingColors(MarkdownRenderer.highlightedCode(python)).count >= 3)
    let huge = String(repeating: python, count: 500)
    log.check("large blocks remain intact without costly parsing", MarkdownRenderer.highlightedCode(huge, language: "python").string == huge)
    let partial = "def greet(name):\n    return \"Hello"
    log.check("incomplete streamed code stays visible", MarkdownRenderer.highlightedCode(partial, language: "python").string == partial)
    log.finish()
}
