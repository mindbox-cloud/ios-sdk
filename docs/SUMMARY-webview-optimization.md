# WebView In-App: Оптимизация и Offline — Саммари для команды

**Дата:** 2026-04-09
**Цель:** Ускорить показ WebView in-app + поддержать offline. iOS и Android.

---

## Проблема

Текущее время показа WebView in-app: **~2.0-2.5 сек**. Каждый показ проходит полный цикл:

```
Создать WKWebView → Скачать HTML (сеть) → Скачать tracker.js + main.js (сеть)
→ Parse/Compile JS → Инициализация bridge → Получить payload → Рендер → Показ
```

Без сети in-app вообще не покажется.

---

## Ключевое наблюдение

> **HTML + JS одинаковые для всех webview in-apps.**
> JS — SPA-фреймворк. Контент определяется payload'ом через bridge (`inAppId`, `params`, `formId`).
> HTML — bootstrap-шаблон, загружающий `tracker.js` + `main.js`.

Это позволяет **один прогретый WebView переиспользовать для любого in-app**, а не рендерить каждый отдельно.

**Статус:** Требует подтверждения от фронтенд-команды.

---

## Часть 1: Ускорение показа

### Рекомендуемая стратегия: Warm WebView

**Суть:** Держим один WebView с загруженным HTML+JS в состоянии "ready". При триггере любого in-app — отправляем payload. Один WebView обслуживает все in-apps.

**Фазы работы:**

| Фаза | Что происходит | Когда |
|------|---------------|-------|
| Warm-up | SDK создает WKWebView offscreen, загружает HTML+JS, JS шлет `ready` — SDK **не отвечает**, держит ID | После получения конфига (фон, ~1.5-2s) |
| Триггер | SDK отправляет payload в warm WebView через bridge | По событию пользователя |
| Показ | JS рендерит контент → `init` → окно видимо | ~0.3s после триггера |
| Re-warm | После закрытия — подготовить новый warm WebView | Фон, ~0.5-0.7s (bytecode cache) |

### Замеры (реальное устройство, симулятор iPhone 16)

Замеры `timeToDisplay` (= processingTime + presentationTime), 4 прогона на один inapp:

#### develop (cold start, без оптимизации)

| # | processingTime | presentationTime | timeToDisplay |
|---|---------------|-----------------|---------------|
| 1 | 16.5ms | 2336ms | 2353ms |
| 2 | 10.4ms | 2333ms | 2343ms |
| 3 | 15.9ms | 2178ms | 2194ms |
| 4 | 13.2ms | 2379ms | 2392ms |
| **avg** | **14ms** | **2307ms** | **2321ms** |

#### feature/MOBILE-0000-MVP-CachedWebView (warm hit — тот же inapp)

| # | processingTime | presentationTime | timeToDisplay |
|---|---------------|-----------------|---------------|
| 1 | 16.2ms | 1105ms | 1121ms |
| 2 | 15.8ms | 1252ms | 1267ms |
| 3 | 15.0ms | 1293ms | 1308ms |
| 4 | 14.2ms | 1084ms | 1098ms |
| **avg** | **15ms** | **1184ms** | **1199ms** |

#### feature — cache miss (другой inapp, warm WebView занят)

| # | processingTime | presentationTime | timeToDisplay |
|---|---------------|-----------------|---------------|
| 1 | 15.4ms | 1763ms | 1778ms |

#### Итоговое сравнение

| Сценарий | timeToDisplay | vs develop | Источник выигрыша |
|----------|--------------|------------|-------------------|
| develop (cold) | **2321ms** | baseline | — |
| feature, warm hit | **1199ms** | **−48% / −1.12s** | HTML cache + pre-warmed WebView |
| feature, cache miss | **1778ms** | **−24% / −0.54s** | HTML cache (без fetch по сети) |

`processingTime` (~14-16ms) не изменился — вся оптимизация в `presentationTime`.

### Что SDK уже не может оптимизировать

| Шаг | Время | Почему |
|-----|-------|--------|
| JS рендер после payload | ~300-970ms | Это логика на стороне веба. SDK передал payload — дальше JS рисует. |

