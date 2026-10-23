import XCTest
@testable import Fueg0

final class DailyFireEngineTests: XCTestCase {
    func testDailyFireFeed() async {
        let report = await DailyFireChecks.run()
        XCTAssertTrue(
            report.failures.isEmpty,
            report.failures.joined(separator: "\n")
        )
    }
}
