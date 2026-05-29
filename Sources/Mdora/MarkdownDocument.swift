import Foundation
import SwiftUI
import UniformTypeIdentifiers

final class MarkdownDraftRegistry: @unchecked Sendable {
    static let shared = MarkdownDraftRegistry()

    private let lock = NSLock()
    private var fallbackDrafts: [UUID: String] = [:]
    private var providers: [UUID: () -> String?] = [:]
    private var dirtyDocuments: Set<UUID> = []

    private init() {}

    func registerProvider(for documentID: UUID, provider: @escaping () -> String?) {
        lock.lock()
        providers[documentID] = provider
        lock.unlock()
    }

    func unregisterProvider(for documentID: UUID, fallbackText: String?) {
        lock.lock()
        providers[documentID] = nil
        if let fallbackText {
            fallbackDrafts[documentID] = fallbackText
        }
        lock.unlock()
    }

    func markDirty(for documentID: UUID) {
        lock.lock()
        dirtyDocuments.insert(documentID)
        lock.unlock()
    }

    func storeFallback(_ text: String, for documentID: UUID) {
        lock.lock()
        fallbackDrafts[documentID] = text
        lock.unlock()
    }

    func text(for documentID: UUID) -> String? {
        let provider: (() -> String?)?
        let fallback: String?
        lock.lock()
        provider = providers[documentID]
        fallback = fallbackDrafts[documentID]
        lock.unlock()

        if let provider {
            if Thread.isMainThread {
                return provider() ?? fallback
            }

            var providedText: String?
            DispatchQueue.main.sync {
                providedText = provider()
            }

            if let providedText {
                return providedText
            }
        }

        return fallback
    }

    func clear(for documentID: UUID, matching text: String? = nil) {
        let currentText = self.text(for: documentID)

        lock.lock()
        defer { lock.unlock() }

        guard text == nil || currentText == text else {
            return
        }

        if text == nil || fallbackDrafts[documentID] == text {
            fallbackDrafts[documentID] = nil
        }
        dirtyDocuments.remove(documentID)
    }

    func isDirty(_ documentID: UUID) -> Bool {
        lock.lock()
        let isDirty = dirtyDocuments.contains(documentID)
        lock.unlock()
        return isDirty
    }
}

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.mdoraMarkdown, .plainText]
    }

    let id: UUID
    var text: String

    init(text: String = MarkdownDocument.defaultText, id: UUID = UUID()) {
        self.id = id
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        id = UUID()
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let latestText = MarkdownDraftRegistry.shared.text(for: id) ?? text
        return FileWrapper(regularFileWithContents: Data(latestText.utf8))
    }
}

extension MarkdownDocument {
    static let defaultText = """
    ---
    title: Untitled
    app: Mdora
    ---

    # Untitled {#welcome}

    Start writing in Markdown. Try **bold**, *italic*, ~~strikethrough~~, ==highlight==, H~2~O, 10^2^, :sparkles:, `inline code`, <span class="badge">inline HTML</span>, HTML entities like &copy; and &#x1F680;, #tags, @mentions, [[Knowledge Base|wiki links]], and [links](https://example.com).

    Reference links are supported too: [Mdora][project]. Email autolinks such as hello@example.com are recognized. ^reference-demo

    Abbreviations are expanded in preview and export, so HTML can carry a title.

    Obsidian-style embeds are recognized too: ![[Assets/mockup.png|App mockup]], and links can point to [[Untitled#^reference-demo|a block id]].

    Review marks are recognized: {++added++}, {--removed--}, {~~draft~>polished~~}, {>>editor note<<}, and {==review highlight==}.

    <!-- Comments are parsed and visible in the inspector. -->

    > [!NOTE]+ Rich Markdown markers
    > Mdora recognizes callouts, symbols, tables, code fences, links, images, and document outline markers.

    TODO: Make the editor feel fast and calm.

    - Open an existing `.md` file.
    - Save with Command-S.
    - Switch editor, split, and preview modes in the toolbar.

    - [ ] Build the editor
    - [/] Polish richer task states
    - [!] Keep compatibility sharp
    - [x] Render a live preview

    | Feature | Status |
    | --- | ---: |
    | Native editor | Ready |
    | Rich preview | In progress |

    ![Referenced image][sample-image]

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
    [sample-image]: image.png "Local image reference"
    *[HTML]: Hyper Text Markup Language
    """
}

extension UTType {
    static let mdoraMarkdown = UTType(importedAs: "net.daringfireball.markdown")
}
