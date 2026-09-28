# SwiftMath in PopChat

This is SwiftMath 1.7.3, revision `fa8244ed032f4a1ade4cb0571bf87d2f1a9fd2d7`,
from https://github.com/mgriebling/SwiftMath. The upstream package manifest,
sources, fonts, license and tests are preserved here.

PopChat adds `\boxed` in the native parser and typesetter. SwiftMath's internal
layout APIs cannot be extended from the app target, so this local package keeps
the patch reproducible without modifying SwiftPM's downloaded checkouts.

The patch adds `MathRender/MTBox.swift` and changes `MTMathList.swift`,
`MTMathListBuilder.swift` and `MTTypesetter.swift`. Boxes include padding and a
font-scaled border in their layout metrics, support scripts and nesting, and use
display style for their contents. PopChat's `--smoke-math` covers parsing,
copying, layout dimensions, font scaling and message-rendering integration.
The preserved upstream XCTest suite requires full Xcode; PopChat's smoke
harness also runs on machines with only Command Line Tools.

When updating from upstream, retain this patch until upstream supports boxed
expressions, then return to the remote dependency. Keep the font license files
inside `mathFonts.bundle`; the library code is MIT licensed, as in `LICENSE`.
