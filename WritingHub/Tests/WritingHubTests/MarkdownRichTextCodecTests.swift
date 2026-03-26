import XCTest
@testable import WritingHubLib

final class MarkdownRichTextCodecTests: XCTestCase {
    func testEnvelopePreservesProtectedSuffix() {
        let original = """
        ---
        title: Test
        edited: 2026-03-26
        ---

        # Heading

        Body text.

        ## Platform Versions

        ## LinkedIn

        Professional variant.
        """

        let envelope = MarkdownDocumentEnvelope.parse(from: original)
        let rebuilt = envelope.rebuild(withBodyMarkdown: "# Updated\n\nNew body.")

        XCTAssertTrue(rebuilt.contains("title: Test"))
        XCTAssertTrue(rebuilt.contains("## Platform Versions"))
        XCTAssertTrue(rebuilt.contains("Professional variant."))
        XCTAssertTrue(rebuilt.contains("# Updated"))
        XCTAssertFalse(rebuilt.contains("Body text."))
    }

    func testMarkdownHtmlRoundTripSupportsCommonFormatting() {
        let markdown = """
        # Title

        Paragraph with **bold**, *italic*, `code`, and [link](https://example.com).

        - One
        - Two
        """

        let html = MarkdownRichTextCodec.html(fromMarkdown: markdown)
        let roundTripped = MarkdownRichTextCodec.markdown(fromHTML: html)

        XCTAssertTrue(roundTripped.contains("# Title"))
        XCTAssertTrue(roundTripped.contains("**bold**"))
        XCTAssertTrue(roundTripped.contains("*italic*"))
        XCTAssertTrue(roundTripped.contains("`code`"))
        XCTAssertTrue(roundTripped.contains("[link](https://example.com)"))
        XCTAssertTrue(roundTripped.contains("- One"))
        XCTAssertTrue(roundTripped.contains("- Two"))
    }
}
