# Roadmap

## Phase 0: Project Foundation

- Choose app shell: Tauri or Electron.
- Choose editor base: CodeMirror 6, Milkdown, or ProseMirror.
- Define file model, document state, and save behavior.
- Create design principles for reading, writing, and exporting.

## Phase 1: Markdown Editor MVP

- Open and save local Markdown files.
- Add editor, preview, and synchronized scroll.
- Add syntax highlighting and keyboard shortcuts.
- Add basic theming.
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
