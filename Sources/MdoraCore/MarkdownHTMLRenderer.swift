import Foundation

public enum MarkdownHTMLRenderer {
    private struct RenderContext {
        var references: [String: LinkReferenceDefinition]
        var abbreviations: [String: AbbreviationDefinition]

        var sortedAbbreviations: [AbbreviationDefinition] {
            abbreviations.values.sorted { first, second in
                if first.term.count == second.term.count {
                    return first.term < second.term
                }

                return first.term.count > second.term.count
            }
        }
    }

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
            #"  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.css">"#,
            #"  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.js"></script>"#,
            #"  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/contrib/auto-render.min.js" onload="renderMathInElement(document.body, { delimiters: [ {left: '$$', right: '$$', display: true}, {left: '\\\\[', right: '\\\\]', display: true}, {left: '\\\\(', right: '\\\\)', display: false}, {left: '$', right: '$', display: false} ], throwOnError: false });"></script>"#,
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
        let context = RenderContext(
            references: document.referenceDefinitions,
            abbreviations: document.abbreviationDefinitions
        )

        return document.blocks.map { block in
            renderBlock(block, context: context)
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
        context: RenderContext
    ) -> String {
        switch block {
        case let .frontMatter(frontMatter):
            return "<pre class=\"front-matter front-matter-\(frontMatter.kind.rawValue)\"><code>\(escapeHTML(frontMatter.lines.joined(separator: "\n")))</code></pre>"
        case let .heading(level, text, anchor):
            let blockID = MarkdownBlockIDParser.splitTrailingIdentifier(in: text)
            let content = blockID?.content ?? text
            return "<h\(level) id=\"\(escapeHTML(anchor))\"\(blockIDDataAttribute(blockID?.identifier))>\(renderInline(content, context: context))</h\(level)>"
        case let .paragraph(text):
            let blockID = MarkdownBlockIDParser.splitTrailingIdentifier(in: text)
            let content = blockID?.content ?? text
            return "<p\(blockIDAttributes(blockID?.identifier))>\(renderInline(content, context: context))</p>"
        case let .blockquote(blocks, callout):
            return renderBlockquote(blocks: blocks, callout: callout, context: context)
        case let .unorderedList(items):
            return renderList(tag: "ul", items: items, context: context)
        case let .orderedList(items):
            return renderList(tag: "ol", items: items, context: context)
        case let .taskList(items):
            return renderTaskList(items, context: context)
        case let .codeBlock(language, code):
            return renderCodeBlock(language: language, code: code)
        case let .diagram(diagram):
            return renderDiagram(diagram)
        case let .mathBlock(expression):
            return renderMathBlock(expression)
        case let .table(table):
            return renderTable(table, context: context)
        case let .definitionList(items):
            return renderDefinitionList(items, context: context)
        case let .footnoteDefinition(identifier, text):
            return "<p class=\"footnote-definition\" id=\"fn-\(escapeHTML(identifier))\"><sup>\(escapeHTML(identifier))</sup> \(renderInline(text, context: context))</p>"
        case let .linkReferenceDefinition(definition):
            return renderLinkReferenceDefinition(definition, context: context)
        case let .abbreviationDefinition(definition):
            return renderAbbreviationDefinition(definition)
        case let .image(alt, source, title):
            return renderImage(alt: alt, source: source, title: title, context: context)
        case .thematicBreak:
            return "<hr>"
        case let .htmlComment(comment):
            return "<pre class=\"html-comment\"><code>\(escapeHTML(comment))</code></pre>"
        case let .html(html):
            return "<pre class=\"html-block\"><code>\(escapeHTML(html))</code></pre>"
        }
    }

