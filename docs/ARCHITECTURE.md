# Architecture Notes

## Core Idea

Mdora should keep Markdown as the source of truth for as long as possible. Rich editing features should be layered on top of Markdown instead of replacing it too early with a proprietary document model.

The first implementation is a native macOS SwiftUI app. It uses Apple's document architecture so file ownership, open, save, duplicate, and close behavior feel familiar on macOS from the start.

## Proposed Modules

- `Sources/Mdora`: native SwiftUI app, document scene, editor, preview, export UI.
- `Sources/MdoraCore`: Markdown block parser, inline parser, document model, marker analyzer, and HTML renderer that can run without launching the app.

## Current Runtime Flow

1. `MarkdownDocument` owns the editable Markdown source.
2. `MarkdownParser` converts source into `ParsedMarkdownDocument`, including block source ranges and normalized link reference definitions.
3. `InlineMarkdownParser` tokenizes inline Markdown semantics used by preview, export, and marker analysis.
4. `MarkdownAnalyzer` derives outline, front matter metadata, marker indexes, diagnostics, and block distribution stats.
5. `MarkdownPreview` renders parsed blocks as native SwiftUI views, highlights the block containing the current editor caret, and can scroll that block into view.
6. `DocumentInspector` reads the same parsed document for outline, metadata, compatibility, diagnostics, block distribution, and marker recognition.
7. `@AppStorage` writing preferences tune editor typography, preview typography, preview line width, focus mode, inspector visibility, preview animation, and preview/editor sync.
8. `MarkdownHTMLRenderer` uses the same block and inline parsers for HTML export, resolving reference links and reference images through the parsed document's shared reference table.

The preview layer resolves remote images directly and local image paths relative to the open Markdown file, including standalone wiki image embeds. Local images are downsampled into preview thumbnails through a bounded cache, and first loads run off the main thread so repeated preview redraws do not re-read or re-decode the same file.

This keeps preview, inspection, and export aligned around one parser.

Future modules:

- `editor`: editing surface, shortcuts, selection, history.
- `markdown`: parsing, rendering, serialization, extensions.
- `preview`: document rendering, synchronized scroll, print styles.
- `workspace`: file tree, recent files, tabs, dirty state.
- `theme`: editor themes, preview themes, typography tokens.

## Editing Strategy

There are three viable levels:

1. Source editor with preview: easiest to ship and debug.
2. Source editor with inline decorations: best next step for a Typora-like feel.
3. Full rich-text block editor with Markdown serialization: most powerful, but highest risk.

The recommended path is to ship level 1, grow into level 2, and only adopt level 3 if the product needs complex block manipulation.

The current app is between level 1 and level 2: it keeps Markdown source as truth, but the editor now adds smart return continuation and caret tracking, and the preview already has block-level and inline semantics for tables, callouts, tasks, code languages, diagrams, math, links, footnotes, definition lists, front matter, images, and document markers.

Block source ranges and normalized link reference definitions are part of the parsed document so the app can coordinate editor state with preview state without trying to infer layout from rendered views or reparsing references in each renderer. The preview sync feature uses source ranges as the stable bridge from caret line to rendered block.

Internal preview links are routed through `MarkdownInternalLinkResolver`, which maps heading anchors, same-document wiki heading/block references, footnotes, tags, mentions, and inspector searches to stable block indexes before SwiftUI scrolls. Cross-file wiki references resolve candidate Markdown files beside the current document before the preview asks AppKit to open them. This keeps navigation cheap and parser-driven instead of walking rendered views.

Task checkbox interactions use the same source-map bridge. `MarkdownTaskSourceEditor` replaces only the single task marker character in the Markdown source, so preview-side task editing stays round-trippable and does not rebuild unrelated text.

Inline parsing is backed by a bounded, thread-safe cache. Preview redraws, marker extraction, and export often revisit identical inline strings, so the cache cuts repeated tokenization while skipping very large text runs to keep memory predictable. Marker extraction then walks the parsed inline segment stream once for most inline marker families, avoiding repeated scans when long documents contain many links, tags, references, review marks, and symbol tokens.

Preview rendering avoids allocating temporary enumerated arrays for block, list, table, and definition-list loops. Source-map line lookups use binary search when mapping the editor caret or line-navigation requests back to a rendered block. Editor-driven preview sync also coalesces rapid caret changes with a short cancellable delay, while explicit link navigation remains immediate.

