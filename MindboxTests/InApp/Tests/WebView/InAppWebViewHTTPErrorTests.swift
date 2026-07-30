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
    func recoverableMeansAFailedScript() {
        #expect(InAppWebViewHTTPError.isRecoverable(url: "https://cdn.test/main.js"))
        #expect(!InAppWebViewHTTPError.isRecoverable(url: "https://cdn.test/banner.png"))
        #expect(!InAppWebViewHTTPError.isRecoverable(url: nil))
    }

    @Test
    func parsesDetectionScriptMessage() {
        let url = InAppWebViewHTTPError.failedResourceURL(from: [
            "type": "httpError",
            "url": "https://cdn.test/main.js"
        ] as [String: Any])
        #expect(url == "https://cdn.test/main.js")
    }

    @Test
    func rejectsForeignMessages() {
        #expect(InAppWebViewHTTPError.failedResourceURL(from: ["type": "somethingElse", "url": "x"] as [String: Any]) == nil)
        #expect(InAppWebViewHTTPError.failedResourceURL(from: "not a dictionary") == nil)
        #expect(InAppWebViewHTTPError.failedResourceURL(from: ["url": "x"] as [String: Any]) == nil)
        // An httpError message without a usable URL is dropped at the parsing layer.
        #expect(InAppWebViewHTTPError.failedResourceURL(from: ["type": "httpError"] as [String: Any]) == nil)
        #expect(InAppWebViewHTTPError.failedResourceURL(from: ["type": "httpError", "url": NSNull()] as [String: Any]) == nil)
    }
}
