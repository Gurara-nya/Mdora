import SwiftUI

@main
struct MdoraApp: App {
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            EditorWindow(document: file.$document, documentURL: file.fileURL)
        }
        .commands {
            SidebarCommands()
            TextEditingCommands()

            CommandGroup(replacing: .appInfo) {
                Button("关于 Mdora") {
                    openWindow(id: "about")
                }
            }
        }

        Window("关于 Mdora", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
        }
    }
}
