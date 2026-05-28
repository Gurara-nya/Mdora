import SwiftUI
import UniformTypeIdentifiers

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.mdoraMarkdown, .plainText]
    }

    var text: String

    init(text: String = MarkdownDocument.defaultText) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

extension MarkdownDocument {
    static let defaultText = """
    ---
    title: Untitled
    app: Mdora
    ---

    # Untitled

    Start writing in Markdown. Try **bold**, *italic*, ~~strikethrough~~, `inline code`, #tags, @mentions, [[Wiki Links]], and [links](https://example.com).

    Reference links are supported too: [Mdora][project].

    <!-- Comments are parsed and visible in the inspector. -->

    > [!NOTE]
    > Mdora recognizes callouts, symbols, tables, code fences, links, images, and document outline markers.

    TODO: Make the editor feel fast and calm.

    - Open an existing `.md` file.
    - Save with Command-S.
    - Switch editor, split, and preview modes in the toolbar.

    - [ ] Build the editor
    - [x] Render a live preview

    | Feature | Status |
    | --- | ---: |
    | Native editor | Ready |
    | Rich preview | In progress |

    ```swift
    let app = "Mdora"
    ```

    $$
    E = mc^2
    $$

    ```mermaid
    flowchart LR
        Idea --> Draft
        Draft --> Preview
    ```

    Markdown
    : A plain text format with structure.

    Typora
    : A reference point for calm Markdown editing.

    Footnotes work too.[^1]

    [^1]: Mdora keeps this as Markdown source.

    [project]: https://github.com/Gurara-nya/Mdora "Mdora on GitHub"
    """
}

extension UTType {
    static let mdoraMarkdown = UTType(importedAs: "net.daringfireball.markdown")
}
