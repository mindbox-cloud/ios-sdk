# WebView In-App Optimization Strategies

**Date:** 2026-04-06
**Goal 1:** Pre-loading — минимизировать время показа WebView in-app для пользователя
**Goal 2:** Offline — показывать WebView in-apps без сети

---

## Текущая архитектура

### Что происходит при показе WebView in-app (без оптимизаций)

```
Trigger → Create WKWebView → Fetch HTML (network) → loadHTMLString
       → JS загружает tracker.js + main.js (network) → Parse + Compile JS
       → JS bootstrap (bridge, init) → JS получает payload → Render контента
       → Показ окна
```

| Шаг | Время | Требует сети |
|-----|-------|-------------|
| WKWebView creation | ~50ms | Нет |
| HTML fetch (CDN) | ~200-1000ms | **Да** |
| `tracker.js` fetch (~50KB) | ~100-300ms | **Да** |
| `main.js` fetch | ~100-300ms | **Да** |
| JS parse + compile | ~300ms | Нет |
| JS bootstrap (bridge, listeners) | ~200ms | Нет |
| JS render payload | ~300-500ms | Нет |
| **Итого** | **~1.7-2.5s** | |

### Структура HTML страницы

```html
<!DOCTYPE html>
<html>
<head>
  <script>
    window.__env_vars = {
      TRACKER_PATH: 'https://api.mindbox.ru/scripts/v1/tracker.js?v=1.0.25',
      MAIN_JS_PATH: 'https://mobile-static.mindbox.ru/.../main.js?v=1.0.25',
    }
    // Динамически создаёт <script src="..."> для tracker и main
  </script>
</head>
<body></body>
</html>
```

**Ключевое наблюдение:**
- HTML страницы **разные** для каждого in-app (разная вёрстка, стили)
- JS tracker (`tracker.js`) и `main.js` — **одинаковые** для всех in-apps
- Скрипты загружаются **по URL** (`<script src="...">`), а не inline

---

## Стратегия 1: HTML Pre-cache

**Статус:** Реализовано

### Суть
Скачиваем HTML всех webview in-apps в память сразу после получения конфига.

### Что экономим
- HTML network fetch: ~200-1000ms → 0ms

### Что остаётся
- WKWebView creation, JS fetch, JS parse/compile, JS render

### Реализация
- `WebViewContentPreloader` — извлекает URL из конфига, скачивает HTML
- `WebViewContentCache` — in-memory `[String: String]` кэш
- Инвалидация при memory warning

### Ограничения
- Только in-memory — после kill приложения скачивает заново
- Не кэширует JS файлы (tracker.js, main.js)

---

## Стратегия 2: Pre-rendering (Single Slot)

**Статус:** Реализовано

### Суть
Создаём WKWebView заранее, загружаем HTML + JS, доводим до состояния `.ready`, держим handshake до триггера.

### Что экономим
- Всё кроме JS render payload: ~1.25s

### Результат
- `presentationTime`: 2.2s → 1.0s (−55%)

### Реализация
- `PrerenderedWebViewHolder` — держит один pre-rendered WKWebView
- Через 2 сек после конфига: выбирает priority in-app, рендерит
- При claim: отдаёт view, отправляет held handshake

### Ограничения
- Только 1 in-app pre-rendered
- Claim miss → standard flow (~2.2s)
- ~30-50MB памяти на один WKWebView

---

## Стратегия 3: Shared WKProcessPool

**Статус:** Реализовано (прототип)

### Суть
Все WKWebView в SDK используют один `WKProcessPool`. Это один WebContent процесс на все webview.

### Что даёт
Поскольку `tracker.js` и `main.js` загружаются **по URL** и одинаковые для всех in-apps:
- **HTTP cache** — скрипты скачиваются из сети один раз, остальные WKWebView берут из кэша процесса
- **JSC bytecode cache** — JavaScriptCore кэширует скомпилированный байткод для скриптов по URL. Повторная компиляция значительно быстрее

### Оценка выигрыша

| | 1-й WKWebView | 2-й+ WKWebView |
|---|---|---|
| Fetch tracker.js + main.js | ~200ms (сеть) | ~0ms (HTTP cache) |
| Parse + compile JS | ~300ms | ~50ms (bytecode cache) |
| JS bootstrap | ~200ms | ~200ms |
| Render payload | ~300ms | ~300ms |
| **Итого JS часть** | **~1000ms** | **~550ms** |

