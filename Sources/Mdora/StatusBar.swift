import MdoraCore
import SwiftUI

struct StatusBar: View {
    let stats: MarkdownStats
    let markers: MarkdownMarkers
    let theme: MdoraTheme
    let message: String?

    var body: some View {
        HStack(spacing: 14) {
            Text("\(stats.words) words")
            Text("\(stats.characters) characters")
            Text("\(stats.lines) lines")
            Text("\(markers.links.count) links")
            Text("\(markers.tags.count) tags")
            Text("\(markers.taskTokens.count) flags")
            Text("\(markers.diagrams.count) diagrams")

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
