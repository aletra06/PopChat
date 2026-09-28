import { mathjax } from '@mathjax/src/js/mathjax.js';
import { TeX } from '@mathjax/src/js/input/tex.js';
import { SVG } from '@mathjax/src/js/output/svg.js';
import { SvgWrapperFactory } from '@mathjax/src/js/output/svg/WrapperFactory.js';
import { SvgMtable } from '@mathjax/src/js/output/svg/Wrappers/mtable.js';
import { liteAdaptor } from '@mathjax/src/js/adaptors/liteAdaptor.js';
import { RegisterHTMLHandler } from '@mathjax/src/js/handlers/html.js';
import { MathJaxTexFont } from '@mathjax/mathjax-tex-font/js/svg.js';
import { MathJaxMhchemFontExtension } from '@mathjax/mathjax-mhchem-font-extension/js/svg.js';
import '@mathjax/src/js/input/tex/ams/AmsConfiguration.js';
import '@mathjax/src/js/input/tex/amscd/AmsCdConfiguration.js';
import '@mathjax/src/js/input/tex/bbox/BboxConfiguration.js';
import '@mathjax/src/js/input/tex/boldsymbol/BoldsymbolConfiguration.js';
import '@mathjax/src/js/input/tex/braket/BraketConfiguration.js';
import '@mathjax/src/js/input/tex/cancel/CancelConfiguration.js';
import '@mathjax/src/js/input/tex/cases/CasesConfiguration.js';
import '@mathjax/src/js/input/tex/color/ColorConfiguration.js';
import '@mathjax/src/js/input/tex/configmacros/ConfigMacrosConfiguration.js';
import '@mathjax/src/js/input/tex/enclose/EncloseConfiguration.js';
import '@mathjax/src/js/input/tex/extpfeil/ExtpfeilConfiguration.js';
import '@mathjax/src/js/input/tex/gensymb/GensymbConfiguration.js';
import '@mathjax/src/js/input/tex/mathtools/MathtoolsConfiguration.js';
import '@mathjax/src/js/input/tex/mhchem/MhchemConfiguration.js';
import '@mathjax/src/js/input/tex/newcommand/NewcommandConfiguration.js';
import '@mathjax/src/js/input/tex/textmacros/TextMacrosConfiguration.js';
import '@mathjax/src/js/input/tex/unicode/UnicodeConfiguration.js';
import '@mathjax/src/js/input/tex/verb/VerbConfiguration.js';

const adaptor = liteAdaptor();
RegisterHTMLHandler(adaptor);

// MathJax's browser output stretches tagged equations across a responsive
// viewport. Native images have a fixed natural size, so place their labels
// directly in the same coordinate system as the equation.
class NativeTable extends SvgMtable {
  topTable(svg, labels, side) {
    const { w, L, R } = this.getBBox();
    const labelWidth = this.getTableData().L;
    this.adaptor.removeAttribute(labels, 'transform');
    this.place(side === 'left' ? -L : w + R - labelWidth, 0, labels);
    this.adaptor.append(svg, labels);
  }
}
class NativeSVG extends SVG {
  createRoot(wrapper) {
    const { w, h, d } = wrapper.getOuterBBox();
    return this.createSVG(h, d, w);
  }
}
const factory = new SvgWrapperFactory();
factory.setNodeClass('mtable', NativeTable);
MathJaxTexFont.addExtension(MathJaxMhchemFontExtension);
const output = new NativeSVG({ fontData: MathJaxTexFont, fontCache: 'none', wrapperFactory: factory });
const packages = [
  'base', 'ams', 'amscd', 'bbox', 'boldsymbol', 'braket', 'cancel', 'cases',
  'color', 'configmacros', 'enclose', 'extpfeil', 'gensymb', 'mathtools', 'mhchem',
  'newcommand', 'textmacros', 'unicode', 'verb',
];
// Models also emit these conventional operator names as bare commands.
const macros = { bm: ['\\boldsymbol{#1}', 1] };
for (const name of ['arctg', 'arcctg', 'arccot', 'arcsec', 'arccsc', 'sech', 'csch', 'arsinh', 'arcosh', 'artanh']) {
  macros[name] = `\\operatorname{${name}}`;
}

// No browser, Node APIs, dynamic loader or HTML/link/image packages are exposed
// in the app's JavaScriptCore context. Every font outline is bundled locally.
export function render(source, fontSize, display, color) {
  try {
    if (!source || source.length > 16384 || !Number.isFinite(fontSize) ||
        fontSize < 1 || fontSize > 128 || !/^#[0-9a-f]{6}$/i.test(color)) {
      return null;
    }
    let depth = 0;
    for (let i = 0; i < source.length; i++) {
      if (source[i] === '\\') { i++; continue; }
      if (source[i] === '{' && ++depth > 64) return null;
      if (source[i] === '}') depth--;
    }
    // A new parser per expression prevents model-defined macros and labels
    // from changing how subsequent messages render.
    const input = new TeX({
      packages, maxBuffer: 16384, maxMacros: 1000, tags: 'none',
      macros,
      formatError: (_jax, error) => { throw error; },
    });
    const document = mathjax.document('', { InputJax: input, OutputJax: output });
    const node = document.convert(source, { display, em: fontSize, ex: fontSize / 2, containerWidth: 100000 });
    const svg = adaptor.tags(node, 'svg')[0];
    if (!svg) return null;
    const bounds = adaptor.getAttribute(svg, 'viewBox').split(/\s+/).map(Number);
    const width = bounds[2] * fontSize / 1000;
    const height = bounds[3] * fontSize / 1000;
    if (![width, height].every(Number.isFinite) || width <= 0 || height <= 0 ||
        width > 16384 || height > 8192 || width * height > 8000000) return null;
    adaptor.setAttribute(svg, 'width', String(width));
    adaptor.setAttribute(svg, 'height', String(height));
    adaptor.setAttribute(svg, 'color', color);
    // AppKit's SVG decoder does not apply MathJax's CSS attribute selectors.
    // Materialize the drawing rules as ordinary SVG presentation attributes.
    for (const kind of ['line', 'rect']) {
      for (const shape of adaptor.tags(svg, kind)) {
        if (adaptor.getAttribute(shape, kind === 'line' ? 'data-line' : 'data-frame') === undefined) continue;
        adaptor.setAttribute(shape, 'stroke-width', adaptor.getAttribute(shape, 'stroke-thickness') || '70');
        adaptor.setAttribute(shape, 'fill', 'none');
        const style = adaptor.getAttribute(shape, 'class') || '';
        if (style.includes('mjx-dashed')) adaptor.setAttribute(shape, 'stroke-dasharray', '140');
        if (style.includes('mjx-dotted')) {
          adaptor.setAttribute(shape, 'stroke-linecap', 'round');
          adaptor.setAttribute(shape, 'stroke-dasharray', '0,140');
        }
      }
    }
    for (const path of adaptor.tags(svg, 'path')) {
      if (adaptor.getAttribute(path, 'data-c') !== undefined) adaptor.setAttribute(path, 'stroke-width', String(output.options.blacker));
    }
    const markup = adaptor.outerHTML(svg);
    if (markup.length > 2000000) return null;
    // In particular, prevent a color value from smuggling an external SVG paint
    // server URL into AppKit. All supported glyphs are self-contained paths.
    if (/(?:\b(?:href|src)\s*=|<\s*(?:image|foreignObject|script)\b|url\s*\()/i.test(markup)) return null;
    return { svg: markup, width, height, descent: (bounds[1] + bounds[3]) * fontSize / 1000 };
  } catch (_) {
    return null;
  }
}
