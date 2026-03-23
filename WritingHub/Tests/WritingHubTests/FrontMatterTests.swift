import XCTest
@testable import WritingHubLib

final class FrontMatterTests: XCTestCase {
    func testParseFrontMatter() throws {
        let content = """
        ---
        title: Why AI Will Eat Finance
        created: 2026-02-27
        edited: 2026-02-27
        version: 3
        platforms: [substack, x, linkedin]
        ---

        # Why AI Will Eat Finance

        The main content here.
        """

        let piece = try WritingPiece.parse(from: content)

        XCTAssertEqual(piece.frontMatter.title, "Why AI Will Eat Finance")
        XCTAssertEqual(piece.frontMatter.created, "2026-02-27")
        XCTAssertEqual(piece.frontMatter.edited, "2026-02-27")
        XCTAssertEqual(piece.frontMatter.version, 3)
        XCTAssertEqual(piece.frontMatter.platforms, ["substack", "x", "linkedin"])
        XCTAssertTrue(piece.body.contains("The main content here."))
    }

    func testSerializeFrontMatterRoundTrip() throws {
        let content = """
        ---
        title: Test Post
        created: 2026-02-27
        edited: 2026-02-27
        version: 1
        platforms: [x]
        ---

        Some body text.
        """

        let piece = try WritingPiece.parse(from: content)
        let serialized = piece.serialize()

        XCTAssertTrue(serialized.hasPrefix("---\n"))
        XCTAssertTrue(serialized.contains("title: Test Post"))
        XCTAssertTrue(serialized.contains("Some body text."))

        let reparsed = try WritingPiece.parse(from: serialized)
        XCTAssertEqual(reparsed.frontMatter.title, "Test Post")
        XCTAssertEqual(reparsed.frontMatter.version, 1)
    }

    func testParseMarkdownWithoutFrontMatter() throws {
        let content = """
        # Just a plain markdown file

        No frontmatter here, just content.
        """

        let piece = try WritingPiece.parse(from: content)

        XCTAssertNil(piece.frontMatter.title)
        XCTAssertNil(piece.frontMatter.version)
        XCTAssertTrue(piece.body.contains("Just a plain markdown file"))
        XCTAssertTrue(piece.body.contains("No frontmatter here"))
    }

    func testParsePlatformSections() throws {
        let content = """
        ---
        title: Why AI Will Eat Finance
        created: 2026-02-27
        edited: 2026-02-27
        version: 3
        platforms: [substack, x, linkedin]
        ---

        # Why AI Will Eat Finance

        The main content...

        ## Platform Versions

        ## X Thread

        1/ First tweet.

        ---

        ## LinkedIn

        Professional version here.
        """

        let piece = try WritingPiece.parse(from: content)

        XCTAssertEqual(piece.platformSections.count, 2)
        XCTAssertTrue(piece.platformSections["X Thread"]?.contains("1/ First tweet.") == true)
        XCTAssertTrue(piece.platformSections["LinkedIn"]?.contains("Professional version here.") == true)
        XCTAssertFalse(piece.body.contains("1/ First tweet."))
        XCTAssertFalse(piece.body.contains("Professional version here."))
    }
}
