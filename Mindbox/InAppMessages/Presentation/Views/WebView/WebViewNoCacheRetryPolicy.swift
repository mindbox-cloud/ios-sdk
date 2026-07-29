import Foundation

final class WebViewNoCacheRetryPolicy {

    static let maxAttempts = 2

    private let isCacheFeatureEnabled: () -> Bool

    private(set) var lastHTTPErrorDetail: String?

    private(set) var attemptsUsed = 0

    private var purgeRemovedEntry = false

    private var isPurgeOutcomePending = false

    var hasRetried: Bool { attemptsUsed > 0 }

    init(isCacheFeatureEnabled: @escaping () -> Bool) {
        self.isCacheFeatureEnabled = isCacheFeatureEnabled
    }

    func onHTTPError(url: String?, status: Int?, hasReceivedInit: Bool) -> Bool {
        guard InAppWebViewHTTPError.isRecoverable(url: url, status: status) else { return false }
        lastHTTPErrorDetail = "\(InAppWebViewHTTPError.statusDescription(status)) for \(url ?? "nil")"
        guard !hasReceivedInit else { return false }
        guard !purgeRemovedEntry, !isPurgeOutcomePending, attemptsUsed < Self.maxAttempts else { return false }
        guard isCacheFeatureEnabled() else { return false }
        attemptsUsed += 1
        isPurgeOutcomePending = true
        return true
    }

    func notePurgeOutcome(didRemoveAnything: Bool) {
        isPurgeOutcomePending = false
        if didRemoveAnything { purgeRemovedEntry = true }
    }
}
