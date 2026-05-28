import MdoraCore
import SwiftUI

struct StatusBar: View {
    let stats: MarkdownStats
    let markers: MarkdownMarkers
    let diagnostics: [MarkdownDiagnostic]
    let theme: MdoraTheme
    let focusMode: Bool
    let message: String?

    var body: some View {
        HStack(spacing: 14) {
            Text("\(stats.words) words")
            Text("\(stats.characters) characters")
            Text("\(stats.lines) lines")
            Text("\(stats.readingMinutes) min read")
            Text("\(stats.blockKinds.count) kinds")
            Text("\(markers.links.count) links")
            Text("\(markers.emailLinks.count) emails")
            Text("\(markers.tags.count) tags")
            Text("\(markers.linkReferences.count) refs")
            Text("\(markers.taskTokens.count) flags")
            Text("\(markers.diagrams.count) diagrams")
            Text("\(diagnostics.count) diagnostics")

            if focusMode {
                Text("focus")
            }

            Spacer()

            if let message {
                Text(message)
                    .foregroundStyle(theme.palette.mutedColor)
            }
        }
        .font(.caption)
        .foregroundStyle(theme.palette.mutedColor)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(theme.palette.surfaceColor)
    }
}
