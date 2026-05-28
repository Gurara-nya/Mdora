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

        // Heading
        if case let .heading(level, text, _) = document.blocks[0] {
            XCTAssertEqual(level, 1)
            XCTAssertEqual(text, "Heading 1")
        } else {
            XCTFail("First block should be a heading")
        }

        // Blockquote
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

            print("Successfully parsed real test.md, block count: \\(document.blocks.count)")

            // Let's print out block distribution
            for (index, block) in document.blocks.enumerated() {
                switch block {
                case let .heading(level, text, _):
                    print("Block \\(index): Heading L\\(level) -> \\(text)")
                case .paragraph(let text):
                    print("Block \\(index): Paragraph -> \\(text.prefix(60))...")
                case .blockquote(_, let callout):
                    print("Block \\(index): Blockquote (Callout: \\(String(describing: callout?.kind)))")
                case .mathBlock(let expr):
                    print("Block \\(index): MathBlock -> \\(expr.prefix(60))...")
                default:
                    break
                }
            }
        } catch {
            XCTFail("Failed to load test.md: \\(error)")
        }
    }
}
