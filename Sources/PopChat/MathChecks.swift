import AppKit
import SwiftMath

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

let boxedMathExample = #"""
The centre is

$$\boxed{(1,2)}$$

and the radius is

$$\boxed{2}.$$

Inline: \(\boxed{x^2}\). Nested fractions and scripts:

$$\frac{\boxed{1}}{\sqrt{\boxed{2}}}+\boxed{\frac{x+1}{\boxed{y}}}_{n}^{2}.$$
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
    log.check("boxed screenshot equations and nested boxes render", equations(boxedMathExample).allSatisfy {
        MarkdownRenderer.mathImage($0, fontSize: 22.5, display: true) != nil
    })
    log.check("boxed inline and table math render", attachments(MarkdownRenderer.attributedProse(#"Centre $\boxed{(1,2)}$ and radius \(\boxed{2}\)."#)).count == 2
        && attachments(MarkdownRenderer.tableCell(#"\(\boxed{x}\)"#)).count == 1)
    log.check("boxed code stays literal", attachments(MarkdownRenderer.attributedProse(#"`\(\boxed{x}\)`"#)).isEmpty)
    let box = MarkdownRenderer.mathImage(#"\boxed{(1,2)}"#, fontSize: 18, display: true)
    let unboxed = MarkdownRenderer.mathImage("(1,2)", fontSize: 18, display: true)
    log.check("box reserves room for its frame", (box?.size.width ?? 0) > (unboxed?.size.width ?? 0)
        && (box?.size.height ?? 0) > (unboxed?.size.height ?? 0))
    let scriptBox = MarkdownRenderer.mathImage(#"\boxed{(1,2)}_{n}^{2}"#, fontSize: 18, display: true)
    log.check("scripts reserve space outside the box", (scriptBox?.size.width ?? 0) > (box?.size.width ?? 0)
        && (scriptBox?.size.height ?? 0) > (box?.size.height ?? 0))
    let largeBox = MarkdownRenderer.mathImage(#"\boxed{(1,2)}"#, fontSize: 36, display: true)
    log.check("box and contents scale with text size", abs((largeBox?.size.width ?? 0) - 2 * (box?.size.width ?? 0)) < 0.01
        && abs((largeBox?.size.height ?? 0) - 2 * (box?.size.height ?? 0)) < 0.01)
    let boxedSource = #"\boxed{\frac{1}{\boxed{x}}}^{2}_{n}"#
    let parsedBox = MTMathListBuilder.build(fromString: boxedSource)
    log.check("copy and finalization preserve boxed contents and scripts", parsedBox != nil
        && MTMathListBuilder.mathListToString(MTMathList(atoms: parsedBox?.atoms.map { $0.copy() } ?? [])) == boxedSource
        && MTMathListBuilder.mathListToString(parsedBox?.finalized) == boxedSource)
    log.check("empty and colored boxes render", [#"\boxed{}"#, #"\boxed{\color{FF0000}{x}}"#].allSatisfy {
        MarkdownRenderer.mathImage($0, fontSize: 18, display: true) != nil
    })
    log.check("malformed boxed input preserves its source", [#"\boxed{x"#, #"\boxed{\unknown{x}}"#, #"\boxedOther{x}"#].allSatisfy {
        let source = "\\(" + $0 + "\\)"
        return MarkdownRenderer.mathImage($0, fontSize: 18, display: true) == nil
            && MarkdownRenderer.attributedProse(source).string == source
    })
    log.check("reasoning math renders", attachments(MarkdownRenderer.attributedReasoning(#"Use \(x^2\)."#)).count == 1)
    let small = attachments(MarkdownRenderer.attributedProse(#"\(x^2\)"#, fontSize: 12)).first
    let large = attachments(MarkdownRenderer.attributedProse(#"\(x^2\)"#, fontSize: 24)).first
    log.check("inline math follows text size", (large?.bounds.height ?? 0) > (small?.bounds.height ?? 0))
    for example in [mathExample, boxedMathExample] {
        for length in 0...example.count {
            for segment in MarkdownRenderer.segments(String(example.prefix(length))) {
                switch segment {
                case .prose(let source): _ = MarkdownRenderer.attributedProse(source)
                case .math(let latex): _ = MarkdownRenderer.mathImage(latex, fontSize: 18, display: true)
                default: break
                }
            }
        }
    }
    log.check("every streamed prefix renders without crashing", true)
    log.finish()
}
