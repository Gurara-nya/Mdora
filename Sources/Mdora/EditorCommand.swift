import Foundation
import MdoraCore

final class EditorCommandCenter: ObservableObject {
    @Published private(set) var command: EditorCommand?

    func send(_ action: EditorAction) {
        command = EditorCommand(action: action)
    }
}

struct EditorCommand: Equatable {
    let id = UUID()
    let action: EditorAction
}

enum EditorAction: Equatable {
    case bold
    case italic
    case strikethrough
    case inlineCode
    case link
    case wikiLink
    case image
    case heading(Int)
    case quote
    case unorderedList
    case orderedList
    case task
    case codeBlock
    case mathBlock
    case diagram(DiagramKind)
    case footnote
    case linkReference
    case definitionList
    case tableOfContents([DocumentSymbol])
    case table
    case callout(CalloutKind)
}
