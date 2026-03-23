import XCTest
@testable import WritingHubLib

final class AppUpdateServiceTests: XCTestCase {
    func testVersionComparisonIgnoresLeadingV() {
        XCTAssertTrue(AppVersion("1.2.3") < AppVersion("v1.2.4"))
        XCTAssertEqual(AppVersion.normalized("v2.0.1"), "2.0.1")
    }

    func testVersionComparisonPadsMissingComponents() {
        XCTAssertEqual(AppVersion("1.2"), AppVersion("1.2.0"))
        XCTAssertTrue(AppVersion("1.2.9") < AppVersion("1.10"))
    }

    func testDisplayVersionUsesNormalizedTag() {
        let release = AppReleaseInfo(
            tagName: "v1.4.0",
            name: "Amplify 1.4.0",
            body: "Release notes",
            htmlURL: URL(string: "https://github.com/jihjihk/amplify/releases/tag/v1.4.0")!,
            publishedAt: nil,
            assets: []
        )

        XCTAssertEqual(release.displayVersion, "1.4.0")
    }
}
