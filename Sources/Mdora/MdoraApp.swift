import SwiftUI

@main
struct MdoraApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            EditorWindow(document: file.$document)
        }
        .commands {
            SidebarCommands()
            TextEditingCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
