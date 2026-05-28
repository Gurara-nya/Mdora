import Foundation

public enum MarkdownEmojiShortcode {
    public static func emoji(for name: String) -> String? {
        emojiByName[name.lowercased()]
    }

    public static func displayName(for name: String) -> String {
        if let emoji = emoji(for: name) {
            return "\(emoji) :\(name):"
        }

        return ":\(name):"
    }

    private static let emojiByName: [String: String] = [
        "+1": "👍",
        "-1": "👎",
        "100": "💯",
        "bug": "🐛",
        "bulb": "💡",
        "check": "✅",
        "clap": "👏",
        "construction": "🚧",
        "eyes": "👀",
        "fire": "🔥",
        "heart": "❤️",
        "hourglass": "⌛",
        "idea": "💡",
        "information_source": "ℹ️",
        "memo": "📝",
        "no_entry": "⛔",
        "ok_hand": "👌",
        "pushpin": "📌",
        "question": "❓",
        "rocket": "🚀",
        "sparkles": "✨",
        "star": "⭐",
        "tada": "🎉",
        "warning": "⚠️",
        "white_check_mark": "✅",
        "x": "❌",
        "zap": "⚡"
    ]
}
