import Foundation
import MdoraCore

func runTests() {
    print("🚀 Starting Markdown Parser Tests...")

    // 1. Test Block Math delimiters ($$, \[ \]) and spacing robustness
    let mathMarkdown = """
    $$\\frac{\\partial T}{\\partial t} = a_{l}$$

    \\[
    t_{T_c}
    \\]

    Some inline math: $T_c$ and \\(P_g\\).
    """

    let doc1 = MarkdownParser.parse(mathMarkdown)
    print("Parsed math blocks count: \(doc1.blocks.count)")

    // Assert first block is a math block (from $$)
    guard case .mathBlock(let expr1) = doc1.blocks[0] else {
        fatalError("❌ Expected block 0 to be a math block from $$")
    }
    assert(expr1 == "\\frac{\\partial T}{\\partial t} = a_{l}")
    print("✅ Math block 1 parsed correctly: \(expr1)")

    // Assert second block is a math block (from \[ \])
    guard case .mathBlock(let expr2) = doc1.blocks[1] else {
        fatalError("❌ Expected block 1 to be a math block from \\[ \\]")
    }
    assert(expr2 == "t_{T_c}")
    print("✅ Math block 2 parsed correctly: \(expr2)")

    // 2. Test Escape Interception & Inline Math \( ... \)
    let paragraphBlock = doc1.blocks[2]
    guard case .paragraph(let text) = paragraphBlock else {
        fatalError("❌ Expected block 2 to be a paragraph")
    }
    print("Paragraph raw text: \(text)")
    let inlineSegments = InlineMarkdownParser.parse(text)

    let inlineMathSegments = inlineSegments.compactMap { segment -> String? in
        if case .inlineMath(let val) = segment { return val }
        return nil
    }

    print("Parsed inline math count: \(inlineMathSegments.count) -> \(inlineMathSegments)")
    assert(inlineMathSegments.contains("T_c"))
    assert(inlineMathSegments.contains("P_g"))
    print("✅ Inline math parsed correctly!")

    // 3. Test CommonMark hard line breaks
    let hardBreakMarkdown = "Line one  \nLine two\\  \nLine three\nLine four"
    let hardBreakDocument = MarkdownParser.parse(hardBreakMarkdown)
    guard case .paragraph(let hardBreakParagraph) = hardBreakDocument.blocks[0] else {
        fatalError("❌ Expected hard break sample to parse as a paragraph")
    }
    assert(hardBreakParagraph == "Line one\nLine two\nLine three Line four")

    let hardBreakSegments = InlineMarkdownParser.parse(hardBreakParagraph)
    assert(hardBreakSegments.filter { $0 == .hardBreak }.count == 2)
    assert(MarkdownHTMLRenderer.renderFragment(hardBreakMarkdown).contains("<p>Line one<br>Line two<br>Line three Line four</p>"))
    print("✅ CommonMark hard line breaks survive parsing, preview tokens, and HTML export!")

    // 3b. Test fenced code ranges used by editor highlighting
    let fencedHighlightMarkdown = """
    Before `inline`
    ```text
    `not inline`
    ```
    After `inline`
    """
    let fencedRanges = MarkdownCodeFenceScanner.fencedLineRanges(in: fencedHighlightMarkdown)
    assert(fencedRanges.count == 1)
    assert((fencedHighlightMarkdown as NSString).substring(with: fencedRanges[0]) == "```text\n`not inline`\n```\n")

    let innerFenceRange = (fencedHighlightMarkdown as NSString).range(of: "`not inline`")
    let visibleFenceRanges = MarkdownCodeFenceScanner.fencedLineRanges(
        in: fencedHighlightMarkdown,
        intersecting: innerFenceRange
    )
    assert(visibleFenceRanges == fencedRanges)

    let afterFenceRange = (fencedHighlightMarkdown as NSString).range(of: "After `inline`")
    assert(MarkdownCodeFenceScanner.fencedLineRanges(
        in: fencedHighlightMarkdown,
        intersecting: afterFenceRange
    ).isEmpty)

    let unclosedFenceMarkdown = "```text\n`still code`"
    let unclosedFenceRanges = MarkdownCodeFenceScanner.fencedLineRanges(in: unclosedFenceMarkdown)
    assert(unclosedFenceRanges.count == 1)
    assert((unclosedFenceMarkdown as NSString).substring(with: unclosedFenceRanges[0]) == unclosedFenceMarkdown)
    print("✅ Editor syntax highlighting can skip fenced code ranges without coloring inner backticks!")

    // 3c. Test variable-length CommonMark code fences
    let indentedFenceMarkdown = "    ```text\n    not a fence\n    ```"
    let indentedFenceDocument = MarkdownParser.parse(indentedFenceMarkdown)
    guard case .codeBlock(let indentedFenceLanguage, let indentedFenceCode) = indentedFenceDocument.blocks[0] else {
        fatalError("❌ Expected four-space indented fence to parse as an indented code block")
    }
    assert(indentedFenceLanguage == nil)
    assert(indentedFenceCode == "```text\nnot a fence\n```")
    assert(MarkdownCodeFenceScanner.fencedLineRanges(in: indentedFenceMarkdown).isEmpty)
    assert(!indentedFenceDocument.diagnostics.contains { $0.id.hasPrefix("unclosed-code-fence") })

    let threeSpaceFenceMarkdown = "   ```text\ncode\n   ```"
    let threeSpaceFenceDocument = MarkdownParser.parse(threeSpaceFenceMarkdown)
    guard case .codeBlock(let threeSpaceFenceLanguage, let threeSpaceFenceCode) = threeSpaceFenceDocument.blocks[0] else {
        fatalError("❌ Expected three-space indented fence to parse as a fenced code block")
    }
    assert(threeSpaceFenceLanguage == "text")
    assert(threeSpaceFenceCode == "code")
    assert(MarkdownCodeFenceScanner.fencedLineRanges(in: threeSpaceFenceMarkdown).count == 1)

    let fourSpaceClosingFenceMarkdown = "```text\n    ```"
    let fourSpaceClosingFenceDocument = MarkdownParser.parse(fourSpaceClosingFenceMarkdown)
    guard case .codeBlock(let fourSpaceClosingLanguage, let fourSpaceClosingCode) = fourSpaceClosingFenceDocument.blocks[0] else {
        fatalError("❌ Expected four-space closing fence to remain code content")
    }
    assert(fourSpaceClosingLanguage == "text")
    assert(fourSpaceClosingCode == "    ```")
    assert(fourSpaceClosingFenceDocument.diagnostics.contains { $0.id == "unclosed-code-fence-1" })

    let indentedContentFenceMarkdown = """
      ```swift
      let x = 1
     let y = 2
        let z = 3
      ```
    """
    let indentedContentFenceDocument = MarkdownParser.parse(indentedContentFenceMarkdown)
    guard case .codeBlock(let indentedContentFenceLanguage, let indentedContentFenceCode) = indentedContentFenceDocument.blocks[0] else {
        fatalError("❌ Expected indented fenced code content to parse as a code block")
    }
    assert(indentedContentFenceLanguage == "swift")
    assert(indentedContentFenceCode == "let x = 1\nlet y = 2\n  let z = 3")
    assert(MarkdownCodeFenceScanner.delimiter(in: "  ```swift")?.leadingSpaces == 2)
    assert(MarkdownHTMLRenderer.renderFragment(indentedContentFenceMarkdown).contains("let x = 1\nlet y = 2\n  let z = 3"))

    let invalidBacktickInfoFenceMarkdown = "```swift`bad"
    let invalidBacktickInfoFenceDocument = MarkdownParser.parse(invalidBacktickInfoFenceMarkdown)
    guard case .paragraph("```swift`bad") = invalidBacktickInfoFenceDocument.blocks[0] else {
        fatalError("❌ Expected backtick fence info containing a backtick to stay paragraph text")
    }
    assert(MarkdownCodeFenceScanner.delimiter(in: invalidBacktickInfoFenceMarkdown) == nil)
    assert(MarkdownCodeFenceScanner.fencedLineRanges(in: invalidBacktickInfoFenceMarkdown).isEmpty)
    assert(!invalidBacktickInfoFenceDocument.diagnostics.contains { $0.id.hasPrefix("unclosed-code-fence") })

    let tildeInfoWithBacktickMarkdown = "~~~lang`ok\ncontent\n~~~"
    let tildeInfoWithBacktickDocument = MarkdownParser.parse(tildeInfoWithBacktickMarkdown)
    guard case .codeBlock(let tildeInfoLanguage, let tildeInfoCode) = tildeInfoWithBacktickDocument.blocks[0] else {
        fatalError("❌ Expected tilde fence info containing a backtick to stay a code block")
    }
    assert(tildeInfoLanguage == "lang`ok")
    assert(tildeInfoCode == "content")
    print("✅ CommonMark code fences honor indentation, content de-indentation, and info-string rules!")

    let variableFenceMarkdown = #"""
    ````swift
    ```text
    inner fence stays code
    ```
    ````
    """#
    let variableFenceDocument = MarkdownParser.parse(variableFenceMarkdown)
    guard case .codeBlock(let variableFenceLanguage, let variableFenceCode) = variableFenceDocument.blocks[0] else {
        fatalError("❌ Expected variable-length fence sample to parse as a code block")
    }
    assert(variableFenceLanguage == "swift")
    assert(variableFenceCode == "```text\ninner fence stays code\n```")
    assert(!variableFenceDocument.diagnostics.contains { $0.id.hasPrefix("unclosed-code-fence") })
    let variableFenceInnerRange = (variableFenceMarkdown as NSString).range(of: "inner fence stays code")
    assert(MarkdownCodeFenceScanner.fencedLineRanges(
        in: variableFenceMarkdown,
        intersecting: variableFenceInnerRange
    ).count == 1)

    let tildeFenceMarkdown = "~~~~mermaid\nflowchart LR\n~~~\n~~~~"
    let tildeFenceDocument = MarkdownParser.parse(tildeFenceMarkdown)
    guard case .diagram(let tildeDiagram) = tildeFenceDocument.blocks[0] else {
        fatalError("❌ Expected long tilde fence to parse as a diagram block")
    }
    assert(tildeDiagram.kind == .mermaid)
    assert(tildeDiagram.source == "flowchart LR\n~~~")

    let unclosedVariableFenceMarkdown = #"""
    ````swift
    print("outer fence is still open")
    ```
    """#
    let unclosedVariableFenceDocument = MarkdownParser.parse(unclosedVariableFenceMarkdown)
    assert(unclosedVariableFenceDocument.diagnostics.contains { diagnostic in
        diagnostic.id == "unclosed-code-fence-1" &&
            diagnostic.message.contains("```` fence")
    })
    print("✅ Variable-length CommonMark code fences and diagnostics do not close on shorter inner fences!")

    // 4. Test HTML entity references
    let entityMarkdown = "AT&amp;T &copy; &#169; &#x1F680; &notanentity;"
    let entitySegments = InlineMarkdownParser.parse(entityMarkdown)
    let entityPairs = entitySegments.compactMap { segment -> String? in
        if case let .htmlEntity(source, character) = segment {
            return "\(source)=\(character)"
        }
        return nil
    }
    assert(entityPairs == ["&amp;=&", "&copy;=©", "&#169;=©", "&#x1F680;=🚀"])

    let entityDocument = MarkdownParser.parse(entityMarkdown)
    assert(entityDocument.markers.htmlEntities == ["&amp;", "&copy;", "&#169;", "&#x1F680;"])
    assert(MarkdownHTMLRenderer.renderFragment(entityMarkdown).contains("<p>AT&amp;T © © 🚀 &amp;notanentity;</p>"))
    print("✅ HTML entity references decode for preview/export and remain inspectable!")

    // 4b. Test CommonMark code span delimiter runs
    let codeSpanMarkdown = "Use `` `literal` `` plus ``  padded  `` and `line\nbreak`."
    let codeSpanSegments = InlineMarkdownParser.parse(codeSpanMarkdown)
    let codeSpanValues = codeSpanSegments.compactMap { segment -> String? in
        if case let .code(value) = segment { return value }
        return nil
    }
    assert(codeSpanValues == ["`literal`", " padded ", "line break"])

    let codeSpanHTML = MarkdownHTMLRenderer.renderFragment("Use `` `<tag>` & value ``.")
    assert(codeSpanHTML.contains("<code>`&lt;tag&gt;` &amp; value</code>"))
    print("✅ CommonMark code spans support multi-backtick delimiters, spacing, and HTML escaping!")

    // 4c. Test balanced parentheses in inline link and image destinations
    let balancedDestinationMarkdown = #"[Wiki](https://example.com/a_(b)) and ![Chart](assets/chart_(1).png "Chart (1)")"#
    let balancedDestinationSegments = InlineMarkdownParser.parse(balancedDestinationMarkdown)
    let linkDestinations = balancedDestinationSegments.compactMap { segment -> String? in
        if case let .link(_, destination, _) = segment { return destination }
        return nil
    }
    let imageDestinations = balancedDestinationSegments.compactMap { segment -> String? in
        if case let .image(_, source, title) = segment { return "\(source)|\(title ?? "")" }
        return nil
    }
    assert(linkDestinations == ["https://example.com/a_(b)"])
    assert(imageDestinations == ["assets/chart_(1).png|Chart (1)"])

    let balancedDestinationHTML = MarkdownHTMLRenderer.renderFragment(balancedDestinationMarkdown)
    assert(balancedDestinationHTML.contains(#"<a href="https://example.com/a_(b)">Wiki</a>"#))
    assert(balancedDestinationHTML.contains(#"<img src="assets/chart_(1).png" alt="Chart" title="Chart (1)">"#))
    print("✅ Inline links and images keep balanced parentheses inside destinations and titles!")

    // 4d. Test nested brackets in inline link text and image alt text
    let nestedBracketMarkdown = "[A [nested] label](https://example.com) and ![Alt [v2]](image.png)"
    let nestedBracketSegments = InlineMarkdownParser.parse(nestedBracketMarkdown)
    let nestedLinkLabels = nestedBracketSegments.compactMap { segment -> String? in
        if case let .link(label, _, _) = segment { return label }
        return nil
    }
    let nestedImageAlts = nestedBracketSegments.compactMap { segment -> String? in
        if case let .image(alt, _, _) = segment { return alt }
        return nil
    }
    assert(nestedLinkLabels == ["A [nested] label"])
    assert(nestedImageAlts == ["Alt [v2]"])

    let nestedBracketHTML = MarkdownHTMLRenderer.renderFragment(nestedBracketMarkdown)
    assert(nestedBracketHTML.contains(#"<a href="https://example.com">A [nested] label</a>"#))
    assert(nestedBracketHTML.contains(#"<img src="image.png" alt="Alt [v2]">"#))
    print("✅ Inline links and images keep nested brackets inside labels and alt text!")

    // 5. Test generated heading anchor de-duplication
    let duplicateHeadingMarkdown = """
    # Repeat
    # Repeat
    # Repeat {#repeat}
    # Repeat
    """
    let duplicateHeadingDocument = MarkdownParser.parse(duplicateHeadingMarkdown)
    assert(duplicateHeadingDocument.outline.map(\.anchor) == ["repeat", "repeat-1", "repeat", "repeat-2"])
    assert(duplicateHeadingDocument.diagnostics.contains { $0.id == "duplicate-heading-repeat" })

    let duplicateHeadingHTML = MarkdownHTMLRenderer.renderFragment(duplicateHeadingMarkdown)
    assert(duplicateHeadingHTML.contains(#"<h1 id="repeat">Repeat</h1>"#))
    assert(duplicateHeadingHTML.contains(#"<h1 id="repeat-1">Repeat</h1>"#))
    assert(duplicateHeadingHTML.contains(#"<h1 id="repeat-2">Repeat</h1>"#))
    print("✅ Generated heading anchors are de-duplicated while explicit duplicate anchors stay diagnostic!")

    let headingCompatibilityMarkdown = """
    #
    ###
    Setext One
    =
    Setext Two {#setext-two}
    -
    # Closed Heading ###
    # Closed Custom {#closed-id} ###
    # ATX Wins
    ---

    #not a heading
    """
    let headingCompatibilityDocument = MarkdownParser.parse(headingCompatibilityMarkdown)
    let headingCompatibilityOutline = headingCompatibilityDocument.outline.map { "\($0.level):\($0.title):\($0.anchor)" }
    let expectedHeadingCompatibilityOutline = [
        "1::section",
        "3::section-1",
        "1:Setext One:setext-one",
        "2:Setext Two:setext-two",
        "1:Closed Heading:closed-heading",
        "1:Closed Custom:closed-id",
        "1:ATX Wins:atx-wins"
    ]
    guard headingCompatibilityOutline == expectedHeadingCompatibilityOutline else {
        fatalError("❌ Heading compatibility mismatch: \(headingCompatibilityOutline)")
    }
    guard case .paragraph("#not a heading") = headingCompatibilityDocument.blocks.last else {
        fatalError("❌ Expected #not a heading without a space to stay a paragraph")
    }
    let headingCompatibilityHTML = MarkdownHTMLRenderer.renderFragment(headingCompatibilityMarkdown)
    assert(headingCompatibilityHTML.contains(#"<h1 id="section"></h1>"#))
    assert(headingCompatibilityHTML.contains(#"<h3 id="section-1"></h3>"#))
    assert(headingCompatibilityHTML.contains(#"<h1 id="setext-one">Setext One</h1>"#))
    assert(headingCompatibilityHTML.contains(#"<h2 id="setext-two">Setext Two</h2>"#))
    assert(headingCompatibilityHTML.contains(#"<h1 id="closed-heading">Closed Heading</h1>"#))
    assert(headingCompatibilityHTML.contains(#"<h1 id="closed-id">Closed Custom</h1>"#))
    assert(headingCompatibilityHTML.contains(#"<h1 id="atx-wins">ATX Wins</h1>"#))
    assert(headingCompatibilityHTML.contains("<hr>"))
    print("✅ CommonMark empty ATX headings and single-character setext headings parse cleanly!")

    // 6. Test GFM table escaped pipes and code span pipes
    let escapedPipeTableMarkdown = """
    | Pattern | Meaning |
    | --- | --- |
    | a \\| b | Escaped pipe |
    | `x|y` | Code span pipe |
    | trailing \\| | No split before delimiter |
    | Tail | ends \\|
    """
    let escapedPipeTableDocument = MarkdownParser.parse(escapedPipeTableMarkdown)
    guard case .table(let escapedPipeTable) = escapedPipeTableDocument.blocks[0] else {
        fatalError("❌ Expected escaped pipe sample to parse as a table")
    }
    assert(escapedPipeTable.headers == ["Pattern", "Meaning"])
    assert(escapedPipeTable.rows == [
        ["a | b", "Escaped pipe"],
        ["`x|y`", "Code span pipe"],
        ["trailing |", "No split before delimiter"],
        ["Tail", "ends |"]
    ])

    let escapedPipeTableHTML = MarkdownHTMLRenderer.renderFragment(escapedPipeTableMarkdown)
    assert(escapedPipeTableHTML.contains("<td style=\"text-align: left\">a | b</td>"))
    assert(escapedPipeTableHTML.contains("<code>x|y</code>"))
    print("✅ GFM tables keep escaped pipes and code-span pipes inside their cells!")

    // 7. Test CommonMark parenthesized ordered list markers
    let parenthesizedOrderedMarkdown = """
    1) First step
    2) Second step
    """
    let parenthesizedOrderedDocument = MarkdownParser.parse(parenthesizedOrderedMarkdown)
    guard case .orderedList(let parenthesizedOrderedItems) = parenthesizedOrderedDocument.blocks[0] else {
        fatalError("❌ Expected parenthesized ordered marker sample to parse as an ordered list")
    }
    assert(parenthesizedOrderedItems.map(\.text) == ["First step", "Second step"])

    let parenthesizedTaskMarkdown = """
    1) [ ] Draft
    2) [x] Done
    """
    let parenthesizedTaskDocument = MarkdownParser.parse(parenthesizedTaskMarkdown)
    guard case .taskList(let parenthesizedTaskItems) = parenthesizedTaskDocument.blocks[0] else {
        fatalError("❌ Expected parenthesized task marker sample to parse as a task list")
    }
    assert(parenthesizedTaskItems.map(\.text) == ["Draft", "Done"])
    assert(parenthesizedTaskItems.map(\.state) == [.todo, .done])
    assert(MarkdownHTMLRenderer.renderFragment(parenthesizedOrderedMarkdown).contains("<ol>"))
    print("✅ CommonMark parenthesized ordered list markers parse for lists and task lists!")

    // 8. Test Recursive Blockquote / Callout Parsing
    let quoteMarkdown = """
    > [!IMPORTANT]
    > **结论 1**
    > * Sub list item 1
    > * Sub list item 2
    """

    let doc2 = MarkdownParser.parse(quoteMarkdown)
    guard case .blockquote(let blocks, let callout) = doc2.blocks[0] else {
        fatalError("❌ Expected block to be a blockquote")
    }

    assert(callout?.kind == .important)
    print("Blockquote callout: \(callout?.kind.rawValue ?? "nil")")
    print("Blockquote internal blocks count: \(blocks.count)")

    guard case .paragraph(let paraText) = blocks[0] else {
        fatalError("❌ Blockquote sub-block 0 should be a paragraph")
    }
    assert(paraText == "**结论 1**")

    guard case .unorderedList(let listItems) = blocks[1] else {
        fatalError("❌ Blockquote sub-block 1 should be a list")
    }
    assert(listItems.count == 2)
    assert(listItems[0].text == "Sub list item 1")
    print("✅ Recursive blockquote parsing works perfectly!")

    // 9. Test task source editing through source maps
    let taskMarkdown = """
    - [ ] Draft outline
    - [/] Review compatibility
      - [!] Keep performance sharp
    4. [x] Ship preview
    5) [?] Parenthesized follow-up
    """

    let taskDocument = MarkdownParser.parse(taskMarkdown)
    guard case .taskList(let taskItems) = taskDocument.blocks[0] else {
        fatalError("❌ Expected block 0 to be a task list")
    }
    assert(taskItems.count == 5)

    let updatedTasks = MarkdownTaskSourceEditor.updatingTaskState(
        in: taskMarkdown,
        document: taskDocument,
        blockIndex: 0,
        itemIndex: 1,
        to: .done
    )

    assert(updatedTasks?.contains("- [x] Review compatibility") == true)
    assert(updatedTasks?.contains("4. [x] Ship preview") == true)

    let updatedParenthesizedTask = MarkdownTaskSourceEditor.updatingTaskState(
        in: taskMarkdown,
        document: taskDocument,
        blockIndex: 0,
        itemIndex: 4,
        to: .done
    )
    assert(updatedParenthesizedTask?.contains("5) [x] Parenthesized follow-up") == true)
    print("✅ Task source editing updates the targeted Markdown marker!")

    // 10. Test smart typing continuations
    assert(MarkdownTypingContinuation.continuation(after: "- [/] Review compatibility") == "\n- [ ] ")
    assert(MarkdownTypingContinuation.continuation(after: "  7. [!] Keep performance sharp") == "\n  8. [ ] ")
    assert(MarkdownTypingContinuation.continuation(after: "  7) [!] Keep performance sharp") == "\n  8) [ ] ")
    assert(MarkdownTypingContinuation.continuation(after: "12) Parenthesized ordered item") == "\n13) ")
    assert(MarkdownTypingContinuation.continuation(after: "> quoted") == "\n> ")
    assert(MarkdownTypingContinuation.continuation(after: "> - quoted list item") == "\n> - ")
    assert(MarkdownTypingContinuation.continuation(after: "> - [/] quoted task item") == "\n> - [ ] ")
    assert(MarkdownTypingContinuation.continuation(after: "> 7) [!] quoted ordered task") == "\n> 8) [ ] ")
    assert(MarkdownTypingContinuation.continuation(after: "> > 3. nested quote ordered item") == "\n> > 4. ")
    assert(MarkdownTypingContinuation.continuation(after: "    indented") == "\n    ")
    print("✅ Smart typing continuation preserves task, quote, nested quote, ordered, and indentation context!")

    // 11. Test line indentation editing
    let lineEditMarkdown = "- [ ] One\n  - [ ] Two\nPlain"
    let indentEdit = MarkdownLineEditor.indentingLines(
        in: lineEditMarkdown,
        selectedRange: NSRange(location: 0, length: 17)
    )
    assert(indentEdit.updatedText == "  - [ ] One\n    - [ ] Two\nPlain")
    assert(indentEdit.selectedRange.location == 0)

    let outdentEdit = MarkdownLineEditor.outdentingLines(
        in: indentEdit.updatedText,
        selectedRange: indentEdit.selectedRange
    )
    assert(outdentEdit.updatedText == lineEditMarkdown)

    let cursorOutdent = MarkdownLineEditor.outdentingLines(
        in: "  Plain",
        selectedRange: NSRange(location: 4, length: 0)
    )
    assert(cursorOutdent.updatedText == "Plain")
    assert(cursorOutdent.selectedRange.location == 2)
    print("✅ Markdown line indentation and outdent editing preserves text and selection!")

    // 12. Test smart paste transformations
    assert(MarkdownPasteTransformer.markdownReplacement(pastedText: "https://example.com", selectedText: "Example") == "[Example](https://example.com)")
    assert(MarkdownPasteTransformer.markdownReplacement(pastedText: "https://example.com/image.png", selectedText: "Diagram") == "![Diagram](https://example.com/image.png)")
    assert(MarkdownPasteTransformer.markdownReplacement(pastedText: "https://example.com/image.png", selectedText: "") == "![](https://example.com/image.png)")
    assert(MarkdownPasteTransformer.markdownReplacement(pastedText: "https://example.com", selectedText: "") == nil)
    assert(MarkdownPasteTransformer.markdownReplacement(pastedText: "not a url", selectedText: "Text") == nil)
    let pasteDocumentURL = URL(fileURLWithPath: "/tmp/Mdora Notes/Current.md")
    assert(
        MarkdownPasteTransformer.markdownReplacement(
            fileURL: URL(fileURLWithPath: "/tmp/Mdora Notes/Assets/My Image.png"),
            selectedText: "Mockup",
            currentDocumentURL: pasteDocumentURL
        ) == "![Mockup](Assets/My%20Image.png)"
    )
    assert(
        MarkdownPasteTransformer.markdownReplacement(
            fileURL: URL(fileURLWithPath: "/tmp/Mdora Notes/Assets/My Image.png"),
            selectedText: "",
            currentDocumentURL: pasteDocumentURL
        ) == "![My Image](Assets/My%20Image.png)"
    )
    assert(
        MarkdownPasteTransformer.markdownReplacement(
            fileURL: URL(fileURLWithPath: "/tmp/Images/Chart (1).jpg"),
            selectedText: "Chart",
            currentDocumentURL: pasteDocumentURL
        ) == "![Chart](../Images/Chart%20%281%29.jpg)"
    )
    assert(
        MarkdownPasteTransformer.markdownReplacement(
            fileURL: URL(fileURLWithPath: "/tmp/Mdora Notes/readme.txt"),
            selectedText: "Readme",
            currentDocumentURL: pasteDocumentURL
        ) == nil
    )
    assert(
        MarkdownPasteTransformer.markdownReplacement(
            fileURLs: [
                URL(fileURLWithPath: "/tmp/Mdora Notes/Assets/One.png"),
                URL(fileURLWithPath: "/tmp/Mdora Notes/Assets/Two.jpg"),
                URL(fileURLWithPath: "/tmp/Mdora Notes/Assets/readme.txt")
            ],
            selectedText: "Ignored for multi-file drops",
            currentDocumentURL: pasteDocumentURL
        ) == "![One](Assets/One.png)\n![Two](Assets/Two.jpg)"
    )
    print("✅ Smart paste transforms URL clipboard text into Markdown links and images!")

    // 13. Test inline HTML recognition without stealing angle autolinks
    let inlineHTMLMarkdown = "Inline <span class=\"badge\">HTML</span>, <br />, and <https://example.com>."
    let inlineHTMLSegments = InlineMarkdownParser.parse(inlineHTMLMarkdown)
    let inlineHTMLTags = inlineHTMLSegments.compactMap { segment -> String? in
        if case .htmlInline(let value) = segment { return value }
        return nil
    }
    assert(inlineHTMLTags == ["<span class=\"badge\">", "</span>", "<br />"])
    assert(inlineHTMLSegments.contains(.autoLink("https://example.com")))

    let inlineHTMLDocument = MarkdownParser.parse(inlineHTMLMarkdown)
    assert(inlineHTMLDocument.markers.inlineHTML == inlineHTMLTags)
    let inlineHTMLFragment = MarkdownHTMLRenderer.renderFragment(inlineHTMLMarkdown)
    assert(inlineHTMLFragment.contains(#"<code class="html-inline">&lt;span class=&quot;badge&quot;&gt;</code>"#))
    assert(inlineHTMLFragment.contains(#"<a href="https://example.com">https://example.com</a>"#))
    print("✅ Inline HTML tags are recognized without breaking angle autolinks!")

    // 14. Test HTML block parsing without stealing angle autolinks
    let htmlBlockMarkdown = """
    <aside class="note">
    <strong>Raw HTML</strong>
    </aside>
    """
    let htmlBlockDocument = MarkdownParser.parse(htmlBlockMarkdown)
    guard case .html(let htmlBlockSource) = htmlBlockDocument.blocks[0] else {
        fatalError("❌ Expected multi-line HTML sample to parse as an HTML block")
    }
    assert(htmlBlockSource == "<aside class=\"note\">\n<strong>Raw HTML</strong>\n</aside>")

    let trailingHTMLDocument = MarkdownParser.parse("<hr>")
    guard case .html(let trailingHTMLSource) = trailingHTMLDocument.blocks[0] else {
        fatalError("❌ Expected trailing HTML line to parse as an HTML block")
    }
    assert(trailingHTMLSource == "<hr>")

    let angleAutolinkDocument = MarkdownParser.parse("<https://example.com>")
    guard case .paragraph(let angleAutolinkParagraph) = angleAutolinkDocument.blocks[0] else {
        fatalError("❌ Expected angle autolink to stay a paragraph, not an HTML block")
    }
    assert(angleAutolinkParagraph == "<https://example.com>")

    let htmlBlockFragment = MarkdownHTMLRenderer.renderFragment(htmlBlockMarkdown)
    assert(htmlBlockFragment.contains("&lt;aside class=&quot;note&quot;&gt;\n&lt;strong&gt;Raw HTML&lt;/strong&gt;\n&lt;/aside&gt;"))
    print("✅ HTML blocks preserve their own source lines and angle autolinks stay inline!")

    // 15. Test TODO-style marker recognition across Markdown prefixes
    let taskTokenMarkdown = """
    TODO: Root marker
    + FIXME: Plus marker
    1. BUG: Ordered dot marker
    2) HACK: Ordered paren marker
    - [ ] NOTE: Task checkbox marker
    3) [!] IMPORTANT: Ordered task marker
    <!-- QUESTION: Hidden comment marker -->
    """
    let taskTokenDocument = MarkdownParser.parse(taskTokenMarkdown)
    assert(taskTokenDocument.markers.taskTokens.map { "\($0.kind.title): \($0.text)" } == [
        "TODO: Root marker",
        "FIXME: Plus marker",
        "BUG: Ordered dot marker",
        "HACK: Ordered paren marker",
        "NOTE: Task checkbox marker",
        "IMPORTANT: Ordered task marker",
        "QUESTION: Hidden comment marker"
    ])
    print("✅ TODO-style markers are recognized in plain, list, task, ordered, and comment lines!")

    // 16. Test internal preview link navigation targets
    let navigationMarkdown = """
    # Intro

    Tagged #perf and @yeqi with a footnote.[^nav]

    ## Deep Dive

    Anchor target paragraph ^block-target

    [^nav]: Navigation note
    """

    let navigationDocument = MarkdownParser.parse(navigationMarkdown)
    assert(MarkdownInternalLinkResolver.indexForWikiTarget("#Deep Dive", in: navigationDocument.blocks) == 2)
    assert(MarkdownInternalLinkResolver.indexForWikiTarget("^block-target", in: navigationDocument.blocks) == 3)
    assert(MarkdownInternalLinkResolver.indexForFootnote("nav", in: navigationDocument.blocks) == 4)
    assert(MarkdownInternalLinkResolver.indexForTag("perf", in: navigationDocument.blocks) == 1)
    assert(MarkdownInternalLinkResolver.indexForMention("yeqi", in: navigationDocument.blocks) == 1)
    assert(navigationDocument.blockIndex(containingLine: 1) == 0)
    assert(navigationDocument.blockIndex(containingLine: 3) == 1)
    assert(navigationDocument.blockIndex(containingLine: 5) == 2)
    assert(navigationDocument.blockIndex(containingLine: 7) == 3)
    assert(navigationDocument.blockIndex(containingLine: 9) == 4)
    assert(navigationDocument.blockIndex(containingLine: 2) == nil)
    assert(navigationDocument.sourceRange(forBlockIndex: 3)?.startLine == 7)
    print("✅ Internal preview navigation resolves wiki links, block ids, footnotes, tags, and mentions!")

    // 17. Test cross-file wiki link resolution
    do {
        let workspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mdora-wiki-resolution-\(UUID().uuidString)", isDirectory: true)
        let notesURL = workspaceURL.appendingPathComponent("Notes", isDirectory: true)
        let currentURL = workspaceURL.appendingPathComponent("Current.md")
        let targetURL = notesURL.appendingPathComponent("Other.md")
        let spacedTargetURL = workspaceURL.appendingPathComponent("Daily Note.md")

        try FileManager.default.createDirectory(at: notesURL, withIntermediateDirectories: true)
        try "# Current\n".write(to: currentURL, atomically: true, encoding: .utf8)
        try "# Other\n".write(to: targetURL, atomically: true, encoding: .utf8)
        try "# Daily\n".write(to: spacedTargetURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: workspaceURL) }

        assert(MarkdownInternalLinkResolver.fileURLForWikiTarget("Notes/Other#Details", currentDocumentURL: currentURL) == targetURL.standardizedFileURL)
        assert(MarkdownInternalLinkResolver.fileURLForWikiTarget("Daily Note", currentDocumentURL: currentURL) == spacedTargetURL.standardizedFileURL)
        assert(MarkdownInternalLinkResolver.fileURLForWikiTarget("Current#Intro", currentDocumentURL: currentURL) == nil)
        assert(MarkdownInternalLinkResolver.fileURLForWikiTarget("Missing", currentDocumentURL: currentURL) == nil)
        print("✅ Cross-file wiki links resolve neighboring Markdown files!")
    } catch {
        fatalError("❌ Failed cross-file wiki link test setup: \(error)")
    }

    // 10. Load & parse real test.md
    let currentDir = FileManager.default.currentDirectoryPath
    let filePath = currentDir + "/test.md"

    do {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        let document = MarkdownParser.parse(content)
        print("✅ Parsed real test.md! Total blocks: \(document.blocks.count)")

        print("🔍 Diagnostics count: \(document.diagnostics.count)")
        for diag in document.diagnostics {
            print("⚠️ Diagnostic: [\(diag.severity.title)] \(diag.title) - \(diag.message) (Line \(diag.line ?? 0))")
        }

        var mathCount = 0
        var calloutCount = 0

        for block in document.blocks {
            if case .mathBlock = block {
                mathCount += 1
            } else if case .blockquote(_, let callout) = block, callout != nil {
                calloutCount += 1
            }
        }

        print("📊 Real file stats - Math Blocks: \(mathCount), Callouts: \(calloutCount)")
    } catch {
        fatalError("❌ Failed to read test.md: \(error)")
    }

    print("🎉 All Markdown Parser Tests Passed Successfully!")
}

runTests()
