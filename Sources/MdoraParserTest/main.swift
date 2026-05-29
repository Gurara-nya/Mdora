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

    let fencedSyntaxRanges = MarkdownSyntaxHighlightScanner.ranges(in: fencedHighlightMarkdown)
    let fencedSyntaxCodeSpans = fencedSyntaxRanges.codeSpanRanges.map {
        (fencedHighlightMarkdown as NSString).substring(with: $0)
    }
    assert(fencedSyntaxCodeSpans == ["`inline`", "`inline`"])

    let innerFenceRange = (fencedHighlightMarkdown as NSString).range(of: "`not inline`")
    let visibleFenceRanges = MarkdownCodeFenceScanner.fencedLineRanges(
        in: fencedHighlightMarkdown,
        intersecting: innerFenceRange
    )
    assert(visibleFenceRanges == fencedRanges)
    assert(fencedSyntaxRanges.inlineExcludedRanges.contains {
        NSIntersectionRange($0, innerFenceRange).length > 0
    })

    let bareFenceLineMarkdown = "```\n"
    let bareFenceSyntaxRanges = MarkdownSyntaxHighlightScanner.ranges(in: bareFenceLineMarkdown)
    assert(bareFenceSyntaxRanges.fencedLineRanges.count == 1)
    assert(bareFenceSyntaxRanges.codeSpanRanges.isEmpty)

    let bareSmartQuoteFenceMarkdown = "‘’‘"
    let bareSmartQuoteFenceSyntaxRanges = MarkdownSyntaxHighlightScanner.ranges(in: bareSmartQuoteFenceMarkdown)
    assert(bareSmartQuoteFenceSyntaxRanges.fencedLineRanges.count == 1)
    assert(bareSmartQuoteFenceSyntaxRanges.codeSpanRanges.isEmpty)

    let afterFenceRange = (fencedHighlightMarkdown as NSString).range(of: "After `inline`")
    assert(MarkdownCodeFenceScanner.fencedLineRanges(
        in: fencedHighlightMarkdown,
        intersecting: afterFenceRange
    ).isEmpty)

    let unclosedFenceMarkdown = "```text\n`still code`"
    let unclosedFenceRanges = MarkdownCodeFenceScanner.fencedLineRanges(in: unclosedFenceMarkdown)
    assert(unclosedFenceRanges.count == 1)
    assert((unclosedFenceMarkdown as NSString).substring(with: unclosedFenceRanges[0]) == unclosedFenceMarkdown)

    let smartQuoteFenceMarkdown = """
    ‘’‘text
    `not inline either`
    ’‘’
    After `inline`
    """
    let smartQuoteFenceDocument = MarkdownParser.parse(smartQuoteFenceMarkdown)
    guard case .codeBlock(let smartQuoteFenceLanguage, let smartQuoteFenceCode) = smartQuoteFenceDocument.blocks[0] else {
        fatalError("❌ Expected smart-quote fence markers to parse as a code block")
    }
    assert(smartQuoteFenceLanguage == "text")
    assert(smartQuoteFenceCode == "`not inline either`")
    let smartQuoteFenceRanges = MarkdownCodeFenceScanner.fencedLineRanges(in: smartQuoteFenceMarkdown)
    assert(smartQuoteFenceRanges.count == 1)
    let smartQuoteSyntaxRanges = MarkdownSyntaxHighlightScanner.ranges(in: smartQuoteFenceMarkdown)
    let smartQuoteSyntaxCodeSpans = smartQuoteSyntaxRanges.codeSpanRanges.map {
        (smartQuoteFenceMarkdown as NSString).substring(with: $0)
    }
    assert(smartQuoteSyntaxCodeSpans == ["`inline`"])
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

    let infoStringLanguageMarkdown = "```swift linenos start=3\nlet value = 1\n```"
    let infoStringLanguageDocument = MarkdownParser.parse(infoStringLanguageMarkdown)
    guard case .codeBlock(let infoStringLanguage, let infoStringCode) = infoStringLanguageDocument.blocks[0] else {
        fatalError("❌ Expected fenced code info string to parse as a code block")
    }
    assert(infoStringLanguage == "swift")
    assert(infoStringCode == "let value = 1")
    assert(infoStringLanguageDocument.markers.codeLanguages == ["swift"])
    let infoStringLanguageHTML = MarkdownHTMLRenderer.renderFragment(infoStringLanguageMarkdown)
    assert(infoStringLanguageHTML.contains(#"class="language-swift""#))
    assert(!infoStringLanguageHTML.contains("language-swift linenos"))

    let diagramInfoStringMarkdown = "```mermaid theme=dark\nflowchart LR\nA-->B\n```"
    let diagramInfoStringDocument = MarkdownParser.parse(diagramInfoStringMarkdown)
    guard case .diagram(let diagramInfoStringBlock) = diagramInfoStringDocument.blocks[0] else {
        fatalError("❌ Expected diagram fence to use first info-string word for kind detection")
    }
    assert(diagramInfoStringBlock.kind == .mermaid)
    assert(diagramInfoStringBlock.source == "flowchart LR\nA-->B")
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

    let editorCodeSpanMarkdown = """
    ```text
    fence content
    ```
    Use `` `literal` `` and `inline`, but leave ```open alone.
    ```
    """
    let editorCodeSpanRanges = MarkdownCodeSpanScanner.codeSpanRanges(in: editorCodeSpanMarkdown)
    let editorCodeSpanMatches = editorCodeSpanRanges.map {
        (editorCodeSpanMarkdown as NSString).substring(with: $0)
    }
    assert(editorCodeSpanMatches == ["`` `literal` ``", "`inline`"])

    let inlineContentRange = (editorCodeSpanMarkdown as NSString).range(of: "inline")
    let visibleCodeSpanMatches = MarkdownCodeSpanScanner.codeSpanRanges(
        in: editorCodeSpanMarkdown,
        intersecting: inlineContentRange
    ).map {
        (editorCodeSpanMarkdown as NSString).substring(with: $0)
    }
    assert(visibleCodeSpanMatches == ["`inline`"])

    let multilineEditorCodeSpanMarkdown = """
    Use `line
    break` and ``multi
    line`` spans.
    """
    let multilineEditorCodeSpanRanges = MarkdownCodeSpanScanner.codeSpanRanges(in: multilineEditorCodeSpanMarkdown)
    let multilineEditorCodeSpanMatches = multilineEditorCodeSpanRanges.map {
        (multilineEditorCodeSpanMarkdown as NSString).substring(with: $0)
    }
    assert(multilineEditorCodeSpanMatches == ["`line\nbreak`", "``multi\nline``"])

    let multilineWindowRange = (multilineEditorCodeSpanMarkdown as NSString).range(of: "line``")
    let multilineWindowMatches = MarkdownCodeSpanScanner.codeSpanRanges(
        in: multilineEditorCodeSpanMarkdown,
        intersecting: multilineWindowRange
    ).map {
        (multilineEditorCodeSpanMarkdown as NSString).substring(with: $0)
    }
    assert(multilineWindowMatches == ["``multi\nline``"])

    let syntaxHighlightMarkdown = """
    ```text
    **fenced bold**
    ```
    `**not bold**` and **bold outside**
    `**not
    bold either**`
    """
    let syntaxHighlightRanges = MarkdownSyntaxHighlightScanner.ranges(in: syntaxHighlightMarkdown)
    let syntaxHighlightCodeSpans = syntaxHighlightRanges.codeSpanRanges.map {
        (syntaxHighlightMarkdown as NSString).substring(with: $0)
    }
    assert(syntaxHighlightCodeSpans == ["`**not bold**`", "`**not\nbold either**`"])

    let syntaxHighlightNSString = syntaxHighlightMarkdown as NSString
    let fencedBoldRange = syntaxHighlightNSString.range(of: "**fenced bold**")
    let protectedBoldRange = syntaxHighlightNSString.range(of: "**not bold**")
    let multilineProtectedBoldRange = syntaxHighlightNSString.range(of: "bold either**")
    let outsideBoldRange = syntaxHighlightNSString.range(of: "**bold outside**")
    assert(syntaxHighlightRanges.inlineExcludedRanges.contains {
        NSIntersectionRange($0, fencedBoldRange).length > 0
    })
    assert(syntaxHighlightRanges.inlineExcludedRanges.contains {
        NSIntersectionRange($0, protectedBoldRange).length > 0
    })
    assert(syntaxHighlightRanges.inlineExcludedRanges.contains {
        NSIntersectionRange($0, multilineProtectedBoldRange).length > 0
    })
    assert(!syntaxHighlightRanges.inlineExcludedRanges.contains {
        NSIntersectionRange($0, outsideBoldRange).length > 0
    })

    let protectedBoldWindowRanges = MarkdownSyntaxHighlightScanner.ranges(
        in: syntaxHighlightMarkdown,
        intersecting: protectedBoldRange
    )
    assert(protectedBoldWindowRanges.codeSpanRanges.map {
        syntaxHighlightNSString.substring(with: $0)
    } == ["**not bold**"])
    assert(protectedBoldWindowRanges.inlineExcludedRanges.allSatisfy {
        NSIntersectionRange($0, protectedBoldRange) == $0
    })

    let multilineProtectedWindowRanges = MarkdownSyntaxHighlightScanner.ranges(
        in: syntaxHighlightMarkdown,
        intersecting: multilineProtectedBoldRange
    )
    assert(multilineProtectedWindowRanges.codeSpanRanges.map {
        syntaxHighlightNSString.substring(with: $0)
    } == ["bold either**"])
    print("✅ CommonMark code spans support multi-backtick delimiters, spacing, and HTML escaping!")

    let mathHighlightMarkdown = #"""
    Before **bold**
    $$
    a_1 + **not bold** + `not code`
    $$
    After **bold**
    \[
    [not a link](https://example.com) and `not code either`
    \]
    Tail `code`
    """#
    let mathHighlightNSString = mathHighlightMarkdown as NSString
    let mathBlockRanges = MarkdownMathBlockScanner.mathBlockLineRanges(in: mathHighlightMarkdown)
    assert(mathBlockRanges.count == 2)
    assert(mathHighlightNSString.substring(with: mathBlockRanges[0]) == "$$\na_1 + **not bold** + `not code`\n$$\n")
    assert(mathHighlightNSString.substring(with: mathBlockRanges[1]) == "\\[\n[not a link](https://example.com) and `not code either`\n\\]\n")

    let mathSyntaxRanges = MarkdownSyntaxHighlightScanner.ranges(in: mathHighlightMarkdown)
    let mathSyntaxCodeSpans = mathSyntaxRanges.codeSpanRanges.map {
        mathHighlightNSString.substring(with: $0)
    }
    assert(mathSyntaxCodeSpans == ["`code`"])

    let mathProtectedBoldRange = mathHighlightNSString.range(of: "**not bold**")
    let mathProtectedLinkRange = mathHighlightNSString.range(of: "[not a link](https://example.com)")
    let mathOutsideBoldRange = mathHighlightNSString.range(of: "**bold**")
    assert(mathSyntaxRanges.inlineExcludedRanges.contains {
        NSIntersectionRange($0, mathProtectedBoldRange).length > 0
    })
    assert(mathSyntaxRanges.inlineExcludedRanges.contains {
        NSIntersectionRange($0, mathProtectedLinkRange).length > 0
    })
    assert(!mathSyntaxRanges.inlineExcludedRanges.contains {
        NSIntersectionRange($0, mathOutsideBoldRange).length > 0
    })

    let mathWindowRange = mathHighlightNSString.range(of: "`not code either`")
    assert(MarkdownMathBlockScanner.mathBlockLineRanges(
        in: mathHighlightMarkdown,
        intersecting: mathWindowRange
    ).map { mathHighlightNSString.substring(with: $0) } == ["\\[\n[not a link](https://example.com) and `not code either`\n\\]\n"])
    let mathWindowSyntaxRanges = MarkdownSyntaxHighlightScanner.ranges(
        in: mathHighlightMarkdown,
        intersecting: mathWindowRange
    )
    assert(mathWindowSyntaxRanges.mathBlockRanges.map {
        mathHighlightNSString.substring(with: $0)
    } == ["`not code either`"])
    assert(mathWindowSyntaxRanges.inlineExcludedRanges.allSatisfy {
        NSIntersectionRange($0, mathWindowRange) == $0
    })

    let mathContainingFenceMarkdown = #"""
    $$
    ```swift
    let value = "**still math**"
    ```
    $$
    After `code`
    """#
    let mathContainingFenceRanges = MarkdownSyntaxHighlightScanner.ranges(in: mathContainingFenceMarkdown)
    assert(mathContainingFenceRanges.mathBlockRanges.count == 1)
    assert(mathContainingFenceRanges.fencedLineRanges.isEmpty)
    assert(mathContainingFenceRanges.codeSpanRanges.map {
        (mathContainingFenceMarkdown as NSString).substring(with: $0)
    } == ["`code`"])

    let fenceContainingMathMarkdown = #"""
    ```text
    $$
    **still code**
    $$
    ```
    After `code`
    """#
    let fenceContainingMathRanges = MarkdownSyntaxHighlightScanner.ranges(in: fenceContainingMathMarkdown)
    assert(fenceContainingMathRanges.fencedLineRanges.count == 1)
    assert(fenceContainingMathRanges.mathBlockRanges.isEmpty)
    assert(fenceContainingMathRanges.codeSpanRanges.map {
        (fenceContainingMathMarkdown as NSString).substring(with: $0)
    } == ["`code`"])
    let fenceContainingMathNSString = fenceContainingMathMarkdown as NSString
    let fenceWindowRange = fenceContainingMathNSString.range(of: "**still code**")
    let fenceWindowSyntaxRanges = MarkdownSyntaxHighlightScanner.ranges(
        in: fenceContainingMathMarkdown,
        intersecting: fenceWindowRange
    )
    assert(fenceWindowSyntaxRanges.fencedLineRanges.map {
        fenceContainingMathNSString.substring(with: $0)
    } == ["**still code**"])
    assert(fenceWindowSyntaxRanges.inlineExcludedRanges.allSatisfy {
        NSIntersectionRange($0, fenceWindowRange) == $0
    })
    print("✅ Editor syntax highlighting protects display math blocks from inline recoloring!")

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

    let escapedInlineDestinationMarkdown = #"[Escaped](https://example.com/a\)b "Title \"quoted\"") and ![Pic](assets/a\(b\).png "Pic \"title\"")"#
    let escapedInlineDestinationSegments = InlineMarkdownParser.parse(escapedInlineDestinationMarkdown)
    let escapedInlineLink = escapedInlineDestinationSegments.compactMap { segment -> String? in
        if case let .link(_, destination, title) = segment { return "\(destination)|\(title ?? "")" }
        return nil
    }
    let escapedInlineImage = escapedInlineDestinationSegments.compactMap { segment -> String? in
        if case let .image(_, source, title) = segment { return "\(source)|\(title ?? "")" }
        return nil
    }
    assert(escapedInlineLink == [#"https://example.com/a)b|Title "quoted""#])
    assert(escapedInlineImage == [#"assets/a(b).png|Pic "title""#])

    let escapedInlineDestinationHTML = MarkdownHTMLRenderer.renderFragment(escapedInlineDestinationMarkdown)
    assert(escapedInlineDestinationHTML.contains(#"<a href="https://example.com/a)b" title="Title &quot;quoted&quot;">Escaped</a>"#))
    assert(escapedInlineDestinationHTML.contains(#"<img src="assets/a(b).png" alt="Pic" title="Pic &quot;title&quot;">"#))
    print("✅ Inline link and image destinations unescape CommonMark backslash escapes!")

    let balancedAutoLinkMarkdown = "Visit https://example.com/a_(b), www.example.com/docs_(v2), and wrapped (https://example.com/plain). Email user@www.example.com. Code `https://example.com/not_(linked)`."
    let autoLinkSegments = InlineMarkdownParser.parse(balancedAutoLinkMarkdown).compactMap { segment -> String? in
        if case let .autoLink(url) = segment { return url }
        return nil
    }
    assert(autoLinkSegments == ["https://example.com/a_(b)", "www.example.com/docs_(v2)", "https://example.com/plain"])

    let autoLinkDocument = MarkdownParser.parse(balancedAutoLinkMarkdown)
    assert(autoLinkDocument.markers.autoLinks == ["https://example.com/a_(b)", "www.example.com/docs_(v2)", "https://example.com/plain"])

    let autoLinkScannerMarkdown = "Visit https://example.com/a_(b), www.example.com/docs_(v2), and wrapped (https://example.com/plain). Ignore user@www.example.com and www."
    let autoLinkScannerMatches = MarkdownAutoLinkScanner.autoLinks(in: autoLinkScannerMarkdown).map(\.url)
    assert(autoLinkScannerMatches == ["https://example.com/a_(b)", "www.example.com/docs_(v2)", "https://example.com/plain"])
    let autoLinkScannerNSString = autoLinkScannerMarkdown as NSString
    let autoLinkInteriorRange = autoLinkScannerNSString.range(of: "docs_(v2)")
    assert(MarkdownAutoLinkScanner.autoLinks(
        in: autoLinkScannerMarkdown,
        intersecting: autoLinkInteriorRange
    ).map(\.url) == ["www.example.com/docs_(v2)"])

    let balancedAutoLinkHTML = MarkdownHTMLRenderer.renderFragment(balancedAutoLinkMarkdown)
    assert(balancedAutoLinkHTML.contains(#"<a href="https://example.com/a_(b)">https://example.com/a_(b)</a>"#))
    assert(balancedAutoLinkHTML.contains(#"<a href="http://www.example.com/docs_(v2)">www.example.com/docs_(v2)</a>"#))
    assert(balancedAutoLinkHTML.contains(#"(<a href="https://example.com/plain">https://example.com/plain</a>)."#))
    assert(!balancedAutoLinkHTML.contains(#"<a href="https://example.com/not_(linked)">"#))
    print("✅ Raw and www URL autolinks keep balanced parentheses and trim surrounding punctuation!")

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

    let duplicateReferenceMarkdown = """
    [Use][Ref Label]
    ![Diagram][Ref Label]

    [ref   label]: https://example.com/first "First"
    [REF LABEL]: https://example.com/second "Second"
    """
    let duplicateReferenceDocument = MarkdownParser.parse(duplicateReferenceMarkdown)
    let duplicateReferenceDefinition = duplicateReferenceDocument.referenceDefinitions["ref label"]
    assert(duplicateReferenceDefinition?.destination == "https://example.com/first")
    assert(duplicateReferenceDefinition?.title == "First")
    assert(duplicateReferenceDocument.diagnostics.contains { $0.id == "duplicate-reference-ref label" })
    assert(!duplicateReferenceDocument.diagnostics.contains { $0.id == "missing-reference-ref label" })

    let duplicateReferenceHTML = MarkdownHTMLRenderer.renderFragment(duplicateReferenceMarkdown)
    assert(duplicateReferenceHTML.contains(#"<a href="https://example.com/first" title="First">Use</a>"#))
    assert(duplicateReferenceHTML.contains(#"<img src="https://example.com/first" alt="Diagram" title="First">"#))
    assert(!duplicateReferenceHTML.contains(#"https://example.com/second" title="Second">Use"#))
    print("✅ Reference definitions follow CommonMark first-wins behavior and flag duplicates!")

    let escapedReferenceLabelMarkdown = """
    [Escaped][a \\] label]

    [a \\] label]: https://example.com/escaped "Escaped"
    """
    let escapedReferenceLabelDocument = MarkdownParser.parse(escapedReferenceLabelMarkdown)
    let escapedReferenceLabelKey = LinkReferenceDefinition.normalizedLabel(#"a \] label"#)
    assert(escapedReferenceLabelDocument.referenceDefinitions[escapedReferenceLabelKey]?.destination == "https://example.com/escaped")
    assert(!escapedReferenceLabelDocument.diagnostics.contains { $0.id == "missing-reference-\(escapedReferenceLabelKey)" })

    let escapedReferenceLabelHTML = MarkdownHTMLRenderer.renderFragment(escapedReferenceLabelMarkdown)
    assert(escapedReferenceLabelHTML.contains(#"<a href="https://example.com/escaped" title="Escaped">Escaped</a>"#))

    let invalidReferenceLabelMarkdown = """
    [bad [label]: https://example.com/bad
    """
    let invalidReferenceLabelDocument = MarkdownParser.parse(invalidReferenceLabelMarkdown)
    assert(invalidReferenceLabelDocument.referenceDefinitions["bad [label"] == nil)
    guard case .paragraph("[bad [label]: https://example.com/bad") = invalidReferenceLabelDocument.blocks[0] else {
        fatalError("❌ Expected reference definitions with unescaped [ inside labels to stay paragraphs")
    }

    let overlongReferenceLabel = String(repeating: "a", count: 1_000)
    let overlongReferenceLabelDocument = MarkdownParser.parse("[\(overlongReferenceLabel)]: https://example.com/too-long")
    assert(overlongReferenceLabelDocument.referenceDefinitions[overlongReferenceLabel] == nil)
    print("✅ Reference definition labels honor escaped brackets and reject invalid labels!")

    let multilineReferenceTitleMarkdown = """
    [Use][multiline]

    [multiline]: https://example.com/resource
      "Title on next line"

    After the reference.
    """
    let multilineReferenceTitleDocument = MarkdownParser.parse(multilineReferenceTitleMarkdown)
    let multilineReferenceDefinition = multilineReferenceTitleDocument.referenceDefinitions["multiline"]
    assert(multilineReferenceDefinition?.destination == "https://example.com/resource")
    assert(multilineReferenceDefinition?.title == "Title on next line")
    assert(multilineReferenceTitleDocument.blocks.count == 3)
    guard case .linkReferenceDefinition(let multilineReferenceBlock) = multilineReferenceTitleDocument.blocks[1] else {
        fatalError("❌ Expected multiline reference title to stay attached to the reference definition")
    }
    assert(multilineReferenceBlock.title == "Title on next line")
    assert(multilineReferenceTitleDocument.sourceRange(forBlockIndex: 1)?.endLine == 4)

    let multilineReferenceTitleHTML = MarkdownHTMLRenderer.renderFragment(multilineReferenceTitleMarkdown)
    assert(multilineReferenceTitleHTML.contains(#"<a href="https://example.com/resource" title="Title on next line">Use</a>"#))
    assert(multilineReferenceTitleHTML.contains("<p>After the reference.</p>"))
    print("✅ Reference definitions accept CommonMark titles on the following line!")

    let multilineReferenceDestinationMarkdown = """
    [Use][next-destination]

    [next-destination]:
      https://example.com/next
      'Next line title'

    After the split destination.
    """
    let multilineReferenceDestinationDocument = MarkdownParser.parse(multilineReferenceDestinationMarkdown)
    let multilineReferenceDestinationDefinition = multilineReferenceDestinationDocument.referenceDefinitions["next-destination"]
    assert(multilineReferenceDestinationDefinition?.destination == "https://example.com/next")
    assert(multilineReferenceDestinationDefinition?.title == "Next line title")
    assert(multilineReferenceDestinationDocument.blocks.count == 3)
    assert(multilineReferenceDestinationDocument.sourceRange(forBlockIndex: 1)?.endLine == 5)

    let multilineReferenceDestinationHTML = MarkdownHTMLRenderer.renderFragment(multilineReferenceDestinationMarkdown)
    assert(multilineReferenceDestinationHTML.contains(#"<a href="https://example.com/next" title="Next line title">Use</a>"#))
    assert(multilineReferenceDestinationHTML.contains("<p>After the split destination.</p>"))
    print("✅ Reference definitions accept destinations on the following line!")

    let balancedReferenceDestinationMarkdown = """
    [Balanced][balanced-ref]
    [Broken][broken-ref]

    [balanced-ref]: https://example.com/a_(b) "Balanced"
    [broken-ref]: https://example.com/a_(b "Broken"
    """
    let balancedReferenceDestinationDocument = MarkdownParser.parse(balancedReferenceDestinationMarkdown)
    assert(balancedReferenceDestinationDocument.referenceDefinitions["balanced-ref"]?.destination == "https://example.com/a_(b)")
    assert(balancedReferenceDestinationDocument.referenceDefinitions["broken-ref"] == nil)
    assert(balancedReferenceDestinationDocument.diagnostics.contains { $0.id == "missing-reference-broken-ref" })

    let balancedReferenceDestinationHTML = MarkdownHTMLRenderer.renderFragment(balancedReferenceDestinationMarkdown)
    assert(balancedReferenceDestinationHTML.contains(#"<a href="https://example.com/a_(b)" title="Balanced">Balanced</a>"#))
    assert(balancedReferenceDestinationHTML.contains(##"<a href="#ref-broken-ref">Broken</a>"##))
    print("✅ Reference definition destinations require balanced unescaped parentheses!")

    let escapedReferenceDestinationMarkdown = #"""
    [Escaped][escaped-destination]

    [escaped-destination]: <https://example.com/a\>b> "Title \"quoted\""
    """#
    let escapedReferenceDestinationDocument = MarkdownParser.parse(escapedReferenceDestinationMarkdown)
    let escapedReferenceDestinationDefinition = escapedReferenceDestinationDocument.referenceDefinitions["escaped-destination"]
    assert(escapedReferenceDestinationDefinition?.destination == "https://example.com/a>b")
    assert(escapedReferenceDestinationDefinition?.title == #"Title "quoted""#)

    let escapedReferenceDestinationHTML = MarkdownHTMLRenderer.renderFragment(escapedReferenceDestinationMarkdown)
    assert(escapedReferenceDestinationHTML.contains(#"<a href="https://example.com/a&gt;b" title="Title &quot;quoted&quot;">Escaped</a>"#))
    print("✅ Reference definition destinations and titles unescape CommonMark backslash escapes!")

    let incompleteSplitReferenceMarkdown = """
    [dangling]:
    invalid title tail
    """
    let incompleteSplitReferenceDocument = MarkdownParser.parse(incompleteSplitReferenceMarkdown)
    assert(incompleteSplitReferenceDocument.referenceDefinitions["dangling"] == nil)
    assert(incompleteSplitReferenceDocument.blocks.count == 1)
    guard case .paragraph("[dangling]: invalid title tail") = incompleteSplitReferenceDocument.blocks[0] else {
        fatalError("❌ Expected incomplete split reference definitions to remain one paragraph")
    }
    print("✅ Incomplete split reference definitions do not split paragraphs!")

    let collapsedReferenceMarkdown = """
    [Known][] and ![Known][]
    [Missing][] and ![Chart][] plus `[Code][]`
    Shortcut [Known] and ![Known] stay resolved.
    Plain [brackets] and ![missing-shortcut] stay text.
    [[Wiki Page]] remains a wiki link.

    [known]: https://example.com/known
    """
    let collapsedReferenceDocument = MarkdownParser.parse(collapsedReferenceMarkdown)
    assert(collapsedReferenceDocument.diagnostics.contains { $0.id == "missing-reference-missing" })
    assert(collapsedReferenceDocument.diagnostics.contains { $0.id == "missing-reference-chart" })
    assert(!collapsedReferenceDocument.diagnostics.contains { $0.id == "missing-reference-known" })
    assert(!collapsedReferenceDocument.diagnostics.contains { $0.id == "missing-reference-code" })
    assert(!collapsedReferenceDocument.diagnostics.contains { $0.id == "missing-reference-brackets" })
    assert(!collapsedReferenceDocument.diagnostics.contains { $0.id == "missing-reference-missing-shortcut" })
    assert(collapsedReferenceDocument.markers.linkReferences.contains("Known"))
    assert(collapsedReferenceDocument.markers.wikiLinks.contains("Wiki Page"))

    let collapsedReferenceHTML = MarkdownHTMLRenderer.renderFragment(collapsedReferenceMarkdown)
    assert(collapsedReferenceHTML.contains(#"<a href="https://example.com/known">Known</a>"#))
    assert(collapsedReferenceHTML.contains(#"<img src="https://example.com/known" alt="Known">"#))
    assert(collapsedReferenceHTML.contains(##"<a href="#ref-Missing">Missing</a>"##))
    assert(collapsedReferenceHTML.contains(#"<span class="image-ref">Chart [Chart]</span>"#))
    assert(collapsedReferenceHTML.contains(#"Plain [brackets] and ![missing-shortcut] stay text."#))
    assert(collapsedReferenceHTML.contains(#"<span class="wikilink" data-target="Wiki Page" data-path="Wiki Page">Wiki Page</span>"#))
    print("✅ Collapsed and shortcut reference links/images resolve without false missing diagnostics!")

    let invalidReferenceTitleMarkdown = """
    [bad]: https://example.com "Title" trailing
    [Uses bad][bad]
    """
    let invalidReferenceTitleDocument = MarkdownParser.parse(invalidReferenceTitleMarkdown)
    assert(invalidReferenceTitleDocument.referenceDefinitions["bad"] == nil)
    guard case .paragraph(let invalidReferenceParagraph) = invalidReferenceTitleDocument.blocks[0] else {
        fatalError("❌ Expected invalid reference definition with trailing title text to stay a paragraph")
    }
    assert(invalidReferenceParagraph == #"[bad]: https://example.com "Title" trailing [Uses bad][bad]"#)
    assert(invalidReferenceTitleDocument.diagnostics.contains { $0.id == "missing-reference-bad" })

    let invalidReferenceTitleHTML = MarkdownHTMLRenderer.renderFragment(invalidReferenceTitleMarkdown)
    guard invalidReferenceTitleHTML.contains(##"<p>[bad]: <a href="https://example.com">https://example.com</a> &quot;Title&quot; trailing <a href="#ref-bad">Uses bad</a></p>"##) else {
        fatalError("❌ Invalid reference title HTML mismatch: \(invalidReferenceTitleHTML)")
    }
    print("✅ Invalid reference titles with trailing text remain paragraph content!")

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

    let thematicBreakMarkdown = """
    Before stars
    * * *
    After stars
    Before underscores
    ___
    After underscores

        ***
    """
    let thematicBreakDocument = MarkdownParser.parse(thematicBreakMarkdown)
    assert(thematicBreakDocument.blocks.count == 6)
    guard case .paragraph("Before stars") = thematicBreakDocument.blocks[0],
          case .thematicBreak = thematicBreakDocument.blocks[1],
          case .paragraph("After stars Before underscores") = thematicBreakDocument.blocks[2],
          case .thematicBreak = thematicBreakDocument.blocks[3],
          case .paragraph("After underscores") = thematicBreakDocument.blocks[4],
          case .codeBlock(nil, "***") = thematicBreakDocument.blocks[5] else {
        fatalError("❌ Expected thematic breaks to terminate paragraphs while four-space markers stay code")
    }
    let thematicBreakHTML = MarkdownHTMLRenderer.renderFragment(thematicBreakMarkdown)
    assert(thematicBreakHTML.components(separatedBy: "<hr>").count - 1 == 2)
    assert(thematicBreakHTML.contains("<code>***</code>"))
    print("✅ CommonMark thematic breaks terminate paragraphs without stealing indented code!")

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
    assert(parenthesizedOrderedItems.map(\.markerNumber) == [1, 2])

    let orderedStartMarkdown = """
    4. Fourth step
    5. Fifth step
    """
    let orderedStartDocument = MarkdownParser.parse(orderedStartMarkdown)
    guard case .orderedList(let orderedStartItems) = orderedStartDocument.blocks[0] else {
        fatalError("❌ Expected non-one ordered marker sample to parse as an ordered list")
    }
    assert(orderedStartItems.map(\.text) == ["Fourth step", "Fifth step"])
    assert(orderedStartItems.map(\.markerNumber) == [4, 5])
    assert(MarkdownHTMLRenderer.renderFragment(orderedStartMarkdown).contains(#"<ol start="4">"#))

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

    let continuedListMarkdown = """
    - First line
      continues lazily
    - Second line

    Paragraph outside
    """
    let continuedListDocument = MarkdownParser.parse(continuedListMarkdown)
    guard case .unorderedList(let continuedListItems) = continuedListDocument.blocks[0] else {
        fatalError("❌ Expected continued unordered list to parse as one list block")
    }
    assert(continuedListItems.map(\.text) == ["First line continues lazily", "Second line"])
    guard case .paragraph("Paragraph outside") = continuedListDocument.blocks[1] else {
        fatalError("❌ Expected paragraph after blank line to stay outside the list")
    }
    let continuedTaskMarkdown = """
    - [ ] Draft outline
      with more detail
    - [x] Done item
    """
    let continuedTaskDocument = MarkdownParser.parse(continuedTaskMarkdown)
    guard case .taskList(let continuedTaskItems) = continuedTaskDocument.blocks[0] else {
        fatalError("❌ Expected continued task list to stay a task list")
    }
    assert(continuedTaskItems.map(\.text) == ["Draft outline with more detail", "Done item"])
    assert(continuedTaskItems.map(\.state) == [.todo, .done])
    let continuedListHTML = MarkdownHTMLRenderer.renderFragment(continuedListMarkdown)
    assert(continuedListHTML.contains("<li>First line continues lazily</li>"))
    print("✅ CommonMark parenthesized ordered markers and lazy list continuations parse cleanly!")

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

    let lazyQuoteMarkdown = """
    > Lazy quote starts
    continues without marker
    > - quoted bullet

    Outside paragraph
    """
    let lazyQuoteDocument = MarkdownParser.parse(lazyQuoteMarkdown)
    guard case .blockquote(let lazyQuoteBlocks, nil) = lazyQuoteDocument.blocks[0] else {
        fatalError("❌ Expected lazy continuation sample to start with a blockquote")
    }
    guard case .paragraph("Lazy quote starts continues without marker") = lazyQuoteBlocks[0],
          case .unorderedList(let lazyQuoteItems) = lazyQuoteBlocks[1] else {
        fatalError("❌ Expected unmarked text to lazily continue the quoted paragraph")
    }
    assert(lazyQuoteItems.map(\.text) == ["quoted bullet"])
    guard case .paragraph("Outside paragraph") = lazyQuoteDocument.blocks[1] else {
        fatalError("❌ Expected paragraph after blank line to stay outside the blockquote")
    }
    let lazyQuoteHTML = MarkdownHTMLRenderer.renderFragment(lazyQuoteMarkdown)
    assert(lazyQuoteHTML.contains("<blockquote>"))
    assert(lazyQuoteHTML.contains("<p>Lazy quote starts continues without marker</p>"))
    print("✅ Recursive blockquote and lazy continuation parsing works perfectly!")

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

    let rawHTMLBlockMarkdown = """
    Intro before raw HTML
    <script type="application/json">
    {
      "ok": true,

      "items": [1, 2]
    }
    </script>
    After script.
    """
    let rawHTMLBlockDocument = MarkdownParser.parse(rawHTMLBlockMarkdown)
    guard case .paragraph("Intro before raw HTML") = rawHTMLBlockDocument.blocks[0],
          case .html(let rawHTMLBlockSource) = rawHTMLBlockDocument.blocks[1],
          case .paragraph("After script.") = rawHTMLBlockDocument.blocks[2] else {
        fatalError("❌ Expected raw HTML block to interrupt the paragraph and keep following text separate")
    }
    assert(rawHTMLBlockSource == """
    <script type="application/json">
    {
      "ok": true,

      "items": [1, 2]
    }
    </script>
    """)
    assert(rawHTMLBlockDocument.sourceRange(forBlockIndex: 1)?.startLine == 2)
    assert(rawHTMLBlockDocument.sourceRange(forBlockIndex: 1)?.endLine == 8)

    let nonInterruptingInlineHTMLMarkdown = """
    Intro
    <span>inline-ish</span>
    continues
    """
    let nonInterruptingInlineHTMLDocument = MarkdownParser.parse(nonInterruptingInlineHTMLMarkdown)
    guard case .paragraph(let nonInterruptingInlineHTMLParagraph) = nonInterruptingInlineHTMLDocument.blocks[0] else {
        fatalError("❌ Expected non-block inline HTML tag to stay in the paragraph")
    }
    assert(nonInterruptingInlineHTMLParagraph == "Intro <span>inline-ish</span> continues")

    let htmlBlockFragment = MarkdownHTMLRenderer.renderFragment(htmlBlockMarkdown)
    assert(htmlBlockFragment.contains("&lt;aside class=&quot;note&quot;&gt;\n&lt;strong&gt;Raw HTML&lt;/strong&gt;\n&lt;/aside&gt;"))
    let rawHTMLBlockFragment = MarkdownHTMLRenderer.renderFragment(rawHTMLBlockMarkdown)
    assert(rawHTMLBlockFragment.contains("&lt;script type=&quot;application/json&quot;&gt;\n{\n  &quot;ok&quot;: true,\n\n  &quot;items&quot;: [1, 2]\n}\n&lt;/script&gt;"))
    print("✅ HTML blocks preserve source lines, raw-text blanks, and angle autolinks stay inline!")

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
