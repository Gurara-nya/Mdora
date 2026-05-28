import MdoraCore
import SwiftUI

struct StatusBar: View {
    let stats: MarkdownStats
    let markers: MarkdownMarkers
    let diagnostics: [MarkdownDiagnostic]
    let theme: MdoraTheme
    let focusMode: Bool
    let selection: EditorSelection
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
            Text("\(markers.wikiEmbeds.count) embeds")
            Text("\(markers.blockIDs.count) block ids")
            Text("\(markers.customAnchors.count) anchors")
            Text("\(markers.abbreviations.count) abbr")
            Text("\(markers.linkReferences.count) refs")
            Text("\(markers.taskTokens.count) flags")
            Text("\(markers.criticMarkupCount) edits")
            Text("\(markers.diagrams.count) diagrams")
            Text("\(markers.callouts.count) callouts")
            Text("\(diagnostics.count) diagnostics")
            Text("L\(selection.line):C\(selection.column)")

            if selection.selectedLength > 0 {
                Text("\(selection.selectedLength) selected")
            }

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