### Реализация
```swift
enum SharedWebViewProcessPool {
    static let pool = WKProcessPool()
}
// В WKWebViewConfiguration:
config.processPool = SharedWebViewProcessPool.pool
```

### Ограничения
- Crash в WebContent process убивает все webview (риск минимален для controlled HTML)
- Выигрыш только для 2-го+ WKWebView в рамках одной сессии
- `nonPersistent()` dataStore — кэш не переживает перезапуск приложения

### Вопрос для исследования
- Работает ли bytecode cache с `nonPersistent()` data store? Нужно замерить. Если нет — рассмотреть default data store с ручной очисткой

---

## Стратегия 4: Pre-rendering Pool (N слотов)

**Статус:** Реализовано (прототип)

### Суть
Вместо одного pre-rendered WKWebView — пул из N (по умолчанию 3) с приоритезацией.

### Что даёт
- Claim hit для нескольких in-apps, а не только для priority
- В комбинации со Shared ProcessPool: 2-й и 3-й WKWebView в пуле создаются быстрее

### Memory budget
| Pool size | С shared pool | Без shared pool |
|-----------|--------------|-----------------|
| 1 | ~30-50MB | ~30-50MB |
| 2 | ~40-65MB | ~60-100MB |
| 3 | ~50-80MB | ~90-150MB |

### Реализация
```swift
private var pool: [String: PrerenderedWebView] = [:]
// Priority in-apps рендерятся первыми
// Memory warning → evict всего пула
```

### Ограничения
- Каждый WKWebView = ощутимый memory footprint
- На устройствах с 2GB RAM (iPhone SE) — 3 webview может быть слишком много
- Нужен adaptive pool size на основе доступной памяти

### Возможные улучшения
- **Adaptive pool size**: `ProcessInfo.processInfo.physicalMemory` — если < 3GB, уменьшить пул до 1-2
- **Graduated eviction**: при первом memory warning — evict до 1 view, при втором — evict всё
- **LRU eviction**: если пул полон и нужно добавить новый in-app — удалить наименее приоритетный

---

## Стратегия 5: JS Pre-warming (Blank Template)

**Статус:** Не реализовано

### Суть
Создать один WKWebView с "пустым" HTML, который загружает только `tracker.js` + `main.js`. JS фреймворк инициализируется, но контент не рендерится. При показе — заменить HTML контентом конкретного in-app.

### Как работает
```
При старте:
  WKWebView → load blank HTML with <script src="tracker.js"> → JS init done

При триггере:
  loadHTMLString(конкретный in-app HTML) → JS уже в bytecode cache → быстрый parse
  → JS render payload
```

### Что экономим
- WKWebView creation: 0ms (pre-created)
- JS fetch: 0ms (уже в HTTP cache процесса)
- JS compile: значительно быстрее (bytecode cache в рамках того же процесса)

### Отличие от Pre-rendering
- Pre-rendering рендерит конкретный in-app до `.ready` — один WKWebView на один in-app
- JS Pre-warming только инициализирует JS движок — один WKWebView прогревает кэш для всех

### Реализация
```swift
// Blank HTML для прогрева JS engine
let warmupHTML = """
<html><head>
<script src="https://api.mindbox.ru/scripts/v1/tracker.js?v=1.0.25"></script>
<script src="https://mobile-static.mindbox.ru/.../main.js?v=1.0.25"></script>
</head><body></body></html>
"""
```

### Ограничения
- Нужно знать URL скриптов из конфига до загрузки HTML
- Не убирает JS bootstrap и render time (~500ms)
- Выигрыш зависит от эффективности bytecode cache в JSC
- Потенциально бесполезно если Shared ProcessPool + Pre-rendering уже покрывают этот кейс

### Когда полезно
- Если pool size ограничен 1 (мало памяти) и нужно ускорить cold miss
- Как fallback при claim miss: "JS уже скомпилирован, осталось загрузить HTML и отрендерить"

---

## Стратегия 6: Predictive Pre-render

**Статус:** Не реализовано

### Суть
Оставить ограниченный пул (1-2), но умнее выбирать что рендерить.

