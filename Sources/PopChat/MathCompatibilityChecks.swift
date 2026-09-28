import AppKit

/// Representative model output, including commands that the former renderer
/// rejected. These are compatibility examples, not a claim of full TeX support.
let mathCompatibilityCases: [(String, String)] = [
    ("arctangent screenshot", #"\arctan(x)=\operatorname{sgn}(x)\arccos\left(\frac{1}{\sqrt{1+x^2}}\right)."#),
    ("named operators", #"\operatorname{rank}(A)+\operatorname{Var}(X)+\operatorname{sgn}(x)+\arctg x+\arccot x+\sech x"#),
    ("operator limits", #"\operatorname*{arg\,max}_{x\in\mathbb{R}} f(x)"#),
    ("display and text fractions", #"\dfrac{a+b}{c+d}+\tfrac{1}{2}"#),
    ("continued fractions", #"\cfrac{1}{1+\cfrac{1}{2+x}}"#),
    ("binomials", #"\binom{n}{k}=\dbinom{n}{k}=\tbinom{n}{k}"#),
    ("general fractions", #"\genfrac{(}{)}{0pt}{}{a}{b}"#),
    ("roots", #"\sqrt{x^2+1}+\sqrt[3]{\frac{a}{b}}"#),
    ("boxed answers", #"\boxed{(1,2)}\qquad\boxed{2}."#),
    ("nested boxes", #"\frac{\boxed{1}}{\sqrt{\boxed{2}}}+\boxed{\frac{x}{\boxed{y}}}_{n}^{2}"#),
    ("sums and products", #"\sum_{k=1}^{n}k=\frac{n(n+1)}{2},\quad\prod_{k=1}^{n}k=n!"#),
    ("integrals", #"\int_0^1 x^2\,\mathrm{d}x=\frac13,\quad\iint_D f\,dA+\iiint_V f\,dV+\oint_C f\,ds"#),
    ("limits", #"\lim_{x\to0}\frac{\sin x}{x}=1,\quad\limsup_{n\to\infty}a_n"#),
    ("substack", #"\sum_{\substack{i+j=n\\i,j\ge0}}a_i b_j"#),
    ("overset and underset", #"a\overset{\text{def}}{=}b,\quad\underset{x\to0}{\lim}f(x)"#),
    ("overbrace and underbrace", #"\overbrace{a+\cdots+a}^{n\text{ terms}}=\underbrace{na}_{\text{sum}}"#),
    ("accents", #"\hat{x}+\widehat{ABC}+\bar{x}+\overline{AB}+\tilde{x}+\widetilde{ABC}+\vec{v}+\dot{x}+\ddot{x}"#),
    ("wide arrows", #"\overrightarrow{AB}+\overleftarrow{AB}+\overleftrightarrow{AB}"#),
    ("labelled arrows", #"A\xrightarrow{f}B\xleftarrow[g]{h}C"#),
    ("cancellation", #"\frac{\cancel{x}y}{\cancel{x}}=y,\quad\bcancel{a}+\xcancel{b}+\cancelto{0}{x}"#),
    ("delimiters", #"\left\langle\frac{a}{b}\middle|x\right\rangle+\Bigl[\bigl(x\bigr)\Bigr]"#),
    ("norms and absolute values", #"\lVert x\rVert_2+\lvert x\rvert+\left\|\frac{x}{y}\right\|"#),
    ("floor and ceiling", #"\lfloor x\rfloor+\lceil x\rceil"#),
    ("spacing", #"a\,b\:c\;d\!e\quad f\qquad g\hspace{1em}h"#),
    ("styles", #"{\displaystyle\sum_{i=1}^n i}+{\textstyle\frac12}+{\scriptstyle x}+{\scriptscriptstyle y}"#),
    ("number sets", #"\mathbb{R}\supset\mathbb{Q}\supset\mathbb{Z}\supset\mathbb{N},\quad\mathbb{C}"#),
    ("font variants", #"\mathcal{F}+\mathscr{L}+\mathfrak{g}+\mathrm{e}+\mathsf{A}+\mathtt{code}+\mathit{x}"#),
    ("bold vectors", #"\mathbf{A}\boldsymbol{x}=\boldsymbol{\alpha}+\bm{\beta}"#),
    ("text and punctuation", #"x=2\quad\text{if }x>0,\qquad\text{otherwise }0."#),
    ("text accents", #"\text{Caf\'e and na\"ive}"#),
    ("greek variants", #"\alpha+\beta+\gamma+\Gamma+\Delta+\theta+\vartheta+\phi+\varphi+\epsilon+\varepsilon+\omega+\Omega"#),
    ("relations", #"a\leq b\ge c\neq d\approx e\equiv f\sim g\simeq h\propto i"#),
    ("logic", #"\forall x\in A,\ \exists y\notin B:\ P(x)\implies Q(y)\iff R(x)"#),
    ("set operators", #"A\cup B\cap C\setminus D\subseteq E,\quad\emptyset=\varnothing"#),
    ("calculus symbols", #"\nabla\cdot\mathbf{F}=\frac{\partial f}{\partial x},\quad f'(x),\ f''(x),\ \infty"#),
    ("dots", #"a_1,\ldots,a_n;\quad a_1+\cdots+a_n;\quad\vdots\ \ddots"#),
    ("modular arithmetic", #"a\equiv b\pmod n,\quad a\bmod n,\quad\gcd(a,b)"#),
    ("complex numbers", #"\Re(z)+i\Im(z),\quad\overline{z},\quad\arg z"#),
    ("plain matrix", #"\begin{matrix}a&b\\c&d\end{matrix}"#),
    ("parenthesized matrix", #"\begin{pmatrix}a&b\\c&d\end{pmatrix}"#),
    ("bracketed matrix", #"\begin{bmatrix}1&0\\0&1\end{bmatrix}"#),
    ("brace matrix", #"\begin{Bmatrix}a&b\\c&d\end{Bmatrix}"#),
    ("determinant", #"\begin{vmatrix}a&b\\c&d\end{vmatrix}=ad-bc"#),
    ("double bar matrix", #"\begin{Vmatrix}a&b\\c&d\end{Vmatrix}"#),
    ("small matrix", #"\left(\begin{smallmatrix}a&b\\c&d\end{smallmatrix}\right)"#),
    ("augmented array", #"\left[\begin{array}{cc|c}1&2&3\\4&5&6\end{array}\right]"#),
    ("array rules", #"\begin{array}{c|c}x&y\\\hline1&2\end{array}"#),
    ("piecewise function", #"f(x)=\begin{cases}x^2&\text{if }x\ge0,\\-x&\text{otherwise.}\end{cases}"#),
    ("display cases", #"f(x)=\begin{dcases}\frac1x&x\ne0\\0&x=0\end{dcases}"#),
    ("aligned equations", #"\begin{aligned}x+y&=3\\x-y&=1\end{aligned}"#),
    ("aligned columns", #"\begin{alignedat}{2}x&=1&\quad y&=2\\a&=3& b&=4\end{alignedat}"#),
    ("gathered equations", #"\begin{gathered}x+y=3\\x-y=1\end{gathered}"#),
    ("align environment", #"\begin{align*}a&=b+c\\&=d\end{align*}"#),
    ("equation environment", #"\begin{equation*}E=mc^2\end{equation*}"#),
    ("explicit equation tag", #"E=mc^2\tag{1}"#),
    ("named colors", #"\color{red}{x}+\textcolor{blue}{y}"#),
    ("color boxes", #"\colorbox{yellow}{$x$}+\fcolorbox{red}{white}{$y$}"#),
    ("phantom alignment", #"\phantom{x}\frac12+\vphantom{\frac12}x+\smash{x}"#),
    ("prescript", #"\prescript{14}{6}{C}"#),
    ("colon relations", #"f\colon A\to B,\quad x\coloneqq y"#),
    ("braket notation", #"\bra{\psi}\ket{\phi}=\braket{\psi|\phi}"#),
    ("chemical equation", #"\ce{2H2 + O2 -> 2H2O}"#),
    ("chemical isotope", #"\ce{^{14}_{6}C -> ^{14}_{7}N + e-}"#),
    ("local macro", #"\newcommand{\vect}[1]{\mathbf{#1}}\vect{x}+\vect{y}"#),
    ("unicode math", #"α+β≤π,\quad x∈ℝ"#),
];

func checkMathCompatibility(_ log: inout CheckLog) {
    for (name, latex) in mathCompatibilityCases {
        let image = MarkdownRenderer.mathImage(latex, fontSize: 20, display: true)
        log.check("math compatibility: \(name)", image.map(mathImageHasInk) ?? false)
    }
    log.check("local macros do not leak to later equations", MarkdownRenderer.mathImage(#"\vect{x}"#, fontSize: 20, display: true) == nil)
    if let ruled = MarkdownRenderer.mathImage(#"\begin{array}{c|c}x&y\\1&2\end{array}"#, fontSize: 20, display: true),
       let plain = MarkdownRenderer.mathImage(#"\begin{array}{cc}x&y\\1&2\end{array}"#, fontSize: 20, display: true) {
        log.check("array divider is painted", mathImageInkCount(ruled) > mathImageInkCount(plain))
    } else { log.check("array divider is painted", false) }
    for source in [#"\href{https://example.com}{x}"#, #"\includegraphics{https://example.com/a.png}"#,
                   #"\require{html}"#, #"\htmlClass{test}{x}"#, #"\color{url(https://example.com/paint)}{x}"#, #"\def\x{\x}\x"#,
                   String(repeating: "{", count: 100) + "x" + String(repeating: "}", count: 100),
                   String(repeating: "x", count: 20_000)] {
        log.check("unsafe or excessive math falls back", MarkdownRenderer.mathImage(source, fontSize: 20, display: true) == nil)
    }
}

/// Decode and draw the SVG too: an image object alone does not prove AppKit
/// painted its glyphs, nested viewports or paths.
private func mathImageHasInk(_ image: NSImage) -> Bool {
    mathImageInkCount(image) > 0
}

private func mathImageInkCount(_ image: NSImage) -> Int {
    let scale = min(1, 1024 / image.size.width)
    let width = max(1, Int(ceil(image.size.width * scale)))
    let height = max(1, Int(ceil(image.size.height * scale)))
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    return pixels.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        let bytes = buffer.bindMemory(to: UInt8.self)
        return stride(from: 3, to: bytes.count, by: 4).reduce(0) { $0 + (bytes[$1] > 0 ? 1 : 0) }
    }
}

let mathGalleryExample = [
    "explicit equation tag", "piecewise function", "aligned equations", "augmented array",
    "overbrace and underbrace", "cancellation", "chemical equation",
].compactMap { name in mathCompatibilityCases.first { $0.0 == name } }
    .map { "\($0.0)\n\n$$\($0.1)$$" }.joined(separator: "\n\n")
    + #"""


Inline \(\operatorname{sgn}(x)\), \(\frac{a}{b}\), \(x_i^2\) and \(\boxed{x}\) stay on the text baseline.

| Quantity | Formula |
| --- | --- |
| Conditional | $P(A|B)$ |
| Norm | $\left|x\right|$ |
"""#
