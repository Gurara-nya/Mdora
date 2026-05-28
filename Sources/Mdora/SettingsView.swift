import SwiftUI

struct SettingsView: View {
    @AppStorage("mdoraTheme") private var themeName = MdoraTheme.system.rawValue
    @AppStorage("showInspector") private var showInspector = true
    @AppStorage("focusMode") private var focusMode = false
    @AppStorage("editorFontSize") private var editorFontSize = 15.0
    @AppStorage("previewFontSize") private var previewFontSize = 16.0
    @AppStorage("previewLineWidth") private var previewLineWidth = 820.0
    @AppStorage("previewAnimations") private var previewAnimations = true

    private var selectedTheme: Binding<MdoraTheme> {
        Binding(
            get: { MdoraTheme(rawValue: themeName) ?? .system },
            set: { themeName = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("App") {
                LabeledContent("Name", value: "Mdora")
                LabeledContent("Editor", value: "Native SwiftUI")
                LabeledContent("Document format", value: "Markdown")
            }

            Section("Appearance") {
                Picker("Theme", selection: selectedTheme) {
                    ForEach(MdoraTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }

                Toggle("Inspector", isOn: $showInspector)
                Toggle("Focus mode", isOn: $focusMode)
                Toggle("Preview animation", isOn: $previewAnimations)
            }

            Section("Typography") {
                LabeledContent("Editor font", value: "\(Int(editorFontSize)) pt")
                Slider(value: $editorFontSize, in: 12 ... 22, step: 1)

                LabeledContent("Preview font", value: "\(Int(previewFontSize)) pt")
                Slider(value: $previewFontSize, in: 13 ... 22, step: 1)

                LabeledContent("Preview width", value: "\(Int(previewLineWidth)) px")
                Slider(value: $previewLineWidth, in: 620 ... 1040, step: 20)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}
