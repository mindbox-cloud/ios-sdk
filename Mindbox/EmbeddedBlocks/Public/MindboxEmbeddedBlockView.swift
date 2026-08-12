//
//  MindboxEmbeddedBlockView.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// A drop-in container for a Mindbox embedded block.
///
/// Created with the block `id` from the admin panel and the `height` the block should occupy.
/// Put it anywhere in the app and constrain its position and width only — the height is applied
/// by the container itself through `intrinsicContentSize`: the one given at creation while the
/// content is loading and shown, and 0 when there is nothing to show (a failure or an empty
/// block), so the block takes no space and is invisible in the host layout. Both outcomes can be
/// customized: `placeholderView` replaces the stock loading shimmer, and `errorView` opts into
/// showing a failure instead of collapsing.
///
/// What exactly lives inside is decided by the SDK from the block `id`, not by the host. The
/// block flow belongs to the SDK too: the container starts its content when it enters a window
/// and stops it when it leaves. The host app observes the outcome through `delegate` and nothing
/// else.
///
/// Сам контейнер — это машина из четырёх состояний контента и одного видимого слоя на каждое из
/// них. Всё, что можно было унести из него целиком, унесено: показ слоёв — в
/// `EmbeddedBlockLayerHost`, бюджет ожидания вместе с его паузой в фоне — в
/// `EmbeddedBlockReadyTimeout`.
public final class MindboxEmbeddedBlockView: UIView {

    // MARK: - Host API

    /// The block id from the admin panel, given at creation. Decides what content the SDK puts
    /// inside.
    public let id: String

    /// Receives the block events. Assigning a delegate after the content already resolved still
    /// delivers that outcome, so subscribing late cannot lose it.
    public weak var delegate: MindboxEmbeddedBlockViewDelegate? {
        didSet {
            // Тот же делегат — не новый подписчик. Хост штатно переприсваивает его на каждой
            // переиспользованной ячейке, и отдавать ему на это уже услышанный исход нельзя: он на
            // исход перестраивает вёрстку, а перестройка вёрстки снова переприсваивает делегата.
            guard delegate !== oldValue else { return }

            deliveredEvent = nil
            scheduleDelivery()
        }
    }

    /// The view shown in place of the content while it is loading. `nil` — the default — means
    /// the SDK's own shimmer. The placeholder fills the whole container, so it is laid out to the
    /// container's width and the height given at creation. Can be swapped at any moment, including
    /// mid-loading.
    public var placeholderView: UIView? {
        didSet {
            guard placeholderView !== oldValue else { return }
            refreshPlaceholder()
        }
    }

    /// The view shown when the block fails. `nil` — the default — keeps the failure invisible:
    /// the container collapses to zero height. Setting a view opts into showing the failure
    /// instead: the container keeps the height given at creation and fills itself with this view.
    /// The SDK ships no stock error screen — what a failed block looks like is the host's design
    /// decision. Applies only to failures; an empty block always collapses.
    ///
    /// A view assigned mid-failure swaps the error screen that is already shown, but never
    /// expands a block that has already collapsed — reopening space the host layout has
    /// reclaimed would make the layout jump. Such a view is remembered and takes effect on
    /// the next load.
    public var errorView: UIView? {
        didSet {
            guard errorView !== oldValue else { return }
            refreshErrorView()
        }
    }

    /// What the container shows, for the SwiftUI wrapper: it sizes the representable itself instead
    /// of relying on `intrinsicContentSize`, and it draws the host's placeholder and error screen
    /// itself instead of handing them over as `UIView`s. Internal: not part of the public API.
    var onPresentationChange: ((EmbeddedBlockPresentation) -> Void)?

    // MARK: - State

    private let contentProvider: EmbeddedBlockWebViewProvider

    /// The height the host reserved for the block at creation. The container holds it while the
    /// content is loading and shown, and drops to 0 when there is nothing to show.
    private let preferredHeight: CGFloat

    private let timeout: EmbeddedBlockReadyTimeout

    private lazy var layers = EmbeddedBlockLayerHost(container: self)

    private lazy var defaultPlaceholder = EmbeddedBlockShimmerView()

    private var state: EmbeddedBlockState = .loading {
        didSet {
            updateTimeout(from: oldValue)
            apply(state)
        }
    }

    /// Схлопывался ли блок с прошлой явной перезагрузки.
    ///
    /// Место, единожды отданное хосту, назад не забирается: повторная попытка — а её блок получает
    /// на каждом возвращении в окно — не разворачивает контейнер обратно под плейсхолдер. Иначе
    /// блок, который показать не удалось, дёргал бы вёрстку хоста на свою высоту и мигал шиммером
    /// на каждый свой проход по экрану, ничего в итоге не показывая. Разворачивает его только
    /// показанный контент — или явная перезагрузка, которая и есть согласие на полный цикл заново.
    private var hasCollapsed = false

