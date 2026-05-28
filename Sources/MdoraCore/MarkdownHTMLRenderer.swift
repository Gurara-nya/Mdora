import Foundation

public enum MarkdownHTMLRenderer {
    public static func renderDocument(_ markdown: String, title: String) -> String {
        let fragment = renderFragment(markdown)
        let escapedTitle = escapeHTML(title)

        return [
            "<!doctype html>",
            "<html lang=\"en\">",
            "<head>",
            "  <meta charset=\"utf-8\">",
            "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
            "  <title>\(escapedTitle)</title>",
            "  <style>",
            css,
            "  </style>",
            "</head>",
            "<body>",
            "  <main>",
            fragment,
            "  </main>",
            "</body>",
            "</html>"
        ].joined(separator: "\n")
    }

    public static func renderFragment(_ markdown: String) -> String {
        let document = MarkdownParser.parse(markdown)
        return document.blocks.map(renderBlock).joined(separator: "\n")
    }

    fileprivate static func escapeHTML(_ text: String) -> String {
        var escaped = text
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        return escaped
    }

    private static func renderBlock(_ block: MarkdownBlock) -> String {
        switch block {
        case let .frontMatter(lines):
            return "<pre class=\"front-matter\"><code>\(escapeHTML(lines.joined(separator: "\n")))</code></pre>"
        case let .heading(level, text, anchor):
            return "<h\(level) id=\"\(escapeHTML(anchor))\">\(renderInline(text))</h\(level)>"
        case let .paragraph(text):
            return "<p>\(renderInline(text))</p>"
        case let .blockquote(lines, callout):
            return renderBlockquote(lines: lines, callout: callout)
        case let .unorderedList(items):
            return renderList(tag: "ul", items: items)
        case let .orderedList(items):
            return renderList(tag: "ol", items: items)
        case let .taskList(items):
            return renderTaskList(items)
        case let .codeBlock(language, code):
            return renderCodeBlock(language: language, code: code)
        case let .diagram(diagram):
            return renderDiagram(diagram)
        case let .mathBlock(expression):
            return renderMathBlock(expression)
        case let .table(table):
            return renderTable(table)
        case let .definitionList(items):
            return renderDefinitionList(items)
        case let .footnoteDefinition(identifier, text):
            return "<p class=\"footnote-definition\" id=\"fn-\(escapeHTML(identifier))\"><sup>\(escapeHTML(identifier))</sup> \(renderInline(text))</p>"
        case let .linkReferenceDefinition(definition):
            return renderLinkReferenceDefinition(definition)
        case let .image(alt, source, title):
            return renderImage(alt: alt, source: source, title: title)
        case .thematicBreak:
            return "<hr>"
        case let .htmlComment(comment):
            return "<pre class=\"html-comment\"><code>\(escapeHTML(comment))</code></pre>"
        case let .html(html):
            return "<pre class=\"html-block\"><code>\(escapeHTML(html))</code></pre>"
        }
    }

    private static func renderBlockquote(lines: [String], callout: CalloutKind?) -> String {
        let body = lines.map(renderInline).joined(separator: "<br>")

        guard let callout else {
            return "<blockquote>\(body)</blockquote>"
        }

        return [
            "<aside class=\"callout callout-\(callout.rawValue)\">",
            "  <p class=\"callout-title\">\(escapeHTML(callout.title))</p>",
            "  <p>\(body)</p>",
            "</aside>"
        ].joined(separator: "\n")
    }

    private static func renderList(tag: String, items: [ListItem]) -> String {
        let renderedItems = items.map { item in
            let indentClass = item.depth > 0 ? " class=\"depth-\(item.depth)\"" : ""
            return "<li\(indentClass)>\(renderInline(item.text))</li>"
        }.joined(separator: "\n")

        return "<\(tag)>\n\(renderedItems)\n</\(tag)>"
    }

    private static func renderTaskList(_ items: [TaskItem]) -> String {
        let renderedItems = items.map { item in
            let checked = item.isDone ? " checked" : ""
            let doneClass = item.isDone ? " done" : ""
            return "<li class=\"task\(doneClass)\"><input type=\"checkbox\" disabled\(checked)> \(renderInline(item.text))</li>"
        }.joined(separator: "\n")

        return "<ul class=\"task-list\">\n\(renderedItems)\n</ul>"
    }

