import Testing
@testable import WritingHubLib

@Suite("FrontMatter Tests")
struct FrontMatterTests {

    // MARK: - Test 1: Parse full frontmatter

    @Test("Parse frontmatter with all fields")
    func parseFrontMatter() throws {
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

        #expect(piece.frontMatter.title == "Why AI Will Eat Finance")
        #expect(piece.frontMatter.created == "2026-02-27")
        #expect(piece.frontMatter.edited == "2026-02-27")
        #expect(piece.frontMatter.version == 3)
        #expect(piece.frontMatter.platforms == ["substack", "x", "linkedin"])
        #expect(piece.body.contains("The main content here."))
    }

    // MARK: - Test 2: Serialize and round-trip

    @Test("Serialize frontmatter and round-trip")
    func serializeFrontMatter() throws {
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

        #expect(serialized.hasPrefix("---\n"))
        #expect(serialized.contains("title: Test Post"))
        #expect(serialized.contains("Some body text."))

        let reparsed = try WritingPiece.parse(from: serialized)
        #expect(reparsed.frontMatter.title == "Test Post")
        #expect(reparsed.frontMatter.version == 1)
    }

    // MARK: - Test 3: Parse markdown without frontmatter

    @Test("Parse markdown without frontmatter")
    func parseMarkdownWithoutFrontMatter() throws {
        let content = """
        # Just a plain markdown file

        No frontmatter here, just content.
        """

        let piece = try WritingPiece.parse(from: content)

        #expect(piece.frontMatter.title == nil)
        #expect(piece.frontMatter.version == nil)
        #expect(piece.body.contains("Just a plain markdown file"))
        #expect(piece.body.contains("No frontmatter here"))
    }

    // MARK: - Test 4: Parse platform sections

    @Test("Parse platform sections")
    func parsePlatformSections() throws {
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

        #expect(piece.platformSections.count == 2)
        #expect(piece.platformSections["X Thread"]?.contains("1/ First tweet.") == true)
        #expect(piece.platformSections["LinkedIn"]?.contains("Professional version here.") == true)
        #expect(!piece.body.contains("1/ First tweet."))
        #expect(!piece.body.contains("Professional version here."))
    }
}