### Сигналы для предсказания
1. **Priority in-apps** — всегда рендерить первыми (уже реализовано)
2. **Targeting data** — если таргетинг сегмента уже проверен и in-app подходит, рендерить его
3. **Event history** — если пользователь часто триггерит определённый event, рендерить связанный in-app
4. **After dismiss** — после закрытия одного in-app, рендерить следующий вероятный

### Реализация
```swift
func onInAppDismissed(shown: InAppId) {
    let next = predictNext(after: shown, from: config)
    prerenderSingle(next)
}
```

### Ограничения
- Сложность предсказания
- Prediction miss = standard flow
- Полезно только если in-apps показываются последовательно в одной сессии

---

## Стратегия 7: Offline — Disk Cache для HTML

**Статус:** Не реализовано

### Суть
Сохранять HTML на диск, чтобы при отсутствии сети использовать последний скачанный вариант.

### Что кэшируем
- HTML страницы in-apps (маленькие, ~1-2KB каждая)

### Как работает
```
С сетью:
  Config → скачать HTML → сохранить на диск + в memory cache → use

Без сети:
  Config из кэша → HTML из disk cache → use
```

### Реализация
```swift
class WebViewContentDiskCache {
    private let cacheDir: URL  // Library/Caches/MindboxWebViewHTML/
    
    func save(html: String, for url: String)
    func load(for url: String) -> String?
    func invalidateAll()
}
```

### Ограничения
- HTML загрузится из кэша, но **JS файлы не загрузятся** (tracker.js, main.js грузятся по `<script src>` из сети)
- Без JS — in-app не работает, показывается пустая страница
- **Вывод: disk cache HTML сам по себе не решает offline**

---

## Стратегия 8: Offline — Service Worker / Cache API внутри WKWebView

**Статус:** Не реализовано

### Суть
Использовать Web Platform средства кэширования (Service Worker, Cache API) для кэширования JS файлов внутри WKWebView.

### Проблема
- `WKWebViewConfiguration.websiteDataStore = .nonPersistent()` — все кэши очищаются при уничтожении WKWebView
- Service Worker не работает с `nonPersistent()` data store
- Переход на `.default()` data store сохранит cookies и data между сессиями — потенциальный privacy concern

### Оценка
Не подходит без смены data store policy. Рискованное изменение.

---

## Стратегия 9: Offline — Native JS/Resource Cache

**Статус:** Не реализовано

### Суть
SDK скачивает `tracker.js` и `main.js` на диск. При загрузке HTML — инжектирует JS inline или через `WKURLSchemeHandler` для подмены сетевых URL на локальные файлы.

### Вариант A: Inline injection

```swift
// При предзагрузке:
let trackerJS = download("https://api.mindbox.ru/scripts/v1/tracker.js")
let mainJS = download("https://mobile-static.mindbox.ru/.../main.js")
saveToDisk(trackerJS, mainJS)

// При показе (offline):
var html = loadHTMLFromDiskCache(for: inAppId)
// Заменяем <script src="...tracker.js"> на <script>...inline code...</script>
html = injectInlineJS(html, trackerJS: trackerJS, mainJS: mainJS)
webView.loadHTMLString(html, baseURL: ...)
```

**Плюсы:**
- Полностью offline — HTML и JS из локального кэша
- Не требует изменений на стороне веба
- Простая реализация — string replacement в HTML

**Минусы:**
- Inline JS не попадает в JSC bytecode cache (теряем выигрыш Shared ProcessPool для JS)
- Нужно парсить HTML для замены `<script src>` → `<script>inline</script>`
- Версионирование: нужно обновлять при изменении `?v=` параметра

### Вариант B: WKURLSchemeHandler (Custom Protocol)

```swift
// Регистрируем кастомный протокол
config.setURLSchemeHandler(MindboxSchemeHandler(), forURLScheme: "mindbox-cache")

// Подменяем URL в HTML
html = html.replacingOccurrences(
    of: "https://api.mindbox.ru/scripts/v1/tracker.js",
    with: "mindbox-cache://tracker.js"
)

// MindboxSchemeHandler отдаёт файл из disk cache
class MindboxSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let data = loadFromDiskCache(urlSchemeTask.request.url!)
        urlSchemeTask.didReceive(URLResponse(...))
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
}
```

