# Roadmap

## Phase 0: Project Foundation

- Choose app shell: native macOS SwiftUI.
- Choose editor base: AppKit `NSTextView` wrapped in SwiftUI.
- Define file model, document state, and save behavior.
- Create design principles for reading, writing, and exporting.

## Phase 1: Markdown Editor MVP

- Open and save local Markdown files.
- Add editor and preview layout modes.
- Add editor formatting controls.
- Add block-based preview for common Markdown structures.
- Add basic theming.
- Add document outline and marker inspection.
- Add math, diagram, footnote, definition list, wiki link, and TODO-style marker recognition.
- Recognize TODO-style markers after unordered, ordered, parenthesized ordered, task-list, and HTML comment prefixes.
- Add reference link definitions, HTML comment recognition, current-line focus feedback, and generated table of contents insertion.
- Parse escaped pipes and code-span pipes correctly inside GFM table cells.
- Support CommonMark `1)` ordered-list markers across parsing, smart return, and preview task editing.
- Preserve ordered-list start numbers across parser, native preview, and HTML export.
- Add richer Obsidian/GitHub callout parsing for aliases, custom titles, and fold markers.
- Add custom heading anchors for stable outline, table of contents, preview, and HTML export targets.
- De-duplicate generated heading anchors for stable table of contents, preview navigation, and HTML export ids.
- Support CommonMark empty ATX headings and single-character setext heading underlines.
- Parse CommonMark thematic breaks as paragraph terminators without stealing indented code.
- Add Obsidian-style block ids for block references, preview cleanup, inspector recognition, and HTML export anchors.
- Add Markdown Extra abbreviation definitions with preview, export, and inspector support.
- Add YAML/TOML/JSON front matter metadata extraction, block distribution stats, email autolinks, image references, and richer editor semantic highlighting.
- Protect fenced code ranges from inline editor highlighting so code fences and inner backticks keep the correct color.
- Parse variable-length CommonMark code fences so shorter inner fences stay inside code blocks.
- Apply CommonMark zero-to-three-space indentation rules to code fence parsing, diagnostics, and editor highlighting.
- De-indent fenced code content by the opening fence indentation so preview and export match CommonMark.
- Reject backtick-fence info strings that contain backticks while preserving tilde-fence info strings.
- Use the first fence info-string word for code language classes, inspector language stats, and diagram detection.
- Use shared code fence delimiter logic for editor highlighting, parsing, and unclosed fence diagnostics.
- Limit editor fenced-code exclusion scans to the active highlight window for smoother large-document typing.
- Clip editor syntax protected ranges to the active highlight window so huge fenced code, math, or code-span regions do not repaint off-screen text.
- Replace loose editor inline-code regex matching with exact backtick-run scanning so code fences are not partially recolored.
- Make editor backtick auto-pairing fence-aware so typing triple backticks creates real code fences.
- Recover smart-punctuation fence markers such as `‘’‘text` and `’‘’` as backtick-compatible code fences before inline coloring runs.
- Protect editor inline-code contents from later emphasis, link, tag, and TODO highlighters.
- Support multiline CommonMark code span highlighting in the editor without mistaking code fences for spans.
- Protect display math blocks from later inline editor highlighters and resolve overlaps with code fences by source order.
- Add parser diagnostics for missing references, missing footnotes, duplicate anchors, duplicate block ids, and unclosed Markdown structures.
- Add smart return continuation for lists, task lists, ordered lists, quotes, and indentation.
- Continue list, task-list, and ordered-list markers inside blockquotes and nested blockquotes.
- Parse lazy blockquote paragraph continuation lines without swallowing content after a blank line.
- Merge lazy list and task-list continuation lines into the preceding item text.
- Add extended task states for in-progress, canceled, forwarded, important, and question items.
- Add shared inline parsing for preview, marker analysis, and HTML export.
- Preserve CommonMark hard line breaks in preview and HTML export.
- Support CommonMark multi-backtick code spans with spacing normalization across preview, export, and editor highlighting.
- Keep balanced parentheses inside inline link and image destinations.
- Unescape CommonMark backslash escapes inside inline link/image destinations and titles.
- Keep nested brackets inside inline link labels and image alt text.
- Decode and inspect HTML entity references in preview and HTML export.
- Add extended inline markers for highlights, citations, emoji shortcodes, and keyboard tags.
- Add inline HTML tag recognition across preview, export, inspector, and editor highlighting.
- Preserve source lines for single-line and multi-line HTML blocks while leaving angle autolinks inline.
- Preserve blank lines inside CommonMark raw-text HTML blocks and let block HTML interrupt paragraphs without breaking inline HTML spans.
- Render common emoji shortcodes as emoji in preview and HTML export.
- Render Obsidian-style wiki link aliases and expose heading/block targets in HTML export metadata.
- Recognize Obsidian-style `![[...]]` embeds as separate preview, export, inspector, and status markers.
- Add Typora-style superscript and subscript markers across preview, export, inspector, and editor highlighting.
- Add editor insertion commands for highlights, superscript, subscript, keyboard tags, and citations.
- Add tested Tab and Shift-Tab indentation editing for Markdown lines and lists.
- Add smart URL, image URL, local image file paste, and image drag-and-drop transforms for Markdown links and images.
- Add CriticMarkup review marks for additions, deletions, substitutions, comments, and editorial highlights.
- Add CommonMark angle-bracket autolinks for URLs and email addresses.
- Keep balanced parentheses inside raw URL autolinks and share that scanner with editor highlighting.
- Recognize GFM-style `www.` autolinks across preview, export, inspector markers, and editor highlighting.
- Add writing view preferences for typography, preview width, focus mode, inspector visibility, and preview animation.
- Add block source maps, caret position reporting, active preview block highlighting, and synchronized preview scrolling.
- Pause preview parsing, inspector analysis, SwiftUI document binding writes, active preview highlighting, preview-side task edits, and editor syntax repainting during active input; mark the frozen preview and refresh only after Save/Command-S or Command-R commits the local editor draft.
- Add Command-R manual preview refresh that cancels pending parse work and updates preview, inspector, and status immediately.
- Show lightweight status-bar feedback for paused, refreshing, and completed preview parse states.
- Resolve reference links and reference images through a shared normalized definition table in preview, diagnostics, and HTML export.
- Follow CommonMark first-wins reference definition semantics and warn on duplicate normalized reference labels.
- Support escaped brackets in reference definition labels and reject unescaped brackets or overlong labels.
- Support CommonMark reference definition destinations on the following line.
- Support CommonMark reference definition titles on the following line with correct source maps.
- Require balanced unescaped parentheses in bare reference definition destinations.
- Unescape CommonMark backslash escapes inside reference definition destinations and titles.
- Keep incomplete split reference definitions as paragraphs instead of prematurely splitting text.
- Reject malformed reference definitions that contain invalid trailing title text instead of dropping the extra text.
- Drive missing-reference diagnostics from parsed inline segments so collapsed links and images are covered without scanning code spans.
- Drive missing-footnote diagnostics from parsed inline segments so code spans and fenced code blocks do not create false warnings.
- Resolve CommonMark shortcut reference links and images only when matching definitions exist, keeping ordinary bracket text untouched.
- Render local image paths and standalone wiki image embeds in preview relative to the current Markdown file.
- Add bounded inline parser caching to reduce repeated preview, analysis, and export tokenization work.
- Reduce preview loop allocations, use binary source-map lookups, and coalesce editor-driven sync scrolls for smoother large-document navigation.
- Suppress preview update and scroll animations automatically for large documents.
- Add async, downsampled, bounded local image caching to reduce main-thread stalls, disk reads, and image decoding during preview redraws.
- Stream inline marker and missing-reference collection over inline-capable block content to reduce analyzer allocations after explicit preview refreshes.
- Add source-map-backed task checkbox editing from preview, including extended task states.
- Resolve internal and neighboring-file preview navigation for wiki heading/block links, footnotes, tags, and mentions.
- Add export to HTML.

## Phase 2: Live Preview Editing

- Render headings, emphasis, links, inline code, code fences, blockquotes, lists, and images inside the editing surface.
- Keep Markdown source round-trippable.
- Add math and diagram support.
- Add robust undo and redo behavior.

## Phase 3: Desktop Polish

- File tree and recent files.
- Tabs or workspaces.
- Global search.
- Command palette.
- PDF export.
- App settings and theme marketplace.

## Phase 4: Advanced Documents

- Tables with rich editing controls.
- References, footnotes, and backlinks.
- Plugin API.
- Custom blocks.
- Optional sync layer.

## Guiding Principle

Start boring and stable, then make it magical. The hard part is not rendering Markdown; it is preserving text fidelity while the editor feels visual and calm.
