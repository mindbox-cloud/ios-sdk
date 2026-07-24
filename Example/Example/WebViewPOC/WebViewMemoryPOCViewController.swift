//
//  WebViewMemoryPOCViewController.swift
//  Example
//
//  POC stand for measuring memory behavior of multiple embedded WebView blocks:
//  - 2/3/5 simultaneous MindboxWebViewBlock instances loading real pages
//  - live telemetry: app footprint, available-to-jetsam memory, process kills, load times
//  - cache policy toggle to compare reload behavior with/without HTTP cache
//  - memory ballast to induce system memory pressure on a real device
//
//  Console markers: grep for "[POC]" in the app log.
//

import UIKit
import WebKit
import SwiftUI
import Mindbox

struct WebViewMemoryPOCView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebViewMemoryPOCViewController {
        WebViewMemoryPOCViewController()
    }

    func updateUIViewController(_ uiViewController: WebViewMemoryPOCViewController, context: Context) {}
}

final class WebViewMemoryPOCViewController: UIViewController {

    // Distinct origins so every block gets its own WebContent process and its own cache entries.
    // Mix of heavy (news/e-commerce) and light (wikipedia, as a control) pages.
    private static let pageURLs: [URL] = [
        URL(string: "https://lenta.ru")!,
        URL(string: "https://www.ozon.ru")!,
        URL(string: "https://www.theverge.com")!,
        URL(string: "https://www.apple.com")!,
        URL(string: "https://en.wikipedia.org/wiki/Moscow")!
    ]
    private static let blockHeight: CGFloat = 600

    private final class BlockSlot {
        let block: MindboxWebViewBlock
        let infoLabel = UILabel()
        let url: URL
        var loadStart: Date?
        var loadCount = 0
        var lastLoadMillis: Int?
        var state = "created"

        init(url: URL) {
            self.url = url
            self.block = MindboxWebViewBlock()
        }
    }

    private var slots: [BlockSlot] = []
    private var ballast: [UnsafeMutableRawPointer] = []
    private var statsTimer: Timer?

    private let statsLabel = UILabel()
    private let countControl = UISegmentedControl(items: ["2", "3", "5"])
    private let cacheSwitch = UISwitch()
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "WebView Memory POC"
        setupLayout()

        // Launch arg "-webviewPOCCount 5" lands in the NSArgumentDomain of UserDefaults,
        // letting automated runs pick the block count without UI interaction.
        let requestedCount = UserDefaults.standard.integer(forKey: "webviewPOCCount")
        let counts = [2, 3, 5]
        let initialCount = counts.contains(requestedCount) ? requestedCount : 2
        countControl.selectedSegmentIndex = counts.firstIndex(of: initialCount) ?? 0
        // Launch arg "-webviewPOCCache YES" pre-enables the returnCacheDataElseLoad policy.
        cacheSwitch.isOn = UserDefaults.standard.bool(forKey: "webviewPOCCache")

