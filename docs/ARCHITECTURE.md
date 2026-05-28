# Architecture Notes

## Core Idea

Mdora should keep Markdown as the source of truth for as long as possible. Rich editing features should be layered on top of Markdown instead of replacing it too early with a proprietary document model.

## Proposed Modules

- `app-shell`: desktop window, menus, file permissions, native dialogs.
- `editor`: editing surface, shortcuts, selection, history.
- `markdown`: parsing, rendering, serialization, extensions.
- `preview`: document rendering, synchronized scroll, print styles.
- `workspace`: file tree, recent files, tabs, dirty state.
- `export`: HTML, PDF, and future DOCX/Pandoc paths.
- `theme`: editor themes, preview themes, typography tokens.

## Editing Strategy

There are three viable levels:

1. Source editor with preview: easiest to ship and debug.
2. Source editor with inline decorations: best next step for a Typora-like feel.
3. Full rich-text block editor with Markdown serialization: most powerful, but highest risk.

The recommended path is to ship level 1, grow into level 2, and only adopt level 3 if the product needs complex block manipulation.

## Risks

- Round-trip Markdown fidelity can break when rich editing mutates source text.
- Tables, nested lists, front matter, and mixed HTML are easy to mishandle.
- PDF export quality depends heavily on print CSS.
- Large documents need incremental parsing and careful rendering.

## Early Decisions To Make

- Tauri or Electron.
- CodeMirror-first or Milkdown-first.
- Whether HTML inside Markdown is supported in MVP.
- Whether the first release prioritizes writing, reading, or exporting.
