import AppKit
import SwiftUI

/// One persisted size for the transcript and composer. Window chrome stays compact.
enum ChatTextSize {
    static let key = "chatTextSize"
    static let defaultSize = 16.0
    static let range = 11.0...32.0

    static func normalized(_ size: Double) -> Double {
        guard size.isFinite else { return defaultSize }
        return min(range.upperBound, max(range.lowerBound, size.rounded()))
    }

    static func handle(_ event: NSEvent, defaults: UserDefaults = .standard) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard modifiers.contains(.command), !modifiers.contains(.option),
              !modifiers.contains(.control) else { return false }
        // Use characters, so + works on both US and Swedish layouts and keypads.
        let character = event.charactersIgnoringModifiers ?? ""
        let current = normalized(defaults.object(forKey: key) as? Double ?? defaultSize)
        let next: Double
        switch character {
        case "+", "=": next = current + 1
        case "-": next = current - 1
        case "0" where !modifiers.contains(.shift): next = defaultSize
        default: return false
        }
        defaults.set(normalized(next), forKey: key)
        return true
    }
}

private struct ChatTextSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = ChatTextSize.defaultSize
}

extension EnvironmentValues {
    var chatTextSize: CGFloat {
        get { self[ChatTextSizeKey.self] }
        set { self[ChatTextSizeKey.self] = newValue }
    }
}