**Плюсы:**
- JS загружается "по URL" (хоть и кастомному) — **может** попасть в bytecode cache
- Чистая архитектура — подмена на уровне URL scheme, HTML почти не меняется
- Можно кэшировать любые ресурсы (картинки, шрифты, CSS)

**Минусы:**
- `WKURLSchemeHandler` не работает для `http://` / `https://` — только кастомные схемы
- Нужно менять URL в HTML перед загрузкой
- Bytecode cache для кастомных scheme — не гарантирован, нужно проверять
- Более сложная реализация

### Вариант C: WKContentWorld + URLProtocol interception

```swift
// Наследник URLProtocol перехватывает запросы к tracker.js / main.js
class CachingURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        // Перехватываем только известные JS URLs
        return isKnownJSUrl(request.url)
    }
    
    override func startLoading() {
        if let cached = diskCache.load(for: request.url!) {
            client?.urlProtocol(self, didLoad: cached)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            // Fallback to network
        }
    }
}
```

**Проблема:** `URLProtocol` не перехватывает запросы из WKWebView (они идут в отдельном процессе). Этот подход **не работает** для WKWebView.

### Рекомендация
**Вариант B (WKURLSchemeHandler)** — наиболее чистый и расширяемый. Позволяет кэшировать любые ресурсы и потенциально сохраняет bytecode cache.

---

## Стратегия 10: Offline — Full Page Snapshot + Deferred Interactivity

**Статус:** Не реализовано

### Суть
Pre-render все in-apps, сделать `WKWebView.takeSnapshot()`, сохранить UIImage на диск. При offline показе — показать snapshot как статичную картинку.

### Как работает
```
Online (background):
  Pre-render in-app → WKWebView.takeSnapshot() → save PNG to disk → destroy WKWebView

Offline:
  Trigger → load snapshot from disk → show as UIImageView (мгновенно)
  [Без интерактивности: кнопки не работают]

Online (если сеть появилась):
  За snapshot'ом поднять WKWebView → crossfade когда ready
```

### Что кэшируем
- `UIImage` snapshot: ~100-500KB per in-app (PNG на диск)

### Плюсы
- Мгновенный визуальный показ (0ms)
- Очень маленький footprint на диске
- Работает полностью offline

### Минусы
- **Нет интерактивности** — кнопки, формы, квизы не работают
- Snapshot устаревает если контент динамический
- Для неинтерактивных in-apps (баннер с одной кнопкой "Закрыть") — может быть приемлемо
- Для квизов/форм — неприемлемо

### Когда полезно
- Информационные in-apps без сложной интерактивности
- Как placeholder пока грузится полный webview

---

## Стратегия 11: Offline — MHTML / WebArchive

**Статус:** Не реализовано

### Суть
Использовать `WKWebView.createWebArchiveData()` (iOS 14+) для сохранения полного состояния страницы (HTML + JS + CSS + images) в один архив.

### Как работает
```swift
// Сохранение (после pre-render):
webView.createWebArchiveData { result in
    if case .success(let data) = result {
        saveToDisk(data, for: inAppId)  // ~200-500KB
    }
}

// Загрузка (offline):
let archiveData = loadFromDisk(for: inAppId)
webView.load(archiveData, mimeType: "application/x-webarchive",
             characterEncodingName: "utf-8", baseURL: baseURL)
```

### Плюсы
- **Полный offline** — все ресурсы в одном архиве
- Нативный API Apple — стабильно, поддерживается
- Интерактивность сохраняется (JS в архиве)
- Не нужно парсить HTML или подменять URL

### Минусы
- `createWebArchiveData` доступен с iOS 14+
- Архив может быть большим если есть картинки/шрифты (~200KB-2MB)
- JS в архиве может не инициализировать bridge корректно (нужно тестировать)
- WebContent process должен быть жив при создании архива (нельзя создать из data без WKWebView)
- Вопрос: будет ли JS bridge работать после загрузки из архива?

### Вопросы для исследования
- Работает ли bridge (postMessage) после загрузки из webarchive?
- Сохраняется ли состояние JS (инициализированный tracker)?
- Корректно ли отрабатывают динамические `<script src>` при загрузке из архива?

