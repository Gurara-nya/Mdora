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
    case inlineCode
    case link
    case image
    case heading(Int)
    case quote
    case unorderedList
    case orderedList
    case task
    case codeBlock
    case table
    case callout(CalloutKind)
}