    /// Слой, показанный прямо сейчас. Хранится, а не вычисляется на лету: он один источник и для
    /// высоты, и для отчёта обёртке — иначе они могли бы разойтись. И он же отделяет показанный
    /// экран ошибки от просто назначенного: `errorView`, отданный после схлопывания, не показан.
    private var shownLayer: EmbeddedBlockPresentation.Layer = .placeholder

    /// Публичных исходов два: показан или не показан. «Пусто» для хоста — тот же непоказ, что и
    /// ошибка, разница живёт только внутри контейнера (пустой блок не показывает `errorView`).
    private enum BlockEvent {
        case loaded
        case failed
    }

    /// The last event handed to the current delegate — keeps the same outcome from being reported
    /// twice, for instance when restarted content fails again.
    private var deliveredEvent: BlockEvent?

    private var isDeliveryScheduled = false

    // MARK: - Life cycle

    /// - Parameters:
    ///   - id: The block id from the admin panel.
    ///   - height: The height the block occupies while loading and shown. Reserving it is the
    ///     host's job and there is no default: a height of 0 or less leaves the block invisible
    ///     whatever its content turns out to be, so the SDK reports it as an integration error.
    public convenience init(id: String, height: CGFloat) {
        self.init(id: id,
                  height: height,
                  contentProvider: DI.injectOrFail(EmbeddedBlockContentProviderMaking.self).makeProvider(id: id))
    }

    /// Blocks are not created from storyboards: the id and the height are required and have no
    /// sensible defaults. Create the view in code with `init(id:height:)`.
    @available(*, unavailable, message: "Use init(id:height:) instead")
    public required init?(coder: NSCoder) {
        return nil
    }

