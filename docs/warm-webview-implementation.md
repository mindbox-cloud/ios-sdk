# Warm WebView — Реализация и архитектура

**Дата:** 2026-04-08
**Статус:** Реализовано (MVP)
**Ветка:** feature/MOBILE-0000-MVP-CachedWebView

---

## Используемые стратегии

Текущая реализация комбинирует **3 стратегии** из `webview-optimization-strategies.md`:

| # | Стратегия | Статус | Роль |
|---|-----------|--------|------|
| **1** | HTML Pre-cache | Готово (ранее) | Скачивает HTML всех webview in-apps в memory-кэш сразу после конфига |
| **3** | Shared ProcessPool | Готово (ранее) | Один `WKProcessPool` для всех WKWebView — HTTP cache + JSC bytecode cache |
| **14** | Warm WebView | **Реализовано (новое)** | Один прогретый WebView обслуживает любой webview in-app |

Стратегии **2** (Pre-rendering single slot) и **4** (Pre-rendering pool) **заменены** на Warm WebView.

---

## Схема работы

```
 ┌──────────────────────────────────────────────────────────────┐
 │  ФАЗА 1: Загрузка конфига                                    │
 │                                                               │
 │  InAppConfigurationManager.completeDownloadTask()             │
 │    → decode ConfigResponse                                    │
 │    → preloadWebViewContent(config):                           │
 │                                                               │
 │      1) contentPreloader.preloadContent(config)               │
 │         → извлекает ВСЕ contentUrl webview in-apps            │
 │         → скачивает HTML каждого → WebViewContentCache        │
 │           (in-memory кэш)                                     │
 │                                                               │
 │      2) DispatchQueue.main.asyncAfter(2 сек):                 │
 │         warmHolder.warmUp(config)                             │
 └──────────────────────────────────────────────────────────────┘
                              │
                              ▼
 ┌──────────────────────────────────────────────────────────────┐
 │  ФАЗА 2: Warm-up (фон, пользователь не видит)                │
 │                                                               │
 │  WarmWebViewHolder.warmUp(config):                            │
 │    → findFirstWebViewCandidate(config)                        │
 │      перебирает config.inapps.elements по порядку             │
 │      берёт ПЕРВЫЙ in-app с webview layer                      │
 │      (не по приоритету — первый в массиве конфига)            │
 │    → preloader.cachedHTML(contentUrl)                          │
 │      берёт HTML из кэша (скачан на Фазе 1)                   │
 │    → создаёт TransparentView(                                 │
 │        params: [:],  inAppId: "",  isPreloadMode: true        │
 │      )                                                        │
 │    → loadHTMLFromCache(html, baseUrl)                         │
 │      → WKWebView.loadHTMLString (SharedProcessPool)           │
 │                                                               │
 │  JS загружается:                                              │
 │    HTML → <script src="tracker.js"> → <script src="main.js"> │
 │    → JS инициализируется                                      │
 │    → JS шлёт postMessage({ action: "ready", id: "..." })     │
 │    → TransparentView: isPreloadMode=true                      │
 │      → сохраняет pendingReadyId                               │
 │      → НЕ отвечает                                            │
 │    → WebView в состоянии "warm"                               │
 │                                                               │
 │  Память: ~30-50MB на один WKWebView                           │
 │  Время: ~1.5-2s в фоне                                       │
 └──────────────────────────────────────────────────────────────┘
                              │
                       (ждёт триггера)
                              │
                              ▼
 ┌──────────────────────────────────────────────────────────────┐
 │  ФАЗА 3: Триггер                                             │
 │                                                               │
 │  InAppCoreManager.sendEvent(event)                            │
 │    → InAppConfigurationManager.handleInapps(event)            │
 │      → InappMapper: таргетинг, частота, приоритет             │
 │      → возвращает InAppFormData (конкретный in-app)           │
 │    → InappScheduleManager.scheduleInApp(formData)             │
 │      → timer с delay                                          │
 │      → presentInapp(formData, stopwatch)                      │
 └──────────────────────────────────────────────────────────────┘
                              │
                              ▼
 ┌──────────────────────────────────────────────────────────────┐
 │  ФАЗА 4: Презентация                                         │
 │                                                               │
 │  PresentationDisplayUseCase.presentInAppUIModel()             │
 │    → strategy = WebviewPresentationStrategy                   │
 │    → window = UIWindow(alpha ≈ 0, невидимое)                  │
 │    → WebViewFactory → WebViewController                       │
 │    → window.rootViewController = vc                           │
 │                                                               │
 │  WebViewController.viewDidLoad() → setupWebView():            │
 │                                                               │
 │    ┌─ TRY WARM ────────────────────────────────────────────┐  │
 │    │ warmHolder.claim(inAppId, params, operation):          │  │
 │    │   ✓ warmView != nil                                    │  │
 │    │   ✓ pendingReadyId != nil (JS ready)                   │  │
 │    │   → view.updateInAppId(inAppId)                        │  │
 │    │   → view.updateParams(webviewLayer.params)             │  │
 │    │   → view.updateOperation(operation)                    │  │
 │    │   → return TransparentView                             │  │
 │    │   → scheduleRewarm() (через 1 сек — новый warm)       │  │
 │    │                                                        │  │
 │    │ completeReadyHandshake():                              │  │
 │    │   → facade.sendReadyEvent(id)                          │  │
 │    │     payload: { inAppId, formId, operation, ... }       │  │
 │    │   → запускает timeout timer                            │  │
 │    │                                                        │  │
 │    │ JS получает payload → рендерит → шлёт "init"          │  │
 │    │ Время: ~0.3s                                           │  │
 │    └────────────────────────────────────────────────────────┘  │
 │                                                               │
 │    ┌─ FALLBACK (COLD) ─────────────────────────────────────┐  │
 │    │ Если warm miss (нет warm view или JS не ready):        │  │
 │    │ → новый TransparentView(params, inAppId)               │  │
 │    │ → loadHTMLPage(baseUrl, contentUrl)                    │  │
 │    │ → fetch HTML → load → JS init → ready → respond        │  │
 │    │ → JS рендерит → "init"                                 │  │
 │    │ Время: ~2.2s                                           │  │
 │    └────────────────────────────────────────────────────────┘  │
 └──────────────────────────────────────────────────────────────┘
                              │
                              ▼
 ┌──────────────────────────────────────────────────────────────┐
 │  ФАЗА 5: Показ пользователю                                  │
 │                                                               │
 │  JS шлёт "init" → bridge → TransparentView                   │
 │    → webViewAction.onInit()                                   │
 │    → WebViewController.onInit():                              │
 │        window.alpha = 1.0 (анимация 0.3s)                    │
 │        window.makeKeyAndVisible()                             │
 │        notifyPresentedIfNeeded() → onPresented()              │
 │                                                               │
 │  InappScheduleManager.onPresented:                            │
 │    → tracker.trackView() → Inapp.Show                         │
 │    → trackingService.trackInAppShown()                        │
 │                                                               │
 │  ⚠️ Inapp.Show отправляется ТОЛЬКО после "init" от JS.       │
 │     Warm-up и preload НЕ триггерят Inapp.Show.               │
 └──────────────────────────────────────────────────────────────┘
                              │
                              ▼
 ┌──────────────────────────────────────────────────────────────┐
 │  ФАЗА 6: Re-warm (фон, после claim)                          │
 │                                                               │
 │  scheduleRewarm() — через 1 сек после claim:                  │
 │    → createWarmView(html, baseUrl) — тот же HTML              │
 │    → новый TransparentView + loadHTMLFromCache                │
 │    → JS загружается → "ready" → held                          │
 │    → готов к следующему триггеру                               │
 │                                                               │
 │  Время re-warm: ~0.5-0.7s (bytecode cache через              │
 │  SharedProcessPool ускоряет повторную компиляцию JS)          │
 └──────────────────────────────────────────────────────────────┘
```