Local preview images follow the same bounded-resource rule: the UI shows a stable placeholder, decodes a preview-sized thumbnail on a utility task, then reuses that cached `CGImage` for subsequent SwiftUI redraws. This keeps image-heavy notes from stalling the main thread while preserving the original file for open-in-Finder behavior.

Writing preferences are intentionally stored outside the Markdown file. They affect the editing and reading surface without mutating source text, which keeps Markdown round-tripping predictable.

Typing continuations are kept in `MarkdownTypingContinuation` so editor return behavior for bullets, task lists, ordered task lists, quotes, quoted lists, nested quoted lists, and indentation can be tested without launching the AppKit editor. Tab and Shift-Tab line edits use `MarkdownLineEditor`, which returns a small replacement range plus a corrected selection instead of rewriting the whole document.

Editor syntax highlighting keeps fenced code lines and their contents as protected ranges through `MarkdownCodeFenceScanner`, so inline regex passes do not recolor backticks or Markdown-looking text inside code fences. For large documents, the editor asks the scanner only for ranges intersecting the active highlight window and uses the same variable-length delimiter state machine for line-level fence styling.

Paste and image-file drop normalization are kept in `MarkdownPasteTransformer`; the AppKit text view only reads pasteboard file URLs or strings and applies a replacement when the input can safely become a Markdown link or image. Local image files resolve relative to the current Markdown document when possible, keeping pasted and dropped image references portable across folders.

## Compatibility Surface

The parser currently recognizes:

- ATX and setext headings, including empty ATX headings, single-character setext underlines, de-duplicated generated anchors, and Markdown Extra/Pandoc-style custom heading anchors.
- Obsidian-style block ids such as `^block-id`, stripped from visible preview text and exported as HTML block anchors.
- YAML, TOML, and JSON front matter.
- Fenced code blocks with variable-length backtick or tilde delimiters, CommonMark's zero-to-three-space indentation, content de-indentation, and backtick info-string validation rules, plus indented code blocks.
- Diagram fences for Mermaid, Graphviz, PlantUML, sequence, and flowchart sources.
- Inline emphasis, strong text, strikethrough, highlights, superscript, subscript, CriticMarkup review marks, CommonMark code spans with multi-backtick delimiters and spacing normalization, CommonMark hard line breaks, HTML entity references, links and images with balanced parentheses in destinations and nested brackets in labels, reference links, citations, resolved emoji shortcodes, keyboard tags, inline HTML tags, raw autolinks, CommonMark angle-bracket autolinks, email links, wiki links and embeds with aliases and heading/block targets, tags, mentions, footnotes, images, Markdown Extra abbreviations, and math markers.
- Block and inline math markers.
- Ordered lists with both `1.` and `1)` markers, GFM-style tables including escaped pipes and code-span pipes inside cells, plus task lists with extended states such as `[/]`, `[-]`, `[>]`, `[!]`, and `[?]`.
- Blockquotes and Obsidian/GitHub-style callouts, including aliases, custom titles, and `+`/`-` fold markers.
- Footnote definitions and references.
- Definition lists.
- Abbreviation definitions, resolved into inline abbreviation rendering for preview and HTML export.
- Reference link definitions and references, including normalized lookup across preview, diagnostics, and export.
- Image reference syntax with resolved reference definitions, plus email autolinks.
- HTML comments and single-line or multi-line HTML blocks, without stealing CommonMark angle autolinks.
- Images, links, automatic links, wiki links, wiki embeds, block ids, tags, mentions, and TODO-style tokens in plain, commented, unordered-list, ordered-list, and task-list lines.
- Diagnostics for missing references, missing footnotes, duplicate explicit heading anchors, duplicate block ids, and unclosed front matter, variable-length code fences, or math blocks.

## Risks

- Round-trip Markdown fidelity can break when rich editing mutates source text.
- Tables, nested lists, front matter, and mixed HTML are easy to mishandle.
- PDF export quality depends heavily on print CSS.
- Large documents need incremental parsing and careful rendering.

## Early Decisions To Make

- How far the custom parser should go before adopting a CommonMark-compatible library.
- Whether inline preview should be built inside `NSTextView` or through a richer custom text system.
- How HTML inside Markdown should be rendered and sandboxed.
- Whether the first release prioritizes writing, reading, or exporting.