    private static func renderCodeBlock(language: String?, code: String) -> String {
        let languageClass: String
        let label: String

        if let language, !language.isEmpty {
            languageClass = " class=\"language-\(escapeHTML(language))\""
            label = "<span class=\"code-language\">\(escapeHTML(language))</span>"
        } else {
            languageClass = ""
            label = ""
        }

        return "<pre>\(label)<code\(languageClass)>\(escapeHTML(code))</code></pre>"
    }

    private static func renderDiagram(_ diagram: DiagramBlock) -> String {
        [
            "<figure class=\"diagram diagram-\(diagram.kind.rawValue)\">",
            "  <figcaption>\(escapeHTML(diagram.kind.title)) diagram</figcaption>",
            "  <pre><code>\(escapeHTML(diagram.source))</code></pre>",
            "</figure>"
        ].joined(separator: "\n")
    }

    private static func renderMathBlock(_ expression: String) -> String {
        [
            "<figure class=\"math-block\">",
            "  <pre><code>\(escapeHTML(expression))</code></pre>",
            "</figure>"
        ].joined(separator: "\n")
    }

    private static func renderTable(_ table: TableBlock) -> String {
        let headerCells = table.headers.enumerated().map { index, header in
            "<th style=\"text-align: \(cssAlignment(table.alignments, at: index))\">\(renderInline(header))</th>"
        }.joined()

        let bodyRows = table.rows.map { row in
            let cells = row.enumerated().map { index, cell in
                "<td style=\"text-align: \(cssAlignment(table.alignments, at: index))\">\(renderInline(cell))</td>"
            }.joined()

            return "<tr>\(cells)</tr>"
        }.joined(separator: "\n")

        return [
            "<table>",
            "<thead><tr>\(headerCells)</tr></thead>",
            "<tbody>",
            bodyRows,
            "</tbody>",
            "</table>"
        ].joined(separator: "\n")
    }

    private static func renderDefinitionList(_ items: [DefinitionItem]) -> String {
        let body = items.map { item in
            let definitions = item.definitions.map { definition in
                "<dd>\(renderInline(definition))</dd>"
            }.joined(separator: "\n")

            return "<dt>\(renderInline(item.term))</dt>\n\(definitions)"
        }.joined(separator: "\n")

        return "<dl>\n\(body)\n</dl>"
    }

    private static func renderLinkReferenceDefinition(_ definition: LinkReferenceDefinition) -> String {
        let title = definition.title.map { " <span>\(renderInline($0))</span>" } ?? ""

        return [
            "<p class=\"link-reference\">",
            "  <strong>[\(escapeHTML(definition.label))]</strong>",
            "  <a href=\"\(escapeHTML(definition.destination))\">\(escapeHTML(definition.destination))</a>",
            title,
            "</p>"
        ].joined(separator: "")
    }

    private static func renderImage(alt: String, source: String, title: String?) -> String {
        let titleAttribute = title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
        let image = "<img src=\"\(escapeHTML(source))\" alt=\"\(escapeHTML(alt))\"\(titleAttribute)>"

        if alt.isEmpty {
            return "<figure>\(image)</figure>"
        }

        return "<figure>\(image)<figcaption>\(renderInline(alt))</figcaption></figure>"
    }

    private static func cssAlignment(_ alignments: [TableAlignment], at index: Int) -> String {
        guard alignments.indices.contains(index) else { return "left" }

        switch alignments[index] {
        case .leading:
            return "left"
        case .center:
            return "center"
        case .trailing:
            return "right"
        }
    }