---

## Ключевое допущение

> **HTML + JS одинаковые для всех webview in-apps.**
>
> JS — это SPA-фреймворк. Он рендерит разный контент в зависимости от payload,
> переданного через bridge в ready response (`formId`, `inAppId`, `params`).
> HTML — это bootstrap-шаблон, который загружает `tracker.js` + `main.js`.

**Если это допущение верно:**
- Warm WebView работает для 100% webview in-apps
- Один WebView обслуживает любой in-app через payload
- Hit rate: 100%, время показа: ~0.3s

**Если допущение неверно (HTML разный per in-app):**
- Warm view загрузит "чужой" HTML
- JS не сможет отрендерить payload другого in-app
- Timeout → fallback на cold flow (~2.2s)
- Warm WebView фактически бесполезен

**Статус проверки:** Не подтверждено. Требуется проверка у фронтенд-команды.

---

## Допущения и ограничения

### Допущения
1. HTML+JS одинаковый для всех webview in-apps (см. выше)
2. JS может принять payload через ready response без повторной загрузки HTML
3. `nonPersistent()` data store не мешает bytecode cache в рамках shared ProcessPool
4. Один WKWebView в shared pool не влияет на другой при параллельной загрузке (re-warm)

### Ограничения
1. **Память:** ~30-50MB на warm WebView (всегда занят, даже если in-app не показывается)
2. **Memory warning:** warm view evict'ится → следующий триггер идёт через cold flow
3. **Первый in-app в конфиге:** `findFirstWebViewCandidate` берёт первый webview in-app в порядке массива, не по приоритету
4. **Re-warm после claim:** задержка 1 сек. Если второй in-app триггерится менее чем через 1 сек после первого — cold flow
5. **Один warm view:** только один WebView в памяти. Нет пула.

