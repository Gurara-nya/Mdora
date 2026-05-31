# Mdora

Mdora is a Typora-inspired Markdown editor project: local-first, distraction-free, and designed around a live editing experience where Markdown feels close to the final document.

The goal is not to copy Typora's product or interface, but to build a personal Markdown workspace with a clear architecture, open roadmap, and room for experiments.

## Current App

Mdora now starts as a native macOS SwiftUI document app.

Run it from the repository root:

```sh
swift run Mdora
```

Build it:

```sh
swift build
```

The first build includes:

- Native macOS document open/save behavior for Markdown text files.
- Editor, split, and preview layout modes.
- Native text editor with formatting commands for headings, lists, tasks, links, code, tables, images, and callouts.
- Formatting commands for strikethrough, highlights, superscript, subscript, keyboard tags, citations, wiki links, math blocks, diagrams, footnotes, and definition lists.
- Reference link and table-of-contents insertion commands.
- Block-based live preview for CommonMark headings including empty ATX headings and single-character setext underlines, paragraphs with CommonMark hard line breaks, thematic breaks, blockquotes with lazy continuation lines, Obsidian/GitHub callouts with custom titles and fold markers, lists including `1.` and `1)` ordered markers with preserved start numbers plus lazy item continuations, rich task lists, GFM tables with escaped-pipe and code-span pipe handling, images, variable-length code fences with CommonMark indentation, smart-quote fence compatibility, content de-indentation, and first-word info-string language rules, diagrams, math blocks, footnotes, definition lists, single-line, multi-line, and raw-text HTML blocks, and YAML/TOML/JSON front matter.
- Shared inline Markdown parser for preview, marker recognition, and HTML export, covering hard line breaks, HTML entity references, emphasis, strong text, strikethrough, highlights, superscript, subscript, CriticMarkup review marks, CommonMark code spans with multi-backtick delimiters, links and images with balanced parentheses and backslash-unescaped destinations/titles plus nested brackets in labels, full, collapsed, and shortcut reference links/images, inline images, image references, wiki links and embeds with aliases and heading/block targets, citations, resolved emoji shortcodes, keyboard tags, inline HTML tags, tags, mentions, footnotes, Markdown Extra abbreviations, raw and `www.` autolinks with balanced parentheses, angle-bracket autolinks, email links, and inline math.
- Reference link definitions, including escaped label brackets, balanced and backslash-unescaped destinations, CommonMark destinations or titles on following lines, and rejection of invalid labels, incomplete split definitions, or trailing title text, abbreviation definitions, and HTML comments are parsed as visible, inspectable structures, with references and reference images resolved by CommonMark first-wins semantics plus duplicate-definition diagnostics, and abbreviations resolved in preview and HTML export.
- Remote images and local image files are rendered in preview, with relative paths resolved from the current Markdown file location. Standalone wiki image embeds such as `![[Assets/mockup.png|App mockup]]` use the same preview path.
- Local preview images are downsampled and cached with bounded cost, and first loads happen off the main thread so scrolling and hover redraws do not repeatedly read or decode the same files.
- Parser source maps connect Markdown blocks back to their source line ranges for editor/preview coordination, with generated heading anchors de-duplicated for stable links, custom heading anchors such as `{#section-id}` and Obsidian-style block ids such as `^block-id` preserved for outlines, table of contents entries, inspection, and HTML export.
- Internal preview navigation resolves heading anchors, Obsidian wiki heading/block references, footnotes, tags, and @mentions back to the matching rendered block, and cross-file wiki links can open neighboring Markdown files.
- Preview task checkboxes can update the underlying Markdown task marker directly, with a context menu for extended states such as in-progress, forwarded, important, and question.
- Themes for system, paper, graphite, dusk, and high contrast writing modes.
- Writing view settings for editor font size, preview font size, preview line width, focus mode, inspector visibility, preview animation, and editor-synchronized preview scrolling.
- Inspector for outline, metadata, front matter type, block distribution, tags, mentions, wiki links, wiki embeds, block ids, custom heading anchors, abbreviations, citations, HTML entity references, resolved emoji shortcodes, keyboard tags, inline HTML tags, links, automatic links, email links, images, image references, footnotes, highlights, superscript, subscript, CriticMarkup review marks, math, code languages, diagrams, TODO-style tokens in plain, list, task, ordered, and comment lines, comments, and callouts.
- Editor focus feedback with current-line highlight, fence-aware backtick typing, smart-quote fence recovery, and richer Markdown syntax coloring for YAML/TOML front matter, range-aware fenced code spans, display math blocks, exact-run multiline inline code spans with protected contents, hard line breaks, HTML entities, bold, italic, highlights, superscript, subscript, CriticMarkup review marks, citations, emoji shortcodes, keyboard tags, inline HTML tags, images, links, footnotes, URLs, emails, tables, comments, and more. Large-document highlighting clips protected syntax ranges to the active repaint window.
- Smart paste and drag-and-drop convert URL clipboard text into Markdown links for selected text, and image URLs or local image files into Markdown image syntax with relative paths when possible.
- Selection-aware preview feedback highlights the block that contains the editor caret through binary source-map lookup and can keep that block scrolled into view, with cancellable sync-scroll coalescing to avoid jitter during fast cursor movement.
- Preview parsing, inspector analysis, active preview feedback, SwiftUI document binding writes, and editor syntax repainting stay paused while the editor is receiving input; the frozen preview is marked as paused, and Save/Command-S or Command-R commits the local editor draft once before refreshing preview, inspector, status, and editor styling.
- Bounded inline parsing cache plus streaming marker, parsed heading-anchor metadata, shared inline diagnostic, and document-stat collection reduce repeated Markdown work and broad temporary arrays across preview redraws, marker analysis, and export.
- Smart return and Tab/Shift-Tab handling that continues and reshapes lists, task lists, ordered task lists, quotes, quoted lists, and indentation while writing.
- Live diagnostics for empty files, unclosed front matter, variable-length code fences, math blocks, missing or duplicate link/image references including collapsed references, inline-aware missing footnotes, duplicate explicit heading anchors, and duplicate block ids.
- Optional preview update animation and animated layout changes, with preview animations automatically suppressed for large documents.
- Status bar with word, character, line, caret position, reading time, link, tag, flag, diagram, focus, and diagnostic counts.
- HTML export.