### Два варианта после закрытия in-app

| | Вариант A: JS reusable | Вариант B: JS не reusable |
|---|---|---|
| Что происходит | SDK скрывает WebView, вызывает `reset()`, WebView снова warm | SDK уничтожает WebView, создает новый (re-warm ~0.5-0.7s) |
| Следующий in-app | **~0.3s всегда** | ~0.3s если прошло >1s, иначе cold ~2.2s |
| Доработка фронта | Нужен метод `reset()` в JS | Не нужна |

**Вариант A предпочтительнее**, но зависит от возможностей JS-фреймворка.

### Сопутствующие оптимизации (уже реализованы/в прототипе)

| Оптимизация | Что дает | Статус |
|-------------|---------|--------|
| HTML Pre-cache | HTML скачивается в память сразу после конфига, а не при показе | Готово |
| Shared WKProcessPool | Один процесс для всех WebView → HTTP cache + JSC bytecode cache для JS | Прототип |

---

## Часть 2: Offline

### Проблема

HTML можно закэшировать на диск, но `tracker.js` и `main.js` загружаются по `<script src="...">` из сети. Без них in-app — пустая страница.

### Рекомендуемые варианты (в порядке приоритета для исследования)

#### 1. WebArchive (iOS 14+) — самый простой эксперимент

```
Online: Pre-render in-app → webView.createWebArchiveData() → сохранить на диск
Offline: Загрузить архив → полная страница с JS и интерактивностью
```

- **Плюсы:** Нативный API Apple, все ресурсы в одном файле (~200-500KB), интерактивность сохраняется
- **Минусы:** Нужно проверить — работает ли bridge после загрузки из архива?
- **Android-аналог:** `WebView.saveWebArchive()` — аналогичный подход

#### 2. loadFileURL — скачать все на диск

```
SDK скачивает HTML + tracker.js + main.js → сохраняет в Library/Caches/
Переписывает <script src> на относительные пути
webView.loadFileURL(localHTML, allowingReadAccessTo: cacheDir)
```

- **Плюсы:** Полный offline, нативный API, JSC bytecode cache потенциально работает
- **Минусы:** Нужно модифицировать HTML; `file://` origin может вызвать CORS-проблемы
- **Android-аналог:** `WebView.loadUrl("file:///...")` — проще, нет CORS-ограничений

#### 3. WKURLSchemeHandler — кастомная схема

```
Регистрируем mindbox-cache:// scheme
Подменяем URL скриптов в HTML: https://...tracker.js → mindbox-cache://tracker.js
SchemeHandler отдает файлы из disk cache
```

