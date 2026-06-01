import XCTest
@testable import MdoraCore

final class MdoraCoreTests: XCTestCase {
    func testMarkdownParsing() {
        let markdown = """
        # Heading 1

        > [!IMPORTANT]
        > **結論 1**
        > * Sub list item

        $$\\frac{\\partial T}{\\partial t} = a_{l}$$

        \\[
        t_{T_c}
        \\]

        Some inline math: $T_c$ and \\(P_g\\).
        """

        let document = MarkdownParser.parse(markdown)
        XCTAssertEqual(document.blocks.count, 5)

        if case let .heading(level, text, _, _) = document.blocks[0] {
            XCTAssertEqual(level, 1)
            XCTAssertEqual(text, "Heading 1")
        } else {
            XCTFail("First block should be a heading")
        }

        if case let .blockquote(blocks, callout) = document.blocks[1] {
            XCTAssertEqual(callout?.kind, .important)
            XCTAssertEqual(blocks.count, 2)
            if case let .paragraph(text) = blocks[0] {
                XCTAssertEqual(text, "**結論 1**")
            } else {
                XCTFail("Blockquote sub-block 0 should be a paragraph")
            }
            if case .unorderedList = blocks[1] {
                // Success
            } else {
                XCTFail("Blockquote sub-block 1 should be a list")
            }
        } else {
            XCTFail("Second block should be a blockquote")
        }
    }

    func testLoadRealMarkdownFile() {
        let currentDir = FileManager.default.currentDirectoryPath
        let filePath = currentDir + "/test.md"

        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let document = MarkdownParser.parse(content)
            XCTAssertFalse(document.blocks.isEmpty)
        } catch {
            XCTFail("Failed to load test.md: \\(error)")
        }
    }

    func testTaskTokensSkipNonWritingBlocks() {
        let markdown = """
        Intro line
        TODO: Same paragraph second line marker

        TODO: Root marker
        - [ ] NOTE: Task checkbox marker

        ```text
        FIXME: Ignore code task
        ```

        $$
        BUG: Ignore math task
        $$

        > IMPORTANT: Quoted marker
        > - QUESTION: Quoted list marker
        <!-- HACK: Hidden comment marker -->
        """

        let document = MarkdownParser.parse(markdown)

        XCTAssertEqual(document.sourceMap.first?.startLine, 1)
        XCTAssertEqual(document.sourceMap.first?.endLine, 2)
        XCTAssertEqual(document.blockIndex(containingLine: 2), 0)

        XCTAssertEqual(
            document.markers.taskTokens.map { "\($0.kind.title): \($0.text)" },
            [
                "TODO: Same paragraph second line marker",
                "TODO: Root marker",
                "NOTE: Task checkbox marker",
                "IMPORTANT: Quoted marker",
                "QUESTION: Quoted list marker",
                "HACK: Hidden comment marker"
            ]
        )
    }
}
