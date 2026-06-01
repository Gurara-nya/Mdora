import MdoraCore
import SwiftUI
import UniformTypeIdentifiers

struct HTMLExportDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.html]
    }

    static var writableContentTypes: [UTType] {
        [.html]
    }

    var html: String

    static let empty = HTMLExportDocument(html: "")

    init(html: String) {
        self.html = html
    }

    init(markdown: String) {
        html = MarkdownHTMLRenderer.renderDocument(markdown, title: "Mdora Export")
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        html = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(html.utf8))
    }
}
