import Foundation
import Testing
@testable import Mindbox

@Suite("InApp WebView HTTP error predicate", .tags(.webView))
struct InAppWebViewHTTPErrorTests {

    @Test
    func scriptURLsMatch() {
        #expect(InAppWebViewHTTPError.isScriptResourceURL("https://api.example.com/scripts/v1/tracker.js"))
        #expect(InAppWebViewHTTPError.isScriptResourceURL("https://api.example.com/scripts/v1/tracker.js?v=1.0.31"))
        #expect(InAppWebViewHTTPError.isScriptResourceURL("https://web-static.mindbox.ru/js/byendpoint/x.webview.js?_=5949609"))
        #expect(InAppWebViewHTTPError.isScriptResourceURL("https://cdn.test/main.js#fragment"))
        #expect(InAppWebViewHTTPError.isScriptResourceURL("https://cdn.test/MAIN.JS"))
        #expect(InAppWebViewHTTPError.isScriptResourceURL("  https://cdn.test/padded.js  "))
    }

    @Test
    func nonScriptURLsDoNotMatch() {
        #expect(!InAppWebViewHTTPError.isScriptResourceURL(nil))
        #expect(!InAppWebViewHTTPError.isScriptResourceURL(""))
        #expect(!InAppWebViewHTTPError.isScriptResourceURL("   "))
        #expect(!InAppWebViewHTTPError.isScriptResourceURL("https://cdn.test/banner.png"))
        #expect(!InAppWebViewHTTPError.isScriptResourceURL("https://fonts.googleapis.com/css2?family=Inter"))
        #expect(!InAppWebViewHTTPError.isScriptResourceURL("https://stats.test/client-stats?pg=1"))
        // ".js" only in the query/fragment, not in the path
        #expect(!InAppWebViewHTTPError.isScriptResourceURL("https://cdn.test/page?file=tracker.js"))
        #expect(!InAppWebViewHTTPError.isScriptResourceURL("https://cdn.test/page#tracker.js"))
        // path merely containing ".js" without ending on it
        #expect(!InAppWebViewHTTPError.isScriptResourceURL("https://cdn.test/tracker.json"))
    }

    @Test
    func recoverableRequiresErrorStatusAndScript() {
        #expect(InAppWebViewHTTPError.isRecoverable(url: "https://api.example.com/scripts/v1/tracker.js", status: 404))
        #expect(InAppWebViewHTTPError.isRecoverable(url: "https://cdn.test/main.js", status: 500))
        // Boundary: exactly minErrorStatus.
        #expect(InAppWebViewHTTPError.isRecoverable(url: "https://cdn.test/main.js", status: InAppWebViewHTTPError.minErrorStatus))
    }

    @Test
    func nonRecoverableCases() {
        // Success / redirect are not errors.
        #expect(!InAppWebViewHTTPError.isRecoverable(url: "https://cdn.test/main.js", status: 200))
        #expect(!InAppWebViewHTTPError.isRecoverable(url: "https://cdn.test/main.js", status: 302))
        // Error status but not a script resource.
        #expect(!InAppWebViewHTTPError.isRecoverable(url: "https://cdn.test/banner.png", status: 404))
    }

    @Test
    func nilStatusSoftensToScriptCheck() {
        #expect(InAppWebViewHTTPError.isRecoverable(url: "https://cdn.test/main.js", status: nil))
        #expect(!InAppWebViewHTTPError.isRecoverable(url: "https://cdn.test/banner.png", status: nil))
        #expect(!InAppWebViewHTTPError.isRecoverable(url: nil, status: nil))
    }

    @Test
    func statusDescriptionNamesTheStatusOrThePlatformGap() {
        #expect(InAppWebViewHTTPError.statusDescription(404) == "HTTP 404")
        #expect(InAppWebViewHTTPError.statusDescription(nil) == "load failure (no HTTP status on WebKit)")
    }

    @Test
    func parsesDetectionScriptMessage() throws {
        let parsed = try #require(InAppWebViewHTTPError.message(from: [
            "type": "httpError",
            "url": "https://cdn.test/main.js",
            "status": NSNumber(value: 404)
        ] as [String: Any]))
        #expect(parsed.url == "https://cdn.test/main.js")
        #expect(parsed.status == 404)
    }

    @Test
    func parsesNullStatusAsNil() throws {
        // The fallback error-listener posts `status: null`, which crosses the bridge as NSNull.
        let parsed = try #require(InAppWebViewHTTPError.message(from: [
            "type": "httpError",
            "url": "https://cdn.test/main.js",
            "status": NSNull()
        ] as [String: Any]))
        #expect(parsed.url == "https://cdn.test/main.js")
        #expect(parsed.status == nil)
    }

    @Test
    func rejectsForeignMessages() {
        #expect(InAppWebViewHTTPError.message(from: ["type": "somethingElse", "url": "x"] as [String: Any]) == nil)
        #expect(InAppWebViewHTTPError.message(from: "not a dictionary") == nil)
        #expect(InAppWebViewHTTPError.message(from: ["url": "x"] as [String: Any]) == nil)
    }
}
