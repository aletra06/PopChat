import AppKit

let mathExample = #"""
For a quadratic equation

\[
ax^2+bx+c=0,\quad a\ne0,
\]

the quadratic formula is

\[
x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}.
\]

The \(\pm\) means there can be two solutions.
"""#

@MainActor
func runMathChecks() -> Never {
    var log = CheckLog()
    func equations(_ source: String) -> [String] {
        MarkdownRenderer.segments(source).compactMap {
            if case .math(let latex) = $0 { return latex }
            return nil
        }
    }
    func attachments(_ text: NSAttributedString) -> [NSTextAttachment] {
        var found: [NSTextAttachment] = []
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, _, _ in
            if let attachment = value as? NSTextAttachment { found.append(attachment) }
        }
        return found
    }
    let display = equations(mathExample)
    log.check("quadratic answer contains both display equations", display.count == 2)
    log.check("fractions, roots and inequality render", display.allSatisfy {
        MarkdownRenderer.mathImage($0, fontSize: 22.5, display: true) != nil
    })
    log.check("single-line bracket math", equations(#"\[x^2\]"#) == ["x^2"])
    log.check("both dollar block forms still work", equations("$$x^2$$\n$$\nx+1\n$$") == ["x^2", "x+1"])
    let trailing = MarkdownRenderer.segments(#"\[x^2\] After the equation."#)
    log.check("text after a display delimiter survives", trailing.flatMap(MarkdownRenderer.searchableStrings).joined().contains("After the equation."))
    log.check("fences and pasteable blocks stay literal", equations("```latex\n\\[x^2\\]\n```\n<pasteable>\n$$x^2$$\n</pasteable>").isEmpty)

    let prose = MarkdownRenderer.attributedProse(#"🧮 Café: \(\pm\), $x^2$ and \(\frac{1}{2}\)."#, fontSize: 18)
    log.check("mixed inline forms render after Unicode", attachments(prose).count == 3 && prose.string.hasPrefix("🧮 Café:"))
    log.check("inline symbol from screenshot renders", attachments(MarkdownRenderer.attributedProse(#"The \(\pm\) means there can be two solutions."#)).count == 1)
    log.check("inline code stays literal", attachments(MarkdownRenderer.attributedProse(#"`\(x\)` and ``$x$ ` literal``"#)).isEmpty)
    log.check("escaped delimiters stay literal", attachments(MarkdownRenderer.attributedProse(#"\\(x\\) and \$x\$"#)).isEmpty)
    log.check("prices stay literal", attachments(MarkdownRenderer.attributedProse("Costs $5 and $10 today.")).isEmpty)
    log.check("ordinary parentheses and brackets stay text", attachments(MarkdownRenderer.attributedProse("(hello) and [world]")).isEmpty)
    log.check("unsupported commands preserve original source", MarkdownRenderer.attributedProse(#"Keep \(\notARealCommand{x}\) visible."#).string.contains(#"\(\notARealCommand{x}\)"#))
    log.check("table math renders", attachments(MarkdownRenderer.tableCell(#"\(x^2\) and $y$"#)).count == 2)
    log.check("reasoning math renders", attachments(MarkdownRenderer.attributedReasoning(#"Use \(x^2\)."#)).count == 1)
    let small = attachments(MarkdownRenderer.attributedProse(#"\(x^2\)"#, fontSize: 12)).first
    let large = attachments(MarkdownRenderer.attributedProse(#"\(x^2\)"#, fontSize: 24)).first
    log.check("inline math follows text size", (large?.bounds.height ?? 0) > (small?.bounds.height ?? 0))
    for length in 0...mathExample.count {
        for segment in MarkdownRenderer.segments(String(mathExample.prefix(length))) {
            switch segment {
            case .prose(let source): _ = MarkdownRenderer.attributedProse(source)
            case .math(let latex): _ = MarkdownRenderer.mathImage(latex, fontSize: 18, display: true)
            default: break
            }
        }
    }
    log.check("every streamed prefix renders without crashing", true)
    log.finish()
}
