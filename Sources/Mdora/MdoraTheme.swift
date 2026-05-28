import AppKit
import SwiftUI

enum MdoraTheme: String, CaseIterable, Identifiable {
    case system
    case paper
    case graphite
    case dusk
    case highContrast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            "系统默认"
        case .paper:
            "经典明雅"
        case .graphite:
            "极简石墨"
        case .dusk:
            "暗夜暮色"
        case .highContrast:
            "高对比度"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .system:
            ThemePalette(
                window: .windowBackgroundColor,
                editor: .textBackgroundColor,
                preview: .windowBackgroundColor,
                surface: .controlBackgroundColor,
                text: .labelColor,
                muted: .secondaryLabelColor,
                border: .separatorColor,
                accent: NSColor.systemBlue,
                code: NSColor.systemGray.withAlphaComponent(0.16)
            )
        case .paper:
            ThemePalette(
                window: NSColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1),
                editor: NSColor(red: 0.995, green: 0.985, blue: 0.955, alpha: 1),
                preview: NSColor(red: 0.985, green: 0.965, blue: 0.925, alpha: 1),
                surface: NSColor(red: 0.93, green: 0.90, blue: 0.82, alpha: 1),
                text: NSColor(red: 0.17, green: 0.15, blue: 0.12, alpha: 1),
                muted: NSColor(red: 0.46, green: 0.40, blue: 0.34, alpha: 1),
                border: NSColor(red: 0.78, green: 0.71, blue: 0.61, alpha: 1),
                accent: NSColor(red: 0.16, green: 0.43, blue: 0.54, alpha: 1),
                code: NSColor(red: 0.88, green: 0.84, blue: 0.76, alpha: 1)
            )
        case .graphite:
            ThemePalette(
                window: NSColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1),
                editor: NSColor(red: 0.13, green: 0.14, blue: 0.15, alpha: 1),
                preview: NSColor(red: 0.095, green: 0.105, blue: 0.115, alpha: 1),
                surface: NSColor(red: 0.18, green: 0.19, blue: 0.20, alpha: 1),
                text: NSColor(red: 0.90, green: 0.91, blue: 0.90, alpha: 1),
                muted: NSColor(red: 0.63, green: 0.66, blue: 0.66, alpha: 1),
                border: NSColor(red: 0.31, green: 0.33, blue: 0.34, alpha: 1),
                accent: NSColor(red: 0.34, green: 0.68, blue: 0.78, alpha: 1),
                code: NSColor(red: 0.18, green: 0.20, blue: 0.22, alpha: 1)
            )
        case .dusk:
            ThemePalette(
                window: NSColor(red: 0.15, green: 0.13, blue: 0.18, alpha: 1),
                editor: NSColor(red: 0.18, green: 0.16, blue: 0.21, alpha: 1),
                preview: NSColor(red: 0.13, green: 0.12, blue: 0.17, alpha: 1),
                surface: NSColor(red: 0.24, green: 0.20, blue: 0.28, alpha: 1),
                text: NSColor(red: 0.94, green: 0.91, blue: 0.88, alpha: 1),
                muted: NSColor(red: 0.70, green: 0.65, blue: 0.69, alpha: 1),
                border: NSColor(red: 0.38, green: 0.31, blue: 0.42, alpha: 1),
                accent: NSColor(red: 0.93, green: 0.58, blue: 0.32, alpha: 1),
                code: NSColor(red: 0.22, green: 0.18, blue: 0.26, alpha: 1)
            )
        case .highContrast:
            ThemePalette(
                window: .black,
                editor: .black,
                preview: .black,
                surface: NSColor(white: 0.08, alpha: 1),
                text: .white,
                muted: NSColor(white: 0.78, alpha: 1),
                border: .white,
                accent: .systemYellow,
                code: NSColor(white: 0.14, alpha: 1)
            )
        }
    }
}

struct ThemePalette {
    var window: NSColor
    var editor: NSColor
    var preview: NSColor
    var surface: NSColor
    var text: NSColor
    var muted: NSColor
    var border: NSColor
    var accent: NSColor
    var code: NSColor

    var windowColor: Color { Color(nsColor: window) }
    var editorColor: Color { Color(nsColor: editor) }
    var previewColor: Color { Color(nsColor: preview) }
    var surfaceColor: Color { Color(nsColor: surface) }
    var textColor: Color { Color(nsColor: text) }
    var mutedColor: Color { Color(nsColor: muted) }
    var borderColor: Color { Color(nsColor: border) }
    var accentColor: Color { Color(nsColor: accent) }
    var codeColor: Color { Color(nsColor: code) }

    var textColorHex: String { text.hexString }
    var accentColorHex: String { accent.hexString }
}

extension NSColor {
    var hexString: String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#000000" }
        let r = max(0, min(1, rgbColor.redComponent))
        let g = max(0, min(1, rgbColor.greenComponent))
        let b = max(0, min(1, rgbColor.blueComponent))
        let red = Int(r * 255)
        let green = Int(g * 255)
        let blue = Int(b * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