    private static func renderInline(_ text: String) -> String {
        var rendered = escapeHTML(text)
        rendered = replace(rendered, pattern: #"`([^`]+)`"#, template: #"<code>$1</code>"#)
        rendered = replace(rendered, pattern: #"~~([^~]+)~~"#, template: #"<del>$1</del>"#)
        rendered = replace(rendered, pattern: #"\*\*([^*]+)\*\*"#, template: #"<strong>$1</strong>"#)
        rendered = replace(rendered, pattern: #"__([^_]+)__"#, template: #"<strong>$1</strong>"#)
        rendered = replace(rendered, pattern: #"\*([^*]+)\*"#, template: #"<em>$1</em>"#)
        rendered = replace(rendered, pattern: #"_([^_]+)_"#, template: #"<em>$1</em>"#)
        rendered = replace(rendered, pattern: #"\[([^\]]+)\]\(([^\)]+)\)"#, template: #"<a href="$2">$1</a>"#)
        rendered = replace(rendered, pattern: #"(?<!\!)\[([^\]]+)\]\[([^\]]+)\]"#, template: ##"<a href="#ref-$2">$1</a>"##)
        rendered = replace(rendered, pattern: #"(?<!\!)\[([^\]]+)\]\[\]"#, template: ##"<a href="#ref-$1">$1</a>"##)
        rendered = replace(rendered, pattern: #"\[\[([^\]]+)\]\]"#, template: #"<span class="wikilink">$1</span>"#)
        rendered = replace(rendered, pattern: #"\[\^([^\]]+)\]"#, template: #"<sup>$1</sup>"#)
        rendered = replace(rendered, pattern: #"(?<!\\)\$([^$\n]+)(?<!\\)\$"#, template: #"<span class="math-inline">$1</span>"#)
        rendered = replace(rendered, pattern: #"(?<![\w">])(https?://[^\s<]+)"#, template: #"<a href="$1">$1</a>"#)
        rendered = replace(rendered, pattern: #"(?<!\w)#([A-Za-z0-9_\-/\p{Han}]+)"#, template: #"<span class="tag">#$1</span>"#)
        rendered = replace(rendered, pattern: #"(?<!\w)@([A-Za-z0-9_\-\.]+)"#, template: #"<span class="mention">@$1</span>"#)
        return rendered
    }

    private static func replace(_ text: String, pattern: String, template: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    private static let css = """
        :root { color-scheme: light dark; }
        body {
          margin: 0;
          font: 16px/1.65 -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
          color: CanvasText;
          background: Canvas;
        }
        main { max-width: 820px; margin: 0 auto; padding: 48px 28px; }
        h1, h2, h3, h4, h5, h6 { line-height: 1.18; margin: 1.35em 0 0.45em; }
        p { margin: 0.85em 0; }
        pre {
          position: relative;
          overflow-x: auto;
          padding: 16px;
          border-radius: 8px;
          background: rgba(127, 127, 127, 0.14);
        }
        pre code { display: block; white-space: pre; }
        code {
          font-family: "SF Mono", ui-monospace, Menlo, monospace;
          font-size: 0.92em;
        }
        table { width: 100%; border-collapse: collapse; margin: 1.1em 0; }
        th, td { border: 1px solid rgba(127, 127, 127, 0.32); padding: 8px 10px; }
        th { background: rgba(127, 127, 127, 0.12); }
        dl { margin: 1em 0; }
        dt { font-weight: 700; }
        dd { margin: 0.25em 0 0.75em 1.4em; }
        a { color: LinkText; }
        blockquote {
          margin-left: 0;
          padding-left: 16px;
          border-left: 3px solid rgba(127, 127, 127, 0.42);
          opacity: 0.86;
        }
        img { max-width: 100%; border-radius: 8px; }
        figcaption { opacity: 0.65; font-size: 0.9em; text-align: center; }
        .front-matter, .html-block, .html-comment { opacity: 0.82; }
        .html-comment { color: rgba(127, 127, 127, 0.9); }
        .footnote-definition { font-size: 0.92em; opacity: 0.86; }
        .link-reference {
          display: flex;
          gap: 0.65em;
          align-items: baseline;
          font-size: 0.92em;
          opacity: 0.86;
        }
        .task-list { list-style: none; padding-left: 0; }
        .task.done { opacity: 0.68; text-decoration: line-through; }
        .code-language { float: right; opacity: 0.58; font-size: 0.82em; text-transform: uppercase; }
        .tag, .mention, .wikilink, .math-inline {
          border-radius: 999px;
          padding: 0.08em 0.45em;
          background: rgba(45, 132, 214, 0.16);
        }
        .diagram, .math-block {
          border-radius: 8px;
          padding: 12px 14px;
          background: rgba(127, 127, 127, 0.10);
          border: 1px solid rgba(127, 127, 127, 0.24);
        }
        .callout {
          border-radius: 8px;
          padding: 12px 14px;
          margin: 1em 0;
          background: rgba(45, 132, 214, 0.12);
          border: 1px solid rgba(45, 132, 214, 0.24);
        }
        .callout-title { margin: 0 0 0.35em; font-weight: 700; }
    """
}