- **Плюсы:** Чистая архитектура, кэширует любые ресурсы, URL-based → bytecode cache
- **Минусы:** Только для кастомных схем (не перехватывает https://), более сложная реализация
- **Android-аналог:** `WebViewClient.shouldInterceptRequest()` — нативно перехватывает любой URL, проще чем на iOS

### Варианты, которые НЕ подходят

| Вариант | Почему не подходит |
|---------|-------------------|
| Disk cache только HTML | JS не загрузится → пустая страница |
| Service Worker / Cache API | Не работает с `nonPersistent()` data store |
| URLProtocol interception | Не перехватывает запросы из WKWebView (отдельный процесс) |
| Local HTTP Server | Overkill: зависимость от GCDWebServer, ATS, port collision, вопросы на ревью Apple |

---

## Часть 3: Кроссплатформенность (Android)

### Warm WebView — переносится 1-в-1

| Аспект | iOS | Android |
|--------|-----|---------|
| WebView | `WKWebView` | `WebView` |
| Прогрев | `loadHTMLString` | `loadDataWithBaseURL` |
| Отправка payload | `evaluateJavaScript` | `evaluateJavascript` |
| Bytecode cache | JSC через Shared ProcessPool | V8 (встроенный кэш) |
| Память | ~30-50MB | Легче, чем на iOS |

### Offline — на Android проще

- `WebViewClient.shouldInterceptRequest()` нативно перехватывает **любой** URL (включая https://) — не нужен custom scheme
- SDK перехватывает запросы к `tracker.js` и `main.js`, отдает из disk cache
- Самый чистый вариант для Android

---

## Доработки на стороне фронта

| Доработка | Зачем | Приоритет |
|-----------|-------|-----------|
| Подтвердить: HTML+JS одинаковые для всех in-apps | Блокер для Warm WebView. Если нет — стратегия не работает | **Блокер** |
| Метод `reset()` для очистки состояния | Вариант A: переиспользовать WebView без пересоздания | Высокий |
| Оптимизация JS рендера (ready→init) | Сейчас ~300-970ms — единственное узкое место после warm | Средний |
| Отдавать URL скриптов в конфиге | Более надежное кэширование (версионирование, инвалидация) | Низкий |

---

## Стратегии при разных HTML+JS шаблонах

Текущая архитектура держится на допущении: **все webview in-app'ы шарят один HTML+JS**. Если это не так:

| Стратегия | Суть | Hit rate | Память | Когда применять |
|-----------|------|----------|--------|-----------------|
| **Pool warm WebViews** | Один warm WebView на каждый уникальный contentUrl | 100% | N × 50MB | N ≤ 3 шаблонов |
| **Claim + URL check** | claim() проверяет совпадение URL; промах → cold start + async rewarm нужного URL | ~50-80% | 50MB | Универсально, низкая сложность |
| **HTML cache only** | Отказаться от pre-warming, оставить только WebViewContentCache | 0% (WV) | ~0 | Универсально, уже работает как fallback |

HTML cache (−24% от baseline) работает всегда как страховка независимо от стратегии.

---

## Открытые вопросы

| # | Вопрос | Кому | Влияние |
|---|--------|------|---------|
| 1 | **Одинаковые ли HTML+JS для всех webview in-apps?** | Фронт | **Блокер** — определяет, работает ли Warm WebView |
| 2 | **Может ли JS принять payload повторно (reset)?** | Фронт | Определяет вариант A vs B |
| 3 | Работает ли bridge после загрузки из WebArchive? | Исследование (SDK) | Определяет подход к offline |
| 4 | Работает ли JSC bytecode cache с `nonPersistent()` dataStore? | Исследование (SDK) | Влияет на скорость re-warm |
| 5 | Может ли бэк отдавать URL скриптов в конфиге? | Бэкенд | Надежность offline-кэша |
| 6 | Какая доля пользователей видит 2+ in-apps за сессию? | Аналитика | Ценность re-warm |

---

## Рекомендуемый план действий

### Phase 1 — Warm WebView (ускорение)
1. Уточнить у фронта вопросы 1 и 2 (блокеры)
2. Реализовать Warm WebView (iOS) — MVP уже на ветке `feature/MOBILE-0000-MVP-CachedWebView`
3. Реализовать Warm WebView (Android)
4. Shared ProcessPool для ускорения re-warm (прототип готов)

### Phase 2 — Offline (исследование)
1. Эксперимент с WebArchive (iOS) — проверить bridge
2. Эксперимент с `shouldInterceptRequest` (Android) — перехват JS
3. Если WebArchive не работает → loadFileURL / WKURLSchemeHandler (iOS)

### Phase 3 — Оптимизация JS-рендера (фронт)
1. Профилировать JS render time (~300-970ms)
2. Рассмотреть SSR / pre-build контента на стороне бэка

---

## Метрики для отслеживания

| Метрика | develop (baseline) | feature (warm hit) | feature (cache miss) | Целевое |
|---------|-------------------|-------------------|---------------------|---------|
| `timeToDisplay` | 2321ms | **1199ms (−48%)** | 1778ms (−24%) | <500ms |
| `presentationTime` | 2307ms | 1184ms | 1763ms | — |
| `processingTime` | 14ms | 15ms | 15ms | — |
| Hit rate | ~33% | 100% | — | 100% |
| Offline-показ | Невозможен | Невозможен | Невозможен | Работает |
| Доп. память | 0 | ~30-50MB | ~30-50MB | ~30-50MB |
