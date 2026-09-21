import AppKit
import Highlighter

/// Local highlighting produces native selectable text. The source is never executed.
enum CodeHighlighting {
    private static let cache: NSCache<NSString, NSAttributedString> = {
        let cache = NSCache<NSString, NSAttributedString>()
        cache.countLimit = 128
        return cache
    }()

    private static let dark = makeHighlighter(theme: "atom-one-dark")
    private static let light = makeHighlighter(theme: "atom-one-light")
    private static let supported = Set(dark?.supportedLanguages() ?? [])

    private static func makeHighlighter(theme: String) -> Highlighter? {
        guard let highlighter = Highlighter(), highlighter.setTheme(theme) else { return nil }
        highlighter.ignoreIllegals = true // Incomplete streamed code is still useful.
        return highlighter
    }

    static func normalizedLanguage(_ hint: String?) -> String? {
        guard let name = hint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !name.isEmpty else { return nil }
        let aliases = ["py": "python", "python3": "python", "js": "javascript", "jsx": "javascript",
                       "ts": "typescript", "tsx": "typescript", "sh": "bash", "shell": "bash",
                       "zsh": "bash", "html": "xml", "c++": "cpp", "c#": "csharp",
                       "yml": "yaml", "text": "plaintext", "txt": "plaintext"]
        return aliases[name] ?? name
    }

    // Old conversations have no language attribute. Only recognize clear code
    // structures here; arbitrary emails and prompts must remain ordinary text.
    private static let signatures: [(String, NSRegularExpression)] = [
        ("python", #"(?m)^\s*(?:(?:async\s+)?def\s+\w+\s*\([^\n]*\)\s*(?:->[^:\n]+)?:|class\s+\w+(?:\([^\n]*\))?\s*:|from\s+[\w.]+\s+import\s+\w+)"#),
        ("swift", #"(?m)^\s*(?:(?:public|private|static|mutating)\s+)*func\s+\w+\s*\("#),
        ("javascript", #"(?m)^\s*(?:(?:export\s+)?(?:async\s+)?function\s+\w+\s*\(|(?:const|let|var)\s+\w+\s*=\s*[^\n]*(?:=>|;\s*$))"#),
        ("bash", #"\A#![^\n]*/(?:env\s+)?(?:ba|z)?sh\b"#),
    ].map { ($0.0, try! NSRegularExpression(pattern: $0.1)) }

    static func pasteableLanguage(_ content: String, hint: String?) -> String? {
        if let explicit = normalizedLanguage(hint) { return explicit }
        // Detection is bounded even for very large copyable documents.
        let sample = String(content.prefix(8_192))
        let range = NSRange(sample.startIndex..., in: sample)
        for (language, pattern) in signatures where pattern.firstMatch(in: sample, range: range) != nil {
            return language
        }
        if content.utf8.count <= 32_768,
           let first = content.first(where: { !$0.isWhitespace }), "[{".contains(first),
           let data = content.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
            return "json"
        }
        return nil
    }

    static func render(_ code: String, language: String?, dark isDark: Bool, fontSize: CGFloat) -> NSAttributedString {
        let language = normalizedLanguage(language) ?? pasteableLanguage(code, hint: nil)
        let key = "\(isDark)|\(fontSize)|\(language ?? "auto")|\(code)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let highlighter = isDark ? dark : light
        let highlighted: NSAttributedString?
        // Unknown language tags are plain code, never passed into the JS engine.
        // Bound expensive parsing so a huge streamed block cannot freeze typing.
        if code.utf8.count <= 65_536, language != "plaintext",
           language.map({ supported.contains($0) }) ?? true {
            highlighted = highlighter?.highlight(code, as: language)
        } else {
            highlighted = nil
        }
        let result: NSMutableAttributedString
        if let highlighted, highlighted.string == code {
            result = NSMutableAttributedString(attributedString: highlighted)
        } else {
            result = NSMutableAttributedString(string: code, attributes: [.foregroundColor: NSColor.labelColor])
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4 * fontSize / NSFont.systemFontSize
        let range = NSRange(location: 0, length: result.length)
        result.removeAttribute(.backgroundColor, range: range)
        result.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .paragraphStyle: paragraph,
        ], range: range)
        cache.setObject(result, forKey: key)
        return result
    }
}
