import Foundation

final class WebViewNoCacheRetryPolicy {

    private let isCacheFeatureEnabled: () -> Bool

    private(set) var lastHTTPErrorDetail: String?

    private(set) var hasRetried = false

    init(isCacheFeatureEnabled: @escaping () -> Bool) {
        self.isCacheFeatureEnabled = isCacheFeatureEnabled
    }

    func onHTTPError(url: String?, status: Int?, hasReceivedInit: Bool) -> Bool {
        guard InAppWebViewHTTPError.isRecoverable(url: url, status: status) else { return false }
        lastHTTPErrorDetail = "HTTP \(status.map(String.init) ?? "?") for \(url ?? "nil")"
        guard !hasReceivedInit else { return false }
        guard !hasRetried else { return false }
        guard isCacheFeatureEnabled() else { return false }
        hasRetried = true
        return true
    }
}