    /// - Parameter timeout: Бюджет ожидания целиком, а не одна его длительность: внутри него живут
    ///   и часы, и планировщик, и подписка на фон, а подменять их поодиночке через контейнер значило
    ///   бы протащить сквозь него три параметра ради тестов.
    init(id: String,
         height: CGFloat,
         contentProvider: EmbeddedBlockWebViewProvider,
         timeout: EmbeddedBlockReadyTimeout? = nil) {
        self.id = id
        self.preferredHeight = height
        self.contentProvider = contentProvider
        self.timeout = timeout ?? EmbeddedBlockReadyTimeout(
            blockId: id,
            duration: TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds)
        )
        super.init(frame: .zero)
        warnIfHeightReservesNothing()
        setUpContainer()
    }

    /// Высоту блока задаёт хост, и нулевая — это не «блок схлопнут», а «место под него не выделено»:
    /// блок отработает весь цикл, отдаст хосту свои события и останется невидимым. Симптомов у этого
    /// нет никаких — блока просто не видно, — а причина самая частая из возможных, поэтому SDK
    /// говорит о ней вслух.
    private func warnIfHeightReservesNothing() {
        guard preferredHeight <= 0 else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(id)' was created with height \(preferredHeight): it reserves no space and stays invisible even when its content loads. Pass the height the block should occupy.",
                      level: .error,
                      category: .embeddedBlocks)
    }

    deinit {
        timeout.pause()
        contentProvider.stop()
    }

    private func setUpContainer() {
        clipsToBounds = true
        backgroundColor = .clear

        contentProvider.onStateChange = { [weak self] state in
            self?.state = state
        }

        timeout.isNeeded = { [weak self] in
            guard let self else { return false }
            return self.window != nil && self.state == .loading
        }
        timeout.onExpire = { [weak self] in
            self?.handleTimeout()
        }

        // The block reserves its space right away, before any loading starts, and reserved space
        // must not look blank.
        layers.show(view(for: shownLayer))
    }

    // MARK: - Layout

    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: contentHeight)
    }

    /// Hosts that lay out by frames rather than by constraints get the same height here.
    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: contentHeight)
    }

    private var contentHeight: CGFloat {
        switch shownLayer {
        case .placeholder, .content, .errorView: return max(0, preferredHeight)
        case .nothing: return 0
        }
    }

    // MARK: - Visibility

    /// Visibility drives the content: there is no reason to hold content for a container that is
    /// not in a window, and no public way for the host to start or stop it by hand.
    override public func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            Logger.common(message: "[EmbeddedBlock] Block '\(id)' left the window, stopping content", category: .embeddedBlocks)
            // Пауза, а не сброс: вне окна блока никто не ждёт, но начатую попытку это не отменяет —
            // вернувшись, она досчитает свой остаток.
            timeout.pause()
            contentProvider.stop()
        } else {
            Logger.common(message: "[EmbeddedBlock] Block '\(id)' entered the window, starting content", category: .embeddedBlocks)
            contentProvider.start()
            timeout.armIfNeeded()
        }
    }

    /// Перезагружает блок: контент начинает загрузку с нуля, адрес запрашивается заново в обход
    /// кэша, блок возвращается в состояние загрузки со своим плейсхолдером и новым таймаутом.
    ///
    /// Internal и без публичной обёртки: автоматические перезагрузки — по ошибке, по возвращению
    /// в приложение — будут строиться на этом методе, а хосту решать, когда обновлять блок, пока
    /// незачем.
    func reload() {
        guard window != nil else {
            // Контент живёт только пока блок в окне; перезагружать невидимый блок нечего — он
            // сам загрузится заново, когда вернётся в окно.
            Logger.common(message: "[EmbeddedBlock] Block '\(id)' reload skipped: the block is not in a window",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(id)' reload requested", category: .embeddedBlocks)
        timeout.reset()
        // Новая попытка — новый исход: хост должен услышать его целиком, даже если он совпадёт
        // с прошлым.
        deliveredEvent = nil
        // И новая попытка вправе снова занять место: перезагрузка — это явное согласие хоста на
        // полный цикл с плейсхолдером, в отличие от молчаливого возвращения блока в окно.
        hasCollapsed = false
        contentProvider.reload()
        timeout.armIfNeeded()
    }

    private func handleTimeout() {
        // Stop first: the provider must not resurrect content the container already gave up on.
        contentProvider.stop()
        state = .failed
    }

    // MARK: - Layers

    /// Бюджет ожидания живёт по попыткам, а не по состояниям: продолжающаяся загрузка досчитывает
    /// свой остаток, а всё остальное — известный исход или начатая заново загрузка — счёт обнуляет.
    /// Заводить его снова решает тот, кто знает, ждут ли блок: вход в окно и возврат из фона.
    private func updateTimeout(from previous: EmbeddedBlockState) {
        guard state != .loading || previous != .loading else { return }

        timeout.reset()
    }

    private func apply(_ state: EmbeddedBlockState) {
        shownLayer = layer(for: state)

        if shownLayer == .nothing {
            hasCollapsed = true
        }

        layers.show(view(for: shownLayer))

        invalidateIntrinsicContentSize()
        onPresentationChange?(EmbeddedBlockPresentation(layer: shownLayer, height: contentHeight))
        scheduleDelivery()
    }

    private func layer(for state: EmbeddedBlockState) -> EmbeddedBlockPresentation.Layer {
        switch state {
        // Схлопнутый блок остаётся свёрнутым и пока грузится заново: место, которое хост уже
        // забрал, повторная попытка назад не отыгрывает.
        case .loading: return hasCollapsed ? .nothing : .placeholder
        case .ready: return .content
        // Провал показывают только тем, кто согласился на это явно; остальным блок сворачивается.
        case .failed: return errorView == nil ? .nothing : .errorView
        case .empty: return .nothing
        }
    }

    private func view(for layer: EmbeddedBlockPresentation.Layer) -> UIView? {
        switch layer {
        case .placeholder: return placeholderView ?? defaultPlaceholder
        case .content: return contentProvider.contentView
        case .errorView: return errorView
        case .nothing: return nil
        }
    }

    /// A placeholder swap takes effect immediately, but only while the placeholder is what the
    /// container shows — in any other state the new view is simply remembered for the next load.
    private func refreshPlaceholder() {
        guard shownLayer == .placeholder else { return }
        layers.show(view(for: .placeholder))
    }

    /// Swapping a shown error screen takes effect immediately, but a collapsed block is not
    /// reopened retroactively: the host layout already reclaimed the space, and expanding it out
    /// of nowhere would make the layout jump. The new view is remembered for the next load. In
    /// any other state the view is simply remembered too.
    private func refreshErrorView() {
        guard state == .failed, shownLayer == .errorView else { return }
        apply(state)
    }

    // MARK: - Host events

    /// Events are handed over on the next main-queue turn: the state can flip in the middle of a
    /// layout pass, and re-entering host code from there is a good way to break the host's layout.
    private func scheduleDelivery() {
        guard !isDeliveryScheduled else { return }

        isDeliveryScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.deliverPendingEvent()
        }
    }

    private func deliverPendingEvent() {
        isDeliveryScheduled = false

        guard let delegate = delegate,
              let event = event(for: state),
              event != deliveredEvent else {
            return
        }

        deliveredEvent = event

        switch event {
            case .loaded: delegate.mindboxEmbeddedBlockViewDidLoad(self)
            case .failed: delegate.mindboxEmbeddedBlockViewDidFail(self)
        }
    }

    private func event(for state: EmbeddedBlockState) -> BlockEvent? {
        switch state {
            case .loading: return nil
            case .ready: return .loaded
            case .failed, .empty: return .failed
        }
    }
}