### Открытые вопросы
1. **[БЛОКЕР]** Может ли JS принять payload повторно без перезагрузки HTML? → Уточнить у фронтенд-команды
2. Нужно ли приоритизировать кандидата для warm-up (priority in-apps первыми)?
3. Работает ли JSC bytecode cache с `nonPersistent()` data store?
4. Мешает ли re-warm основному WebView через SharedProcessPool?

---

## Изменённые файлы

| Файл | Изменение |
|------|-----------|
| `WarmWebViewHolder.swift` | **Новый.** Warm-up, claim, re-warm, invalidate |
| `MindboxWebViewFacade.swift` | `updateInAppId()`, `updateParams()` — обновление данных после создания |
| `TransparentView.swift` | `inAppId` стал `var`, добавлены `updateInAppId()`, `updateParams()` |
| `InAppConfigurationManager.swift` | `prerenderedHolder` → `warmHolder`, `prerender()` → `warmUp()` |
| `WebViewController.swift` | claim из `WarmWebViewHolderProtocol`, fallback на cold flow |
| `InjectInappTools.swift` | DI: `WarmWebViewHolderProtocol` → `WarmWebViewHolder` |
| `InjectCore.swift` | Передача `warmHolder` в `InAppConfigurationManager` |

---

## Сравнение с предыдущей реализацией (Pre-rendering)

| | Pre-rendering (pool, N слотов) | Warm WebView |
|---|---|---|
| WebView'ов в памяти | N (по 30-50MB каждый) | 1 (30-50MB) |
| Hit rate | ~30-50% (только pre-rendered in-apps) | 100% (любой webview in-app) |
| Время показа (hit) | ~1.0s | ~0.3s |
| Время показа (miss) | ~2.2s (cold) | — miss невозможен* |
| После закрытия | Пул пуст, cold flow | Re-warm через 1 сек |
| Привязка к конкретному in-app | Да (один WebView = один in-app) | Нет (один WebView = любой in-app) |

*При условии что warm view готов и допущение про одинаковый HTML верно.