---

## Стратегия 12: Offline — Local HTTP Server

**Статус:** Не реализовано

### Суть
Поднять локальный HTTP-сервер (GCDWebServer или аналог) на устройстве, который отдаёт закэшированные ресурсы. WKWebView грузит страницу с `http://localhost:PORT/`.

### Как работает
```
SDK downloads:
  HTML → disk
  tracker.js → disk  
  main.js → disk

Local server:
  http://localhost:8080/inapp/{id}/index.html → disk HTML
  http://localhost:8080/scripts/tracker.js → disk tracker.js
  http://localhost:8080/scripts/main.js → disk main.js

WKWebView:
  loadRequest(URL("http://localhost:8080/inapp/{id}/index.html"))
```

### Плюсы
- Полный offline с интерактивностью
- URL-based loading → JSC bytecode cache работает
- Shared ProcessPool кэш работает
- Стандартный HTTP — WKWebView воспринимает как обычный сайт
- Можно отдавать правильные `Content-Type` и cache headers

### Минусы
- Зависимость от стороннего HTTP-сервера (GCDWebServer ~50KB)
- Background limitations — сервер не работает когда app suspended
- `http://` на iOS может блокироваться ATS (нужен `NSAllowsLocalNetworking` в Info.plist)
- Overhead на поддержание TCP listener
- Port collision потенциально возможен
- Review concern — Apple может спросить зачем HTTP-сервер в SDK

### Оценка
Мощный, но тяжёлый подход. Оправдан если offline — критическое требование и другие варианты не подошли.

---

## Стратегия 13: Offline — `loadFileURL` с локальными ресурсами

**Статус:** Не реализовано

### Суть
Сохранить HTML и все JS файлы в локальную директорию. Переписать HTML чтобы `<script src>` указывали на относительные пути. Загрузить через `webView.loadFileURL()`.

### Как работает
```
Disk structure:
  Library/Caches/MindboxWebView/
    inapp_123/
      index.html        (modified: script src → relative paths)
      tracker.js
      main.js

Loading:
  webView.loadFileURL(
    URL(fileURLWithPath: ".../inapp_123/index.html"),
    allowingReadAccessTo: URL(fileURLWithPath: ".../inapp_123/")
  )
```

### Плюсы
- Полный offline
- Нативный API, никаких зависимостей
- `file://` URL — JS загружается "по URL", потенциально bytecode cache работает
- Простая реализация

### Минусы
- Нужно переписывать пути в HTML (`https://...tracker.js` → `./tracker.js`)
- `file://` origin — CORS ограничения если JS делает сетевые запросы
- JS bridge может вести себя иначе с `file://` base URL
- `loadFileURL` требует `allowingReadAccessTo` — нужно правильно настроить sandboxing

### Оценка
Хороший баланс простоты и функциональности. Один из лучших вариантов для offline.

---

## ⭐ Стратегия 14: Warm WebView (рекомендуемая)

**Статус:** Не реализовано
**Приоритет:** Наивысший — заменяет стратегии 2, 4, 5, 6

### Ключевое наблюдение

HTML + JS **одинаковые** для всех in-apps. JS — это SPA-фреймворк, который рендерит разный контент в зависимости от payload, переданного через bridge. Это значит: **не нужно pre-render каждый in-app отдельно — достаточно прогреть один WebView и отправлять в него payload любого in-app.**

### Суть

Держим один pre-created WKWebView с загруженным HTML+JS в состоянии "ready". При триггере любого in-app — просто отправляем payload. Один WebView обслуживает все in-apps.

### Как работает

```
Phase 1 — Warm-up (фон, пользователь не видит):
  SDK получает конфиг → создаёт 1 WKWebView (offscreen)
  → loadHTMLString (одинаковый HTML)
  → JS загружает tracker.js + main.js
  → JS инициализируется, шлёт postMessage({ action: "ready", id: "xxx" })
  → SDK ДЕРЖИТ ready ID, НЕ отвечает
  → WebView в состоянии "warm" — JS живой, ждёт payload
  Время: ~1.5-2s в фоне

Phase 2 — Триггер (любой in-app):
  Триггер сработал → SDK отправляет payload в warm WebView:
    evaluateJavaScript("emit({ inAppId: 'A', customParams: {...}, ... })")
  → JS рендерит контент
  → Показ за ~0.3s
```