        // Launch arg "-webviewPOCClearCache YES" wipes the WebKit cache before the first
        // load, so cold-start times can be compared against warm-cache runs.
        if UserDefaults.standard.bool(forKey: "webviewPOCClearCache") {
            let types: Set<String> = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
            WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast) { [weak self] in
                self?.log("WebKit cache cleared before first load")
                self?.rebuildBlocks(count: initialCount)
            }
        } else {
            rebuildBlocks(count: initialCount)
        }

        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshStats()
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
        log("Screen opened, PID \(ProcessInfo.processInfo.processIdentifier)")
    }

    deinit {
        statsTimer?.invalidate()
        freeBallast()
    }

    // MARK: - Layout

    private func setupLayout() {
        statsLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statsLabel.numberOfLines = 0

        countControl.selectedSegmentIndex = 0
        countControl.addTarget(self, action: #selector(countChanged), for: .valueChanged)

        cacheSwitch.addTarget(self, action: #selector(cacheToggled), for: .valueChanged)
        let cacheLabel = UILabel()
        cacheLabel.text = "Cache"
        cacheLabel.font = .systemFont(ofSize: 13)

        let reloadButton = makeButton("Reload all", #selector(reloadAll))
        let clearCacheButton = makeButton("Clear cache", #selector(clearCache))
        let ballastButton = makeButton("+200MB", #selector(addBallast))
        let freeButton = makeButton("Free", #selector(freeBallastTapped))

        let controlsRow1 = UIStackView(arrangedSubviews: [countControl, cacheLabel, cacheSwitch, reloadButton])
        controlsRow1.spacing = 8
        controlsRow1.alignment = .center
        let controlsRow2 = UIStackView(arrangedSubviews: [clearCacheButton, ballastButton, freeButton])
        controlsRow2.spacing = 8
        controlsRow2.distribution = .fillEqually

        let scrollView = UIScrollView()
        stackView.axis = .vertical
        stackView.spacing = 12

        let header = UIStackView(arrangedSubviews: [statsLabel, controlsRow1, controlsRow2])
        header.axis = .vertical
        header.spacing = 8

        for subview in [header, scrollView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func makeButton(_ title: String, _ action: Selector) -> UIButton {
        var config = UIButton.Configuration.bordered()
        config.title = title
        config.buttonSize = .small
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // MARK: - Blocks

    private func rebuildBlocks(count: Int) {
        slots.forEach { $0.block.superview?.removeFromSuperview() }
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        slots = Self.pageURLs.prefix(count).map { BlockSlot(url: $0) }

        for slot in slots {
            let container = UIView()
            container.layer.borderWidth = 1
            container.layer.borderColor = UIColor.systemGray4.cgColor

            slot.infoLabel.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
            slot.infoLabel.textColor = .white
            slot.infoLabel.backgroundColor = UIColor.black.withAlphaComponent(0.65)
            slot.infoLabel.numberOfLines = 2

            slot.block.translatesAutoresizingMaskIntoConstraints = false
            slot.infoLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(slot.block)
            container.addSubview(slot.infoLabel)

            NSLayoutConstraint.activate([
                slot.block.topAnchor.constraint(equalTo: container.topAnchor),
                slot.block.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                slot.block.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                slot.block.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                slot.block.heightAnchor.constraint(equalToConstant: Self.blockHeight),
                slot.infoLabel.topAnchor.constraint(equalTo: container.topAnchor),
                slot.infoLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                slot.infoLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])
            stackView.addArrangedSubview(container)

            wireCallbacks(slot)
            startLoad(slot)
        }
        log("Rebuilt with \(count) blocks, cache=\(cacheSwitch.isOn)")
    }

    private func wireCallbacks(_ slot: BlockSlot) {
        let host = slot.url.host ?? "?"
        slot.block.onLoadFinished = { [weak self, weak slot] result in
            guard let self, let slot else { return }
            if let start = slot.loadStart {
                slot.lastLoadMillis = Int(Date().timeIntervalSince(start) * 1000)
            }
            slot.loadCount += 1
            switch result {
            case .success:
                slot.state = "loaded"
                self.log("\(host) loaded in \(slot.lastLoadMillis ?? -1) ms (load #\(slot.loadCount))")
            case .failure(let error):
                slot.state = "failed"
                self.log("\(host) FAILED: \(error.localizedDescription)")
            }
            self.refreshSlotLabel(slot)
        }
        slot.block.onWebContentProcessTerminated = { [weak self, weak slot] count in
            guard let self, let slot else { return }
            slot.state = "KILLED→reloading"
            slot.loadStart = Date()
            self.log("💀 \(host) WebContent process TERMINATED (kill #\(count)), auto-reloading")
            self.refreshSlotLabel(slot)
        }
    }

    private func startLoad(_ slot: BlockSlot) {
        slot.block.urlCachePolicy = cacheSwitch.isOn ? .returnCacheDataElseLoad : .useProtocolCachePolicy
        slot.state = "loading"
        slot.loadStart = Date()
        slot.block.load(url: slot.url)
        refreshSlotLabel(slot)
    }

    // MARK: - Actions

    @objc private func countChanged() {
        let counts = [2, 3, 5]
        rebuildBlocks(count: counts[countControl.selectedSegmentIndex])
    }

    @objc private func cacheToggled() {
        log("Cache policy switched to \(cacheSwitch.isOn ? "returnCacheDataElseLoad" : "useProtocolCachePolicy")")
    }

    @objc private func reloadAll() {
        slots.forEach { startLoad($0) }
        log("Reload all triggered, cache=\(cacheSwitch.isOn)")
    }

    @objc private func clearCache() {
        let types: Set<String> = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
        WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast) { [weak self] in
            self?.log("WebKit disk+memory cache cleared")
        }
    }

    @objc private func addBallast() {
        let bytes = 200 * 1024 * 1024
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: 16)
        memset(pointer, 1, bytes) // touch pages so the memory is dirty, not just reserved
        ballast.append(pointer)
        log("Ballast +200MB, total \(ballast.count * 200) MB")
        refreshStats()
    }

    @objc private func freeBallastTapped() {
        freeBallast()
        log("Ballast freed")
        refreshStats()
    }

    private func freeBallast() {
        ballast.forEach { $0.deallocate() }
        ballast.removeAll()
    }

    @objc private func appWillEnterForeground() {
        log("Will enter foreground; kills so far: \(slots.map { "\($0.url.host ?? "?")=\($0.block.processTerminationCount)" }.joined(separator: " "))")
    }

    // MARK: - Telemetry

    private func refreshStats() {
        let footprint = Self.appFootprintMB()
        let available = os_proc_available_memory() / (1024 * 1024)
        let totalKills = slots.reduce(0) { $0 + $1.block.processTerminationCount }
        statsLabel.text = String(
            format: "app footprint: %.0f MB | available: %d MB\nballast: %d MB | WebContent kills: %d",
            footprint, available, ballast.count * 200, totalKills
        )
        slots.forEach { refreshSlotLabel($0) }
    }

    private func refreshSlotLabel(_ slot: BlockSlot) {
        let time = slot.lastLoadMillis.map { "\($0) ms" } ?? "—"
        slot.infoLabel.text = " \(slot.url.host ?? "?") [\(slot.state)]\n loads: \(slot.loadCount)  kills: \(slot.block.processTerminationCount)  last: \(time)"
    }

    private static func appFootprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Double(info.phys_footprint) / (1024 * 1024)
    }

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[POC] \(timestamp) \(message)")
    }
}
