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

    // 3. Test Recursive Blockquote / Callout Parsing
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

    // 4. Test task source editing through source maps
    let taskMarkdown = """
    - [ ] Draft outline
    - [/] Review compatibility
      - [!] Keep performance sharp
    4. [x] Ship preview
    """

    let taskDocument = MarkdownParser.parse(taskMarkdown)
    guard case .taskList(let taskItems) = taskDocument.blocks[0] else {
        fatalError("❌ Expected block 0 to be a task list")
    }
    assert(taskItems.count == 4)

    let updatedTasks = MarkdownTaskSourceEditor.updatingTaskState(
        in: taskMarkdown,
        document: taskDocument,
        blockIndex: 0,
        itemIndex: 1,
        to: .done
    )

    assert(updatedTasks?.contains("- [x] Review compatibility") == true)
    assert(updatedTasks?.contains("4. [x] Ship preview") == true)
    print("✅ Task source editing updates the targeted Markdown marker!")

    // 5. Test internal preview link navigation targets
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

    // 6. Test cross-file wiki link resolution
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

    // 7. Load & parse real test.md
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
