# Fork context

This fork adds readable chat text for high-resolution Mac displays. The upstream repository is `lec77/PopChat`; this fork is `aletra06/PopChat`.

`ChatTextSize` stores the size in UserDefaults. `ChatView` observes it and passes it through the SwiftUI environment, including through the existing Equatable message rows. Text render caches include the size. The composer updates its native font without replacing its text, preserving selection and IME composition.

The setting covers messages, reasoning, code, tables, math and the composer. Toolbar controls keep their existing sizes. `FloatingPanel` handles the shortcuts only inside the chat window, using characters to support different keyboard layouts.

Math uses the bundled SwiftMath renderer. Display equations accept `$$...$$` and `\[...\]`; inline equations accept `$...$` and `\(...\)`, including in tables. Code spans and fenced code stay literal. Unsupported inline LaTeX stays visible as source text.

Upstream update checks only notify; they do not install anything. Installing an upstream release would replace these additions. To update this version, merge upstream changes into this fork and rebuild.
