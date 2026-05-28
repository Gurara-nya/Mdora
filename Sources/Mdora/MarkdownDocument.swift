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

    Start writing in Markdown. Try **bold**, *italic*, `inline code`, #tags, @mentions, and [links](https://example.com).

    > [!NOTE]
    > Mdora recognizes callouts, symbols, tables, code fences, links, images, and document outline markers.

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
    """
}

extension UTType {
    static let mdoraMarkdown = UTType(importedAs: "net.daringfireball.markdown")
}