## Product Direction

- Local-first Markdown files, with no account required.
- Fast editor startup and smooth typing for long documents.
- Live preview editing as the core experience.
- Strong export path: HTML, PDF, and eventually DOCX.
- Themeable reading and writing modes.
- Extensible blocks for diagrams, math, tables, and code.

## Suggested Technical Path

For a first public version, avoid starting with a full WYSIWYG engine. A practical path:

1. Build a normal Markdown editor with preview.
2. Add inline live preview for headings, emphasis, links, code, math, and images.
3. Move toward a block-based editor only after the Markdown parser, file model, and export pipeline are stable.

Chosen first stack:

- Native macOS: SwiftUI.
- Package/build system: Swift Package Manager.
- Document model: SwiftUI `DocumentGroup` and `FileDocument`.
- Editor: AppKit `NSTextView` wrapped in SwiftUI for native text selection and undo.
- Parser: MdoraCore line-oriented block parser plus shared inline parser for preview, export, metadata extraction, block distribution stats, marker detection, and diagnostics, including YAML/TOML/JSON front matter, ordered lists with `.` and `)` markers, GFM-style tables with escaped pipes and code-span pipes, GFM-style tasks plus extended task states, Obsidian/GitHub callouts with aliases, custom titles, and fold markers, de-duplicated generated heading anchors, CommonMark hard line breaks, thematic breaks, HTML entity references, math, diagrams, empty ATX headings, setext headings, custom heading anchors, Obsidian-style block ids, indented code, CommonMark code-fence indentation, smart-quote fence compatibility, content de-indentation, info-string validation, and first-word language extraction, footnotes, definition lists, Markdown Extra abbreviations, highlights, superscript, subscript, CriticMarkup additions/deletions/substitutions/comments/highlights, citations, resolved emoji shortcodes, keyboard tags, inline HTML tags, wiki link aliases and embeds, reference links, image references, raw and angle-bracket autolinks, email autolinks, and HTML comments.

Future stack candidates:

- Editor engine: extend the current AppKit `NSTextView` with syntax highlighting and inline decorations.
- Markdown pipeline: unified, remark, rehype, markdown-it, or micromark.
- Rich document model later: ProseMirror, Lexical, or Milkdown.
- Export: headless browser PDF first, then Pandoc integration if needed.

## MVP Scope

- Open, edit, save `.md` files.
- Autosave with dirty-state indicator.
- Editor plus preview layout.
- Markdown syntax highlighting.
- Basic theme switcher.
- Export to HTML.
- Keyboard shortcuts for common formatting.

## Repository Status

This repository starts as planning and architecture notes. Implementation can begin once the initial shell and editor stack are selected.

## License

MIT