### Что экономим по сравнению с Pre-rendering

| | Pre-rendering (1 slot) | Warm WebView |
|---|---|---|
| WebView creation | 0ms | 0ms |
| HTML fetch | 0ms | 0ms |
| JS fetch + compile | 0ms | 0ms |
| JS bootstrap | 0ms | 0ms |
| **JS render payload** | **0ms (уже отрендерен)** | **~300ms** |
| **Hit rate** | **~30-50% (только priority)** | **100%** |
| **Время при miss** | **~2.2s (cold start)** | **— miss невозможен —** |
| Память | 30-50MB × N slots | 30-50MB × 1 |

### После закрытия in-app: Reusable vs Non-reusable JS

#### Вариант A: JS поддерживает повторный payload (reusable)

```
Закрытие InApp A → SDK скрывает WebView, НЕ уничтожает
  → SDK вызывает JS reset-метод → WebView снова "warm"
  → Триггер InApp B → emit(payload B) → показ за ~0.3s
```

**Один WebView на всю сессию. Гарантированные ~0.3s всегда.**

#### Вариант B: JS НЕ поддерживает повторный payload (non-reusable)

```
Закрытие InApp A → SDK уничтожает WebView → создаёт новый
  → Re-warm ~0.5-0.7s в фоне (bytecode cache через Shared ProcessPool)
  → WebView снова "warm" → готов к следующему триггеру
```

**Важно:** разница между вариантами — не просто 0.5s. Зависит от тайминга:

| Сценарий | Reusable (A) | Non-reusable (B) |
|---|---|---|
| Триггер InApp B **сразу** после закрытия A | **~0.3s** | **~2.2s** (re-warm не успел) |
| Триггер InApp B **через 2+ сек** после A | **~0.3s** | **~0.3s** (re-warm успел) |

В worst case разница: **0.3s vs 2.2s**. На практике между двумя in-apps обычно проходит достаточно времени, вариант B покрывает ~90%+ кейсов. Но вариант A надёжнее.

### Пример: 3 in-apps за сессию

```
Текущий подход (Pre-render InApp A):
  InApp A (hit)  → ~1.0s
  InApp B (miss) → ~2.2s
  InApp C (miss) → ~2.2s
  Hit rate: 33%

Warm WebView:
  InApp A → ~0.3s
  InApp B → ~0.3s
  InApp C → ~0.3s
  Hit rate: 100%
```

### Кроссплатформенность (Android)

Стратегия 1-в-1 переносится на Android:
- Pre-create `WebView` → загрузить HTML+JS → держать ready
- При триггере: `evaluateJavascript("emit(payload)")`
- V8 bytecode cache работает аналогично JSC
- `WebView` на Android легче по памяти чем `WKWebView`
- На Android `shouldInterceptRequest` проще чем `WKURLSchemeHandler` для offline

### Открытый вопрос (блокер)

**Может ли JS принять payload повторно без перезагрузки HTML?** Нужно уточнить у фронтенд-команды. Определяет выбор между вариантом A и B.

### Реализация

```swift
class WarmWebViewHolder {
    private var webView: WKWebView?
    private var pendingReadyId: UUID?
    
    /// Phase 1: вызывается после получения конфига
    func warmUp(html: String) {
        let wv = createWebView()  // shared ProcessPool
        wv.loadHTMLString(html, baseURL: baseURL)
        // JS отправит "ready" → сохраняем pendingReadyId
        webView = wv
    }
    
    /// Phase 2: вызывается при триггере любого in-app
    func deliver(payload: InAppPayload) -> WKWebView? {
        guard let wv = webView, let readyId = pendingReadyId else { return nil }
        facade.sendReadyEvent(id: readyId, payload: payload)
        pendingReadyId = nil
        return wv
    }
    
    /// Phase 3A (reusable): после закрытия
    func reset() {
        evaluateJavaScript("window.resetInApp()")
        // JS очищает контент, шлёт новый "ready"
    }
    
    /// Phase 3B (non-reusable): после закрытия
    func rewarm(html: String) {
        webView?.removeFromSuperview()
        webView = nil
        warmUp(html: html)  // bytecode cache ускорит до ~0.5s
    }
}
```

