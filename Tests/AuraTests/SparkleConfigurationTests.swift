import XCTest
@testable import Aura

final class SparkleConfigurationTests: XCTestCase {
    func testResolveSucceedsForPackagedBuildWithFeedAndPublicKey() throws {
        let result = SparkleConfiguration.resolve(
            infoDictionary: [
                "SUFeedURL": "https://westbrookdaniel.github.io/aura/appcast.xml",
                "SUPublicEDKey": "ABC123="
            ],
            bundleURL: URL(fileURLWithPath: "/Applications/Aura.app", isDirectory: true)
        )

        let configuration = try XCTUnwrap(try? result.get())
        XCTAssertEqual(configuration.feedURL.absoluteString, "https://westbrookdaniel.github.io/aura/appcast.xml")
        XCTAssertEqual(configuration.publicEDKey, "ABC123=")
    }

    func testResolveFailsOutsideAppBundle() {
        let result = SparkleConfiguration.resolve(
            infoDictionary: [
                "SUFeedURL": "https://westbrookdaniel.github.io/aura/appcast.xml",
                "SUPublicEDKey": "ABC123="
            ],
            bundleURL: URL(fileURLWithPath: "/tmp/Aura", isDirectory: true)
        )

        guard case .failure(let error) = result else {
            return XCTFail("Expected configuration lookup to fail")
        }

        XCTAssertEqual(error, .notPackagedApp)
    }

    func testResolveFailsWithoutPublicKey() {
        let result = SparkleConfiguration.resolve(
            infoDictionary: [
                "SUFeedURL": "https://westbrookdaniel.github.io/aura/appcast.xml"
            ],
            bundleURL: URL(fileURLWithPath: "/Applications/Aura.app", isDirectory: true)
        )

        guard case .failure(let error) = result else {
            return XCTFail("Expected configuration lookup to fail")
        }

        XCTAssertEqual(error, .missingPublicEDKey)
    }
}
