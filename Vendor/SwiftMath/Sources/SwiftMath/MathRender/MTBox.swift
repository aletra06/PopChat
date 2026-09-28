import Foundation
import CoreGraphics

/// A framed math list. It remains an ordinary atom for spacing and scripts.
public class MTBox: MTMathAtom {
    public var innerList: MTMathList?

    override init() {
        super.init()
        type = .boxed
    }

    init(_ box: MTBox?) {
        super.init(box)
        type = .boxed
        innerList = MTMathList(box?.innerList)
    }

    override public var finalized: MTMathAtom {
        let box = super.finalized as! MTBox
        box.innerList = box.innerList?.finalized
        return box
    }
}

/// The frame participates in layout, so fractions, radicals and scripts reserve
/// space for its border instead of painting it over neighboring glyphs.
final class MTBoxDisplay: MTDisplay {
    let inner: MTMathListDisplay
    let inset: CGFloat
    let rule: CGFloat

    init(inner: MTMathListDisplay, padding: CGFloat, rule: CGFloat,
         position: CGPoint, range: NSRange) {
        self.inner = inner
        self.inset = padding + rule
        self.rule = rule
        super.init()
        ascent = inner.ascent + inset
        descent = inner.descent + inset
        width = inner.width + 2 * inset
        self.range = range
        self.position = position
    }

    override var position: CGPoint {
        didSet {
            inner.position = CGPoint(x: position.x + inset, y: position.y)
        }
    }

    override var textColor: MTColor? {
        didSet { inner.textColor = textColor }
    }

    override func draw(_ context: CGContext) {
        super.draw(context)
        inner.draw(context)
        guard let textColor else { return }
        context.saveGState()
        context.setStrokeColor(textColor.cgColor)
        context.setLineWidth(rule)
        context.stroke(displayBounds().insetBy(dx: rule / 2, dy: rule / 2))
        context.restoreGState()
    }
}
