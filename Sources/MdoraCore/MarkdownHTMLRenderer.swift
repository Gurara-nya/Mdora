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
        return document.blocks.map { block in
            renderBlock(block, references: document.referenceDefinitions)
        }.joined(separator: "\n")
    }

    fileprivate static func escapeHTML(_ text: String) -> String {
        var escaped = text
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        return escaped
    }

    private static func renderBlock(
        _ block: MarkdownBlock,
        references: [String: LinkReferenceDefinition]
    ) -> String {
        switch block {
        case let .frontMatter(frontMatter):
            return "<pre class=\"front-matter front-matter-\(frontMatter.kind.rawValue)\"><code>\(escapeHTML(frontMatter.lines.joined(separator: "\n")))</code></pre>"
        case let .heading(level, text, anchor):
            return "<h\(level) id=\"\(escapeHTML(anchor))\">\(renderInline(text, references: references))</h\(level)>"
        case let .paragraph(text):
            return "<p>\(renderInline(text, references: references))</p>"
        case let .blockquote(lines, callout):
            return renderBlockquote(lines: lines, callout: callout, references: references)
        case let .unorderedList(items):
            return renderList(tag: "ul", items: items, references: references)
        case let .orderedList(items):
            return renderList(tag: "ol", items: items, references: references)
        case let .taskList(items):
            return renderTaskList(items, references: references)
        case let .codeBlock(language, code):
            return renderCodeBlock(language: language, code: code)
        case let .diagram(diagram):
            return renderDiagram(diagram)
        case let .mathBlock(expression):
            return renderMathBlock(expression)
        case let .table(table):
            return renderTable(table, references: references)
        case let .definitionList(items):
            return renderDefinitionList(items, references: references)
        case let .footnoteDefinition(identifier, text):
            return "<p class=\"footnote-definition\" id=\"fn-\(escapeHTML(identifier))\"><sup>\(escapeHTML(identifier))</sup> \(renderInline(text, references: references))</p>"
        case let .linkReferenceDefinition(definition):
            return renderLinkReferenceDefinition(definition, references: references)
        case let .image(alt, source, title):
            return renderImage(alt: alt, source: source, title: title, references: references)
        case .thematicBreak:
            return "<hr>"
        case let .htmlComment(comment):
            return "<pre class=\"html-comment\"><code>\(escapeHTML(comment))</code></pre>"
        case let .html(html):
            return "<pre class=\"html-block\"><code>\(escapeHTML(html))</code></pre>"
        }
    }

    private static func renderBlockquote(
        lines: [String],
        callout: CalloutKind?,
        references: [String: LinkReferenceDefinition]
    ) -> String {
        let body = lines.map { renderInline($0, references: references) }.joined(separator: "<br>")

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

    private static func renderList(
        tag: String,
        items: [ListItem],
        references: [String: LinkReferenceDefinition]
    ) -> String {
        let renderedItems = items.map { item in
            let indentClass = item.depth > 0 ? " class=\"depth-\(item.depth)\"" : ""
            return "<li\(indentClass)>\(renderInline(item.text, references: references))</li>"
        }.joined(separator: "\n")

        return "<\(tag)>\n\(renderedItems)\n</\(tag)>"
    }

    private static func renderTaskList(
        _ items: [TaskItem],
        references: [String: LinkReferenceDefinition]
    ) -> String {
        let renderedItems = items.map { item in
            let checked = item.isDone ? " checked" : ""
            let doneClass = item.isDone ? " done" : ""
            return "<li class=\"task\(doneClass)\"><input type=\"checkbox\" disabled\(checked)> \(renderInline(item.text, references: references))</li>"
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

    private static func renderTable(
        _ table: TableBlock,
        references: [String: LinkReferenceDefinition]
    ) -> String {
        let headerCells = table.headers.enumerated().map { index, header in
            "<th style=\"text-align: \(cssAlignment(table.alignments, at: index))\">\(renderInline(header, references: references))</th>"
        }.joined()

        let bodyRows = table.rows.map { row in
            let cells = row.enumerated().map { index, cell in
                "<td style=\"text-align: \(cssAlignment(table.alignments, at: index))\">\(renderInline(cell, references: references))</td>"
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

    private static func renderDefinitionList(
        _ items: [DefinitionItem],
        references: [String: LinkReferenceDefinition]
    ) -> String {
        let body = items.map { item in
            let definitions = item.definitions.map { definition in
                "<dd>\(renderInline(definition, references: references))</dd>"
            }.joined(separator: "\n")

            return "<dt>\(renderInline(item.term, references: references))</dt>\n\(definitions)"
        }.joined(separator: "\n")

        return "<dl>\n\(body)\n</dl>"
    }

    private static func renderLinkReferenceDefinition(
        _ definition: LinkReferenceDefinition,
        references: [String: LinkReferenceDefinition]
    ) -> String {
        let title = definition.title.map { " <span>\(renderInline($0, references: references))</span>" } ?? ""

        return [
            "<p class=\"link-reference\">",
            "  <strong>[\(escapeHTML(definition.label))]</strong>",
            "  <a href=\"\(escapeHTML(definition.destination))\">\(escapeHTML(definition.destination))</a>",
            title,
            "</p>"
        ].joined(separator: "")
    }

    private static func renderImage(
        alt: String,
        source: String,
        title: String?,
        references: [String: LinkReferenceDefinition]
    ) -> String {
        let titleAttribute = title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
        let image = "<img src=\"\(escapeHTML(source))\" alt=\"\(escapeHTML(alt))\"\(titleAttribute)>"

        if alt.isEmpty {
            return "<figure>\(image)</figure>"
        }

        return "<figure>\(image)<figcaption>\(renderInline(alt, references: references))</figcaption></figure>"
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

    private static func renderInline(
        _ text: String,
        references: [String: LinkReferenceDefinition]
    ) -> String {
        InlineMarkdownParser.parse(text).map { segment in
            renderInlineSegment(segment, references: references)
        }.joined()
    }

    private static func renderInlineSegment(
        _ segment: InlineMarkdownSegment,
        references: [String: LinkReferenceDefinition]
    ) -> String {
        switch segment {
        case let .text(value):
            return escapeHTML(value)
        case let .strong(value):
            return "<strong>\(renderInline(value, references: references))</strong>"
        case let .emphasis(value):
            return "<em>\(renderInline(value, references: references))</em>"
        case let .strikethrough(value):
            return "<del>\(renderInline(value, references: references))</del>"
        case let .highlight(value):
            return "<mark>\(renderInline(value, references: references))</mark>"
        case let .code(value):
            return "<code>\(escapeHTML(value))</code>"
        case let .link(label, destination, title):
            let titleAttribute = title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
            return "<a href=\"\(escapeHTML(destination))\"\(titleAttribute)>\(renderInline(label, references: references))</a>"
        case let .referenceLink(label, reference):
            guard let definition = references[LinkReferenceDefinition.normalizedLabel(reference)] else {
                return "<a href=\"#ref-\(escapeHTML(reference))\">\(renderInline(label, references: references))</a>"
            }

            let titleAttribute = definition.title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
            return "<a href=\"\(escapeHTML(definition.destination))\"\(titleAttribute)>\(renderInline(label, references: references))</a>"
        case let .image(alt, source, title):
            let titleAttribute = title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
            return "<img src=\"\(escapeHTML(source))\" alt=\"\(escapeHTML(alt))\"\(titleAttribute)>"
        case let .imageReference(alt, label):
            if let definition = references[LinkReferenceDefinition.normalizedLabel(label)] {
                let titleAttribute = definition.title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
                return "<img src=\"\(escapeHTML(definition.destination))\" alt=\"\(escapeHTML(alt))\"\(titleAttribute)>"
            }

            return "<span class=\"image-ref\">\(escapeHTML(alt)) [\(escapeHTML(label))]</span>"
        case let .autoLink(url):
            return "<a href=\"\(escapeHTML(url))\">\(escapeHTML(url))</a>"
        case let .email(email):
            return "<a href=\"mailto:\(escapeHTML(email))\">\(escapeHTML(email))</a>"
        case let .wikiLink(value):
            return "<span class=\"wikilink\">\(escapeHTML(value))</span>"
        case let .footnote(identifier):
            return "<sup>\(escapeHTML(identifier))</sup>"
        case let .inlineMath(value):
            return "<span class=\"math-inline\">\(escapeHTML(value))</span>"
        case let .citation(identifier):
            return "<span class=\"citation\">[@\(escapeHTML(identifier))]</span>"
        case let .emojiShortcode(name):
            return "<span class=\"emoji-shortcode\">:\(escapeHTML(name)):</span>"
        case let .keyboard(value):
            return "<kbd>\(escapeHTML(value))</kbd>"
        case let .tag(value):
            return "<span class=\"tag\">#\(escapeHTML(value))</span>"
        case let .mention(value):
            return "<span class=\"mention\">@\(escapeHTML(value))</span>"
        }
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
        .tag, .mention, .wikilink, .math-inline, .image-ref {
          border-radius: 999px;
          padding: 0.08em 0.45em;
          background: rgba(45, 132, 214, 0.16);
        }
        mark {
          border-radius: 0.25em;
          padding: 0.04em 0.22em;
          background: rgba(255, 212, 64, 0.45);
          color: inherit;
        }
        kbd {
          border: 1px solid rgba(127, 127, 127, 0.36);
          border-bottom-width: 2px;
          border-radius: 0.35em;
          padding: 0.04em 0.38em;
          background: rgba(127, 127, 127, 0.12);
          font-family: "SF Mono", ui-monospace, Menlo, monospace;
          font-size: 0.88em;
        }
        .citation, .emoji-shortcode {
          opacity: 0.82;
          font-variant-numeric: tabular-nums;
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
