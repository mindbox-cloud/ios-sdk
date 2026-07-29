import Foundation

enum InAppWebViewHTTPError {

    static let minErrorStatus = 400

    static func isScriptResourceURL(_ url: String?) -> Bool {
        let raw = url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return false }
        let beforeFragment = raw.components(separatedBy: "#")[0]
        let path = beforeFragment.components(separatedBy: "?")[0]
        return path.lowercased().hasSuffix(".js")
    }

    static func isRecoverable(url: String?, status: Int?) -> Bool {
        guard let status else { return isScriptResourceURL(url) }
        return status >= minErrorStatus && isScriptResourceURL(url)
    }

    static func statusDescription(_ status: Int?) -> String {
        status.map { "HTTP \($0)" } ?? "load failure (no HTTP status on WebKit)"
    }

    static func message(from body: Any) -> (url: String?, status: Int?)? {
        guard let dict = body as? [String: Any],
              dict["type"] as? String == "httpError" else { return nil }
        return (dict["url"] as? String, (dict["status"] as? NSNumber)?.intValue)
    }
}
