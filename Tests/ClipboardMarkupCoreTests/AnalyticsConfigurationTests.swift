@testable import ClipboardMarkupCore
import XCTest

final class AnalyticsConfigurationTests: XCTestCase {
    func testDecodesValidPlistAndExtractsNamespace() throws {
        let data = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>analyticsBaseUrl</key>
          <string>https://example.lambda-url.us-west-2.on.aws/clipboard-markup/</string>
          <key>analyticsKeyId</key>
          <string>clipboard-markup</string>
          <key>analyticsSecret</key>
          <string>secret</string>
          <key>audience</key>
          <string>test</string>
        </dict>
        </plist>
        """.data(using: .utf8)!

        let result = AnalyticsConfiguration.decode(data: data, appVersion: "1.2.3")

        guard case let .success(configuration) = result else {
            return XCTFail("Expected valid configuration")
        }
        XCTAssertEqual(configuration.namespace, "clipboard-markup")
        XCTAssertEqual(configuration.analyticsBaseURL.absoluteString, "https://example.lambda-url.us-west-2.on.aws/clipboard-markup")
        XCTAssertEqual(configuration.uploadURL.absoluteString, "https://example.lambda-url.us-west-2.on.aws/clipboard-markup/v1/events")
        XCTAssertEqual(configuration.appName, "clipboard-markup")
        XCTAssertEqual(configuration.appVersion, "1.2.3")
        XCTAssertEqual(configuration.appPlatform, "macOS")
        XCTAssertEqual(configuration.audience, .test)
    }

    func testRejectsInvalidNamespace() throws {
        let data = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>analyticsBaseUrl</key>
          <string>https://example.com/Clipboard Markup</string>
          <key>analyticsKeyId</key>
          <string>clipboard-markup</string>
          <key>analyticsSecret</key>
          <string>secret</string>
          <key>audience</key>
          <string>debug</string>
        </dict>
        </plist>
        """.data(using: .utf8)!

        let result = AnalyticsConfiguration.decode(data: data, appVersion: "1.2.3")

        guard case let .failure(error) = result else {
            return XCTFail("Expected invalid configuration")
        }
        XCTAssertTrue(error.localizedDescription.contains("Namespace"))
    }

    func testEnvironmentConfigurationLoads() throws {
        let environment = [
            "CLIPBOARD_MARKUP_ANALYTICS_BASE_URL": "https://example.com/clipboard-markup",
            "CLIPBOARD_MARKUP_ANALYTICS_KEY_ID": "clipboard-markup",
            "CLIPBOARD_MARKUP_ANALYTICS_SECRET": "secret",
            "CLIPBOARD_MARKUP_ANALYTICS_AUDIENCE": "beta"
        ]

        let result = AnalyticsConfiguration.loadEnvironment(environment, appVersion: "1.2.3")

        guard let result, case let .success(configuration) = result else {
            return XCTFail("Expected environment configuration")
        }
        XCTAssertEqual(configuration.audience, .beta)
        XCTAssertEqual(configuration.namespace, "clipboard-markup")
    }
}
