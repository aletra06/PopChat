import AppKit
import JavaScriptCore

/// Typesets LaTeX locally, then lets AppKit draw the resulting vector image.
/// The JavaScript context has no browser, filesystem or network APIs.
enum MathRenderer {
    struct Rendering {
        let image: NSImage
        let descent: CGFloat
    }

    private final class Entry: NSObject {
        let rendering: Rendering?
        init(_ rendering: Rendering?) { self.rendering = rendering }
    }

    private static let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.countLimit = 256
        cache.totalCostLimit = 16 * 1024 * 1024
        return cache
    }()

    // Markdown rendering already runs on the main thread. Keep one JS context
    // there, including for streamed partial expressions, instead of rebuilding
    // the engine on every tick. The JS entry point creates a fresh TeX parser.
    private static let context: JSContext? = {
        guard let url = Bundle.module.url(forResource: "renderer", withExtension: "js", subdirectory: "MathJax"),
              let source = try? String(contentsOf: url, encoding: .utf8),
              let context = JSContext() else { return nil }
        context.evaluateScript(source, withSourceURL: url)
        guard context.exception == nil else { return nil }
        return context
    }()

    static func render(_ latex: String, fontSize: CGFloat, display: Bool) -> Rendering? {
        precondition(Thread.isMainThread)
        guard latex.utf16.count <= 16_384, fontSize.isFinite, (1...128).contains(fontSize) else { return nil }
        let dark = NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) != .aqua
        let color = dark ? "#e5e5e5" : "#1a1a1a"
        let key = "\(color)|\(display)|\(fontSize)|\(latex)" as NSString
        if let entry = cache.object(forKey: key) { return entry.rendering }
        guard let context else { return nil }
        context.exception = nil
        let value = context.objectForKeyedSubscript("PopChatMath")?.invokeMethod(
            "render", withArguments: [latex, fontSize, display, color]
        )
        guard context.exception == nil,
              let result = value?.toDictionary(),
              let svg = result["svg"] as? String,
              let width = result["width"] as? Double,
              let height = result["height"] as? Double,
              let descent = result["descent"] as? Double,
              width.isFinite, height.isFinite, descent.isFinite,
              let image = NSImage(data: Data(svg.utf8)) else {
            // Failed partial input is common while streaming. Cache it too.
            cache.setObject(Entry(nil), forKey: key, cost: latex.utf8.count)
            return nil
        }
        image.size = NSSize(width: width, height: height)
        let rendering = Rendering(image: image, descent: descent)
        cache.setObject(Entry(rendering), forKey: key, cost: svg.utf8.count)
        return rendering
    }
}
