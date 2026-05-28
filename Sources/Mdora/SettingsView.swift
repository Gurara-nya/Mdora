import SwiftUI

struct SettingsView: View {
    @AppStorage("mdoraTheme") private var themeName = MdoraTheme.system.rawValue
    @AppStorage("showInspector") private var showInspector = true

    private var selectedTheme: Binding<MdoraTheme> {
        Binding(
            get: { MdoraTheme(rawValue: themeName) ?? .system },
            set: { themeName = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            LabeledContent("App", value: "Mdora")
            LabeledContent("Editor", value: "Native SwiftUI")
            LabeledContent("Document format", value: "Markdown")

            Picker("Theme", selection: selectedTheme) {
                ForEach(MdoraTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }

            Toggle("Inspector", isOn: $showInspector)
        }
        .padding(24)
        .frame(width: 360)
    }
}
