# Math renderer

PopChat runs the checked-in MathJax bundle in JavaScriptCore and draws its SVG output with AppKit. There are no runtime downloads or web views. Node.js is needed only when rebuilding the bundle.

From this directory:

```sh
npm ci --ignore-scripts
npm run build
```

Commit the source, lockfile and generated `Sources/PopChat/Resources/MathJax/renderer.js` together. Run `./build.sh debug` from the repository root, then `--smoke-math` and the rendering/interaction checks listed in `CONTRIBUTING.md`. Inspect `--shot math-compat` and `--shot math-gallery` in both appearances after changing MathJax or the font packages.

`renderer.mjs` lists the bundled TeX extensions. They cover AMS notation, named operators, boxes, matrices, aligned equations, cases, cancellation, colors, bra-ket notation and chemistry. Each expression gets a new TeX parser so local macros cannot affect other messages. Full LaTeX documents, TikZ, external images and dynamically loaded packages are outside this renderer's scope. Unsupported or incomplete input stays visible as source.

The SVG adapter makes equation tags use the image's natural width and turns MathJax's CSS drawing rules into attributes that AppKit understands. Keep the native pixel checks for table dividers when updating these adapters. All font outlines are embedded paths. The app does not expose browser, network or filesystem APIs to the renderer.

Input length, nesting, macro expansion and output dimensions are bounded. The Swift cache stores successes and failures by expression, appearance, display style and font size. Inline attachments use the equation's actual descent for baseline alignment.

The app bundle includes third-party notices and licenses alongside the generated JavaScript. Font license text is checked in separately because the npm font packages record their license in metadata without shipping its full text.
