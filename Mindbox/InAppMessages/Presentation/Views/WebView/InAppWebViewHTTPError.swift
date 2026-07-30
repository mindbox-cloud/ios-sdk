import Foundation

enum InAppWebViewHTTPError {

    static let loadFailureDescription = "load failure (no HTTP status on WebKit)"

    static func isScriptResourceURL(_ url: String?) -> Bool {
        let raw = url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return false }
        let beforeFragment = raw.components(separatedBy: "#")[0]
        let path = beforeFragment.components(separatedBy: "?")[0]
        return path.lowercased().hasSuffix(".js")
    }

    static func isRecoverable(url: String?) -> Bool {
        isScriptResourceURL(url)
    }

    static func failedResourceURL(from body: Any) -> String? {
        guard let dict = body as? [String: Any],
              dict["type"] as? String == "httpError" else { return nil }
        return dict["url"] as? String
    }
}
