# WebView In-App: Offline — Результаты экспериментов

**Дата:** 2026-04-13
**Ветка:** `feature/MOBILE-0000-MVP-CachedWebView`
**Цель:** Показать webview in-app без интернета (offline).

---

## Исходные данные

- HTML-шаблон скачивается по `contentUrl` и содержит **inline JS** (tracker.js и main.js встроены в HTML, а не загружаются через `<script src="https://...">`)
- JS — SPA-фреймворк. После загрузки отправляет `ready` через bridge, получает payload (inAppId, params, operation), рендерит контент и отправляет `init`
- Конфиг (`ConfigResponse`) уже кэшируется на диск и доступен offline (с учётом TTL)

---

## Подход 1: WebArchive (iOS 14+)

### Идея

```
Online:  WarmWebViewHolder warm-up → JS ready → webView.createWebArchiveData() → сохранить на диск
Offline: webView.load(archiveData, mimeType: "application/x-webarchive") → JS из архива → ready → bridge
```

### Реализация

- `WebViewArchiveCache` — disk cache для WebArchive data (keyed by contentUrl)
- `MindboxWebViewFacade.createWebArchive()` — обёртка над `WKWebView.createWebArchiveData()`
- Триггер создания архива в `WarmWebViewHolder.onReadyInPreloadMode`
- Fallback в `loadHTML`: если HTML cache miss + network fail → пробуем WebArchive

### Результат: не работает

**Причина:** `createWebArchiveData()` с `nonPersistent()` dataStore не захватывает подресурсы.

Архив получился **10 238 байт** — это только HTML-шаблон без JS-ресурсов. При загрузке из архива:
- HTML загружается
- Если бы были внешние `<script src>` — они бы не загрузились (не в архиве, сети нет)
- Но скрипты оказались inline → JS загрузился → `ready` пришёл
- SDK отправил payload → JS получил
- **JS не смог отрендерить контент** → `init` не пришёл → timeout

### Вывод

WebArchive не решает проблему. Даже если бы архив захватывал все ресурсы — проблема в рендеринге после payload, а не в загрузке JS.

---

## Подход 2: WKURLSchemeHandler (`mindbox-cache://`)

### Идея

```
Online:  Скачать HTML → распарсить <script src="https://..."> → скачать JS файлы на диск
         Подменить в HTML: https://cdn/tracker.js → mindbox-cache://cdn/tracker.js
Offline: loadHTMLString(rewrittenHTML) → WKURLSchemeHandler перехватывает mindbox-cache:// → отдаёт JS с диска
```

### Реализация

- `WebViewJSCache` — disk cache для JS-файлов (`Library/Caches/com.mindbox.webview-js/`)
- `MindboxCacheSchemeHandler` — `WKURLSchemeHandler` для `mindbox-cache://`, отдаёт файлы из `WebViewJSCache`
- `HTMLScriptURLRewriter` — regex замена `<script src="https://...">` → `<script src="mindbox-cache://...">`
- `WebViewContentCache` — расширен disk-слоем для HTML (переживает перезапуск приложения)
- `WebViewContentPreloader` — после скачивания HTML парсит script URL-ы и скачивает JS на диск
- Регистрация scheme handler в `MindboxWebViewFacade` на `WKWebViewConfiguration`

### Результат: не применимо

**Причина:** HTML-шаблон содержит **inline JS**, а не `<script src="https://...">`.

Rewriter не нашёл ни одного внешнего script-тега → scheme handler ни разу не вызвался. Подход решает проблему загрузки внешних JS-файлов, но в текущей архитектуре фронта эта проблема не существует.

При этом offline-поведение идентично подходу 1:
- HTML загружен с диска (disk cache работает) ✅
- JS исполнился (inline) ✅
- `ready` пришёл ✅
- Payload отправлен и доставлен ✅
- **JS не смог отрендерить контент** → `init` не пришёл → timeout ❌

### Вывод

WKURLSchemeHandler корректно решает задачу offline-загрузки внешних JS, но в текущей архитектуре это не нужно. Реальная проблема — на этапе рендеринга.

---

## Общий вывод

### Что работает offline (SDK-сторона)

| Компонент | Статус | Механизм |
|-----------|--------|----------|
| Config (ConfigResponse) | ✅ | Disk cache + TTL валидация |
| HTML-шаблон | ✅ | `WebViewContentCache` с disk-слоем |
| JS (inline) | ✅ | Встроен в HTML |
| Bridge (ready → payload) | ✅ | WKScriptMessageHandler работает |
| Payload delivery | ✅ | `evaluateJavaScript` — локальная операция |

### Что не работает offline (JS-сторона)

| Компонент | Статус | Проблема |
|-----------|--------|----------|
| Рендеринг после payload | ❌ | JS не отправляет `init` без сети |

### Блокер

**JS-фреймворк не может отрендерить in-app контент offline.** После получения payload JS пытается загрузить ресурсы (картинки, шрифты, данные?) с CDN, и без сети рендеринг не завершается — `init` event никогда не приходит.

### Необходимые действия

Вопрос к фронт-команде:
1. Что JS делает между получением payload и отправкой `init`?
2. Какие сетевые запросы выполняются при рендеринге? (картинки, шрифты, API?)
3. Можно ли рендерить in-app полностью из payload без сети?
4. Можно ли добавить timeout-логику: если ресурсы не загружены за N секунд — показать контент без них?

---

## Побочные результаты (полезные)

Независимо от offline, реализованные изменения дают:

1. **HTML disk cache** — HTML переживает перезапуск приложения. Warm-up после перезапуска не зависит от сети для HTML (только для JS-рендеринга).
2. **WKURLSchemeHandler инфраструктура** — готова к использованию если архитектура фронта изменится на внешние script-файлы.
3. **JS disk cache** — готов для кэширования любых ресурсов через `mindbox-cache://` схему.
