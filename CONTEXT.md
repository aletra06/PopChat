# Fork context

This fork adds readable chat text for high-resolution Mac displays. The upstream repository is `lec77/PopChat`; this fork is `aletra06/PopChat`.

`ChatTextSize` stores the size in UserDefaults. `ChatView` observes it and passes it through the SwiftUI environment, including through the existing Equatable message rows. Text render caches include the size. The composer updates its native font without replacing its text, preserving selection and IME composition.

The setting covers messages, reasoning, code, tables, math and the composer. Toolbar controls keep their existing sizes. `FloatingPanel` handles the shortcuts only inside the chat window, using characters to support different keyboard layouts.

The composer opts out of macOS Writing Tools with `writingToolsBehavior = .none` on macOS 15 and later. This applies to both compact and expanded input without changing system-wide Siri settings.

Compact composer controls share a center alignment guide with the last visible text line. The native text view reports both total height and single-line height, so the controls stay centered as font size changes without scaling the icons or replacing the editor.

Math uses the bundled SwiftMath renderer. Display equations accept `$$...$$` and `\[...\]`; inline equations accept `$...$` and `\(...\)`, including in tables. Code spans and fenced code stay literal. Unsupported inline LaTeX stays visible as source text.

Code highlighting uses HighlighterSwift with bundled highlight.js grammars and Atom One light/dark themes. Fenced blocks use their language tag. Copyable cards accept `<pasteable title="Label" language="python">`; older cards recognize clear Python, Swift, JavaScript, shell and JSON structures. Unmarked prose and `language="text"` cards stay plain. Highlighting preserves source characters and the Copy action. Code cards scroll horizontally to preserve indentation. Render caches include language, appearance and text size; blocks over 64 KiB fall back to monospaced text to bound parsing work.

`SelectableText` measures with a copy of its native text-field cell. Attributed-string `boundingRect` undercounted line height and could clip the final line. Keep the per-width and attributed-string identity cache; `--shot code` checks that the final glyph fits.

Upstream update checks only notify; they do not install anything. Installing an upstream release would replace these additions. To update this version, merge upstream changes into this fork and rebuild.