    private static func renderBlockquote(
        blocks: [MarkdownBlock],
        callout: Callout?,
        context: RenderContext
    ) -> String {
        let body = blocks.map { renderBlock($0, context: context) }.joined(separator: "\n")

        guard let callout else {
            return "<blockquote>\n\(body)\n</blockquote>"
        }

        let calloutClass = "callout callout-\(callout.kind.rawValue)"
        let metadata = " data-callout=\"\(escapeHTML(callout.kind.rawValue))\""

        if let fold = callout.fold {
            let openAttribute = fold == .expanded ? " open" : ""
            return [
                "<details class=\"\(calloutClass)\"\(metadata) data-fold=\"\(fold.rawValue)\"\(openAttribute)>",
                "  <summary class=\"callout-title\">\(escapeHTML(callout.displayTitle))</summary>",
                body.isEmpty ? nil : "  <div class=\"callout-content\">\n\(body)\n  </div>",
                "</details>"
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
        }

        return [
            "<aside class=\"\(calloutClass)\"\(metadata)>",
            "  <p class=\"callout-title\">\(escapeHTML(callout.displayTitle))</p>",
            body.isEmpty ? nil : "  <div class=\"callout-content\">\n\(body)\n  </div>",
            "</aside>"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private static func renderList(
        tag: String,
        items: [ListItem],
        context: RenderContext
    ) -> String {
        let renderedItems = items.map { item in
            let blockID = MarkdownBlockIDParser.splitTrailingIdentifier(in: item.text)
            let content = blockID?.content ?? item.text
            let indentClass = item.depth > 0 ? " class=\"depth-\(item.depth)\"" : ""
            return "<li\(indentClass)\(blockIDAttributes(blockID?.identifier))>\(renderInline(content, context: context))</li>"
        }.joined(separator: "\n")

        return "<\(tag)>\n\(renderedItems)\n</\(tag)>"
    }

    private static func renderTaskList(
        _ items: [TaskItem],
        context: RenderContext
    ) -> String {
        let renderedItems = items.map { item in
            let blockID = MarkdownBlockIDParser.splitTrailingIdentifier(in: item.text)
            let content = blockID?.content ?? item.text
            let checked = item.isDone ? " checked" : ""
            let stateClass = " state-\(item.state.cssClass)"
            let doneClass = item.isDone ? " done" : ""
            let stateMarker = taskStateMarker(item.state)
            return "<li class=\"task\(doneClass)\(stateClass)\"\(blockIDAttributes(blockID?.identifier)) data-task-state=\"\(escapeHTML(item.state.cssClass))\"><input type=\"checkbox\" disabled\(checked)>\(stateMarker) \(renderInline(content, context: context))</li>"
        }.joined(separator: "\n")

        return "<ul class=\"task-list\">\n\(renderedItems)\n</ul>"
    }

    private static func taskStateMarker(_ state: TaskState) -> String {
        switch state {
        case .todo, .done:
            return ""
        default:
            return " <span class=\"task-state\" title=\"\(escapeHTML(state.title))\">\(escapeHTML(state.marker))</span>"
        }
    }

    private static func blockIDAttributes(_ identifier: String?) -> String {
        guard let identifier else { return "" }
        let escaped = escapeHTML(identifier)
        return " id=\"\(escaped)\" data-block-id=\"\(escaped)\""
    }

    private static func blockIDDataAttribute(_ identifier: String?) -> String {
        guard let identifier else { return "" }
        return " data-block-id=\"\(escapeHTML(identifier))\""
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
        "<div class=\"math-block\">$$\(escapeHTML(expression))$$</div>"
    }

    private static func renderTable(
        _ table: TableBlock,
        context: RenderContext
    ) -> String {
        let headerCells = table.headers.enumerated().map { index, header in
            "<th style=\"text-align: \(cssAlignment(table.alignments, at: index))\">\(renderInline(header, context: context))</th>"
        }.joined()

        let bodyRows = table.rows.map { row in
            let cells = row.enumerated().map { index, cell in
                "<td style=\"text-align: \(cssAlignment(table.alignments, at: index))\">\(renderInline(cell, context: context))</td>"
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
        context: RenderContext
    ) -> String {
        let body = items.map { item in
            let definitions = item.definitions.map { definition in
                "<dd>\(renderInline(definition, context: context))</dd>"
            }.joined(separator: "\n")

            return "<dt>\(renderInline(item.term, context: context))</dt>\n\(definitions)"
        }.joined(separator: "\n")

        return "<dl>\n\(body)\n</dl>"
    }

    private static func renderLinkReferenceDefinition(
        _ definition: LinkReferenceDefinition,
        context: RenderContext
    ) -> String {
        let title = definition.title.map { " <span>\(renderInline($0, context: context))</span>" } ?? ""

        return [
            "<p class=\"link-reference\">",
            "  <strong>[\(escapeHTML(definition.label))]</strong>",
            "  <a href=\"\(escapeHTML(definition.destination))\">\(escapeHTML(definition.destination))</a>",
            title,
            "</p>"
        ].joined(separator: "")
    }

    private static func renderAbbreviationDefinition(_ definition: AbbreviationDefinition) -> String {
        [
            "<p class=\"abbreviation-reference\">",
            "  <strong>*[\(escapeHTML(definition.term))]</strong>",
            "  <span>\(escapeHTML(definition.expansion))</span>",
            "</p>"
        ].joined(separator: "")
    }

    private static func renderImage(
        alt: String,
        source: String,
        title: String?,
        context: RenderContext
    ) -> String {
        let titleAttribute = title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
        let image = "<img src=\"\(escapeHTML(source))\" alt=\"\(escapeHTML(alt))\"\(titleAttribute)>"

        if alt.isEmpty {
            return "<figure>\(image)</figure>"
        }

        return "<figure>\(image)<figcaption>\(renderInline(alt, context: context))</figcaption></figure>"
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
        context: RenderContext
    ) -> String {
        InlineMarkdownParser.parse(text).map { segment in
            renderInlineSegment(segment, context: context)
        }.joined()
    }

    private static func renderInlineSegment(
        _ segment: InlineMarkdownSegment,
        context: RenderContext
    ) -> String {
        switch segment {
        case let .text(value):
            return renderText(value, context: context)
        case let .strong(value):
            return "<strong>\(renderInline(value, context: context))</strong>"
        case let .emphasis(value):
            return "<em>\(renderInline(value, context: context))</em>"
        case let .strikethrough(value):
            return "<del>\(renderInline(value, context: context))</del>"
        case let .highlight(value):
            return "<mark>\(renderInline(value, context: context))</mark>"
        case let .superscript(value):
            return "<sup>\(renderInline(value, context: context))</sup>"
        case let .subscriptText(value):
            return "<sub>\(renderInline(value, context: context))</sub>"
        case let .criticAddition(value):
            return "<ins class=\"critic-addition\">\(renderInline(value, context: context))</ins>"
        case let .criticDeletion(value):
            return "<del class=\"critic-deletion\">\(renderInline(value, context: context))</del>"
        case let .criticSubstitution(original, replacement):
            return "<span class=\"critic-substitution\"><del>\(renderInline(original, context: context))</del><ins>\(renderInline(replacement, context: context))</ins></span>"
        case let .criticComment(value):
            return "<span class=\"critic-comment\">\(renderInline(value, context: context))</span>"
        case let .criticHighlight(value):
            return "<mark class=\"critic-highlight\">\(renderInline(value, context: context))</mark>"
        case let .code(value):
            return "<code>\(escapeHTML(value))</code>"
        case let .link(label, destination, title):
            let titleAttribute = title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
            return "<a href=\"\(escapeHTML(destination))\"\(titleAttribute)>\(renderInline(label, context: context))</a>"
        case let .referenceLink(label, reference):
            guard let definition = context.references[LinkReferenceDefinition.normalizedLabel(reference)] else {
                return "<a href=\"#ref-\(escapeHTML(reference))\">\(renderInline(label, context: context))</a>"
            }

            let titleAttribute = definition.title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
            return "<a href=\"\(escapeHTML(definition.destination))\"\(titleAttribute)>\(renderInline(label, context: context))</a>"
        case let .image(alt, source, title):
            let titleAttribute = title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
            return "<img src=\"\(escapeHTML(source))\" alt=\"\(escapeHTML(alt))\"\(titleAttribute)>"
        case let .imageReference(alt, label):
            if let definition = context.references[LinkReferenceDefinition.normalizedLabel(label)] {
                let titleAttribute = definition.title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
                return "<img src=\"\(escapeHTML(definition.destination))\" alt=\"\(escapeHTML(alt))\"\(titleAttribute)>"
            }

            return "<span class=\"image-ref\">\(escapeHTML(alt)) [\(escapeHTML(label))]</span>"
        case let .autoLink(url):
            return "<a href=\"\(escapeHTML(url))\">\(escapeHTML(url))</a>"
        case let .email(email):
            return "<a href=\"mailto:\(escapeHTML(email))\">\(escapeHTML(email))</a>"
        case let .wikiLink(value):
            let reference = MarkdownWikiLinkReference.parse(value)
            return "<span class=\"wikilink\"\(wikiReferenceAttributes(reference))>\(escapeHTML(reference.displayText))</span>"
        case let .wikiEmbed(value):
            let reference = MarkdownWikiLinkReference.parse(value)
            if reference.isImageEmbed {
                return "<img class=\"wiki-embed wiki-embed-image\" src=\"\(escapeHTML(reference.target))\" alt=\"\(escapeHTML(reference.embedDisplayText))\"\(wikiReferenceAttributes(reference))>"
            }

            return "<span class=\"wiki-embed\"\(wikiReferenceAttributes(reference))>\(escapeHTML(reference.embedDisplayText))</span>"
        case let .footnote(identifier):
            return "<sup>\(escapeHTML(identifier))</sup>"
        case let .inlineMath(value):
            return "<span class=\"math-inline\">\\(\(escapeHTML(value))\\)</span>"
        case let .citation(identifier):
            return "<span class=\"citation\">[@\(escapeHTML(identifier))]</span>"
        case let .emojiShortcode(name):
            if let emoji = MarkdownEmojiShortcode.emoji(for: name) {
                return "<span class=\"emoji-shortcode\" title=\":\(escapeHTML(name)):\">\(emoji)</span>"
            }

            return "<span class=\"emoji-shortcode\">:\(escapeHTML(name)):</span>"
        case let .keyboard(value):
            return "<kbd>\(escapeHTML(value))</kbd>"
        case let .tag(value):
            return "<span class=\"tag\">#\(escapeHTML(value))</span>"
        case let .mention(value):
            return "<span class=\"mention\">@\(escapeHTML(value))</span>"
        }
    }

    private static func wikiReferenceAttributes(_ reference: MarkdownWikiLinkReference) -> String {
        var attributes = " data-target=\"\(escapeHTML(reference.target))\""
        if let alias = reference.alias {
            attributes += " data-alias=\"\(escapeHTML(alias))\""
        }
        if !reference.path.isEmpty {
            attributes += " data-path=\"\(escapeHTML(reference.path))\""
        }
        if let heading = reference.heading {
            attributes += " data-heading=\"\(escapeHTML(heading))\""
        }
        if let blockID = reference.blockID {
            attributes += " data-block-id=\"\(escapeHTML(blockID))\""
        }
        return attributes
    }

    private static func renderText(_ text: String, context: RenderContext) -> String {
        guard !context.abbreviations.isEmpty else { return escapeHTML(text) }

        var rendered = ""
        var cursor = text.startIndex

        while cursor < text.endIndex {
            if let definition = matchingAbbreviation(in: text, at: cursor, context: context) {
                rendered += "<abbr title=\"\(escapeHTML(definition.expansion))\">\(escapeHTML(definition.term))</abbr>"
                cursor = text.index(cursor, offsetBy: definition.term.count)
                continue
            }

            rendered += escapeHTML(String(text[cursor]))
            cursor = text.index(after: cursor)
        }

        return rendered
    }

    private static func matchingAbbreviation(
        in text: String,
        at index: String.Index,
        context: RenderContext
    ) -> AbbreviationDefinition? {
        context.sortedAbbreviations.first { definition in
            guard text[index...].hasPrefix(definition.term) else { return false }

            let end = text.index(index, offsetBy: definition.term.count)
            return hasAbbreviationBoundary(before: index, in: text, term: definition.term)
                && hasAbbreviationBoundary(after: end, in: text, term: definition.term)
        }
    }

    private static func hasAbbreviationBoundary(
        before index: String.Index,
        in text: String,
        term: String
    ) -> Bool {
        guard let first = term.first, first.isLetter || first.isNumber else { return true }
        guard index > text.startIndex else { return true }
        return !text[text.index(before: index)].isAbbreviationWordCharacter
    }

    private static func hasAbbreviationBoundary(
        after index: String.Index,
        in text: String,
        term: String
    ) -> Bool {
        guard let last = term.last, last.isLetter || last.isNumber else { return true }
        guard index < text.endIndex else { return true }
        return !text[index].isAbbreviationWordCharacter
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
        .link-reference,
        .abbreviation-reference {
          display: flex;
          gap: 0.65em;
          align-items: baseline;
          font-size: 0.92em;
          opacity: 0.86;
        }
        abbr {
          cursor: help;
          text-decoration-line: underline;
          text-decoration-style: dotted;
          text-decoration-color: rgba(45, 132, 214, 0.78);
          text-underline-offset: 0.16em;
        }
        .task-list { list-style: none; padding-left: 0; }
        .task.done, .task.state-canceled { opacity: 0.68; text-decoration: line-through; }
        .task-state {
          display: inline-flex;
          justify-content: center;
          min-width: 1.35em;
          margin-right: 0.25em;
          border-radius: 999px;
          background: rgba(127, 127, 127, 0.14);
          font-size: 0.82em;
          font-weight: 700;
        }
        .task.state-important .task-state { background: rgba(220, 38, 38, 0.16); }
        .task.state-question .task-state { background: rgba(14, 165, 233, 0.16); }
        .code-language { float: right; opacity: 0.58; font-size: 0.82em; text-transform: uppercase; }
        .tag, .mention, .wikilink, .wiki-embed, .math-inline, .image-ref {
          border-radius: 999px;
          padding: 0.08em 0.45em;
          background: rgba(45, 132, 214, 0.16);
        }
        .wiki-embed-image {
          display: block;
          max-width: 100%;
          height: auto;
          border-radius: 8px;
          padding: 0;
          background: transparent;
        }
        mark {
          border-radius: 0.25em;
          padding: 0.04em 0.22em;
          background: rgba(255, 212, 64, 0.45);
          color: inherit;
        }
        ins.critic-addition,
        .critic-substitution ins {
          border-radius: 0.25em;
          padding: 0.02em 0.18em;
          background: rgba(45, 180, 96, 0.18);
          color: inherit;
          text-decoration-thickness: 0.08em;
        }
        del.critic-deletion,
        .critic-substitution del {
          color: rgba(127, 127, 127, 0.92);
          text-decoration-thickness: 0.08em;
        }
        .critic-substitution {
          display: inline-flex;
          gap: 0.35em;
          align-items: baseline;
        }
        .critic-substitution del::after {
          content: "->";
          margin-left: 0.35em;
          color: rgba(127, 127, 127, 0.72);
          text-decoration: none;
        }
        .critic-comment {
          border-radius: 0.25em;
          padding: 0.04em 0.36em;
          background: rgba(127, 127, 127, 0.14);
          color: rgba(127, 127, 127, 0.96);
          font-style: italic;
        }
        .critic-highlight {
          outline: 1px solid rgba(255, 212, 64, 0.4);
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
        .emoji-shortcode {
          font-size: 1.05em;
          vertical-align: -0.02em;
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
        summary.callout-title { cursor: pointer; }
        details.callout:not([open]) { padding-bottom: 12px; }

        @media print {
          @page {
            margin: 20mm;
          }
          body {
            background: white !important;
            color: black !important;
            font-size: 11pt !important;
          }
          main {
            max-width: 100% !important;
            padding: 0 !important;
            margin: 0 !important;
          }
          /* Prevent awkward page-breaks inside sections or blocks */
          pre, blockquote, figure, table, dl, .callout {
            page-break-inside: avoid;
            break-inside: avoid;
          }
          h1, h2, h3, h4, h5, h6 {
            page-break-after: avoid;
            break-after: avoid;
          }
          /* Ensure code fences and tables look outstanding in print */
          pre, code, table, th, td, .callout {
            border-color: #ddd !important;
            background-color: #fcfcfc !important;
            color: #111 !important;
          }
        }
    """
}

private extension Character {
    var isAbbreviationWordCharacter: Bool {
        isLetter || isNumber || self == "_"
    }
}
