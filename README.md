# Mdora

Mdora is a Typora-inspired Markdown editor project: local-first, distraction-free, and designed around a live editing experience where Markdown feels close to the final document.

The goal is not to copy Typora's product or interface, but to build a personal Markdown workspace with a clear architecture, open roadmap, and room for experiments.

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

Recommended stack candidates:

- Desktop shell: Tauri for a small native app, or Electron for faster ecosystem support.
- UI: React + TypeScript + Vite.
- Markdown editor: CodeMirror 6.
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