---

## Сводная таблица

### Goal 1: Ускорение показа (Pre-loading)

| # | Стратегия | Экономия | Память | Сложность | Статус | Приоритет |
|---|-----------|----------|--------|-----------|--------|-----------|
| **14** | **Warm WebView** | **~1.9s (100% hit)** | **30-50MB × 1** | **Средняя** | **Идея** | **⭐ Наивысший** |
| 1 | HTML Pre-cache | ~200-1000ms | ~KB | Низкая | Готово | Базовый |
| 3 | Shared ProcessPool | ~250ms (2-й+) | 0 (экономия) | Низкая | Прототип | Высокий |
| 2 | Pre-rendering (1 slot) | ~1.25s | ~30-50MB | Средняя | Готово | Заменяется #14 |
| 4 | Pre-rendering Pool (N) | ~1.25s × N | N × 10-15MB* | Низкая | Прототип | Заменяется #14 |
| 5 | JS Pre-warming | ~300-500ms | ~30-50MB | Средняя | Идея | Заменяется #14 |
| 6 | Predictive Pre-render | ~1.25s (smart) | ~30-50MB | Высокая | Идея | Заменяется #14 |

*С shared process pool

### Goal 2: Offline

| # | Стратегия | Полный offline | Интерактивность | Сложность | Рекомендация |
|---|-----------|---------------|-----------------|-----------|-------------|
| 7 | Disk HTML Cache | Нет (JS не грузится) | - | Низкая | Недостаточно |
| 8 | Service Worker | Нет (nonPersistent) | - | Высокая | Не подходит |
| 9A | Native JS Cache (inline) | Да | Да | Средняя | Возможно |
| 9B | WKURLSchemeHandler | Да | Да | Средняя | **Рекомендуется** |
| 10 | Snapshot | Да | Нет | Средняя | Для баннеров |
| 11 | WebArchive | Да | Нужно тестировать | Низкая | **Исследовать** |
| 12 | Local HTTP Server | Да | Да | Высокая | Overkill |
| 13 | loadFileURL | Да | Да | Средняя | **Рекомендуется** |

---

## Рекомендуемый план

### Phase 1 — Warm WebView (наивысший приоритет)
1. **Уточнить у фронтенд-команды:** может ли JS принять повторный payload без перезагрузки? (блокер для выбора варианта A/B)
2. **Реализовать Warm WebView (Стратегия 14)** — один прогретый WebView, payload любого in-app при триггере
3. **Shared ProcessPool (Стратегия 3)** — ускоряет re-warm в варианте B, уже в прототипе
4. Заменяет стратегии 2, 4, 5, 6 — pre-rendering отдельных in-apps больше не нужен

### Phase 2 — Offline (исследование)
1. **WebArchive (Стратегия 11)** — самый простой эксперимент: pre-render → `createWebArchiveData()` → save → load offline. Проверить работает ли bridge
2. **loadFileURL (Стратегия 13)** — если WebArchive не работает: скачать HTML + JS на диск, переписать пути, загрузить через `loadFileURL`
3. **WKURLSchemeHandler (Стратегия 9B)** — если loadFileURL имеет проблемы с CORS/bridge: кастомная схема с полным контролем

### Phase 3 — Fallback (если Warm WebView невозможен)
1. **Pre-rendering Pool (Стратегия 4)** + Shared ProcessPool — вернуться к текущему подходу с оптимизациями
2. **Predictive Pre-render (Стратегия 6)** — если данные покажут паттерны в показе in-apps

---

## Открытые вопросы

1. **⭐ [БЛОКЕР] Может ли JS принять повторный payload без перезагрузки HTML?** — определяет reusable (A) vs non-reusable (B) вариант Warm WebView. Уточнить у фронтенд-команды.
2. Работает ли JSC bytecode cache с `nonPersistent()` data store в рамках shared process pool?
3. Сохраняется ли bridge/interactivity после загрузки из WebArchive?
4. Какой реальный memory footprint WKWebView в shared vs separate process pool?
5. Какая доля пользователей показывает 2+ webview in-apps за сессию? (влияет на ценность re-warm)
6. Может ли бэк отдавать URL скриптов (tracker, main) в конфиге для более надёжного кэширования?
