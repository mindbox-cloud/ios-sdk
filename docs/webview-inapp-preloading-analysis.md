# Анализ: предзагрузка и кэширование WebView In-App

> Дата анализа: 2026-04-06
> Цель: мгновенный показ WebView in-app после триггера + безусловный показ по требованию
> Контекст: подготовка к будущей фиче Stories (WebView + JS)

## Текущий флоу (что занимает 2+ секунды)

```
Триггер (operation)
  → Таргетинг + выбор in-app (~100-500ms, зависит от сети для segments/geo)
  → Schedule + delay
  → Создание UIWindow + WebViewController
  → Создание WKWebView (nonPersistent, каждый раз новый)
  → Fetch HTML по contentUrl (ephemeral URLSession, без кэша)
  → WKWebView.loadHTMLString() — парсинг + рендеринг HTML/CSS/JS
  → JS bridge ready handshake
  → Native отправляет init payload → JS рисует UI
  → Показ (window.alpha = 1.0)
```

### Основные узкие места

| Этап | Время | Причина |
|------|-------|---------|
| Fetch HTML | 200-1000ms | Сетевой запрос, ephemeral сессия, кэш отключен намеренно |
| WKWebView init + рендеринг | 300-800ms | Создание нового WKWebView каждый раз |
| JS bridge handshake | 100-300ms | evaluateJavaScript + ready event round-trip |
| Таргетинг | 100-500ms | Зависимости: segments, geo, сеть |

## Ключевые архитектурные ограничения

1. **Намеренно отключен кэш** — `MindboxWebViewFacade.swift:315-317`:
   ```swift
   config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
   config.urlCache = nil
   ```

2. **Non-persistent WebView** — `MindboxWebViewFacade.swift:90`:
   ```swift
   config.websiteDataStore = .nonPersistent()
   ```

3. **Блокировка в бэкграунде** — `InappScheduleManager.swift:63`:
   ```swift
   if UIApplication.shared.applicationState == .background { return }
   ```

4. **contentUrl известен только после выбора in-app** — URL приходит из конфига, который маппится после таргетинга

5. **Init payload содержит динамические данные** — operation name/body, permissions, insets, trackVisit — формируется в момент показа

## Что реально предзагрузить

### 1. HTML контент (index.html + встроенный JS/CSS)

**Сейчас:** `contentUrl` загружается каждый раз при показе через ephemeral URLSession.

**Можно:** После получения конфига (`prepareConfiguration`) — пройтись по всем WebView in-app'ам и закэшировать HTML по их `contentUrl`. Конфиг уже содержит все `contentUrl` для всех in-app'ов.

**Где взять URLs раньше:** `ConfigResponse` → `inapps.elements` → каждый `InAppDTO` → layers → `WebviewContentBackgroundLayerDTO.contentUrl`

**Реализация:**
```
Mindbox.init → fetchConfig → parse ConfigResponse
  → извлечь все contentUrl из webview-слоёв
  → скачать HTML для каждого → сохранить в memory/disk cache
  → при показе: проверить кэш → если есть, использовать; если нет, fetch как сейчас
```

**Выигрыш:** ~200-1000ms (убираем сетевой запрос при показе)

**Сложность:** Низкая. Нужен `WebViewContentCache` + изменение в `fetchHTML()`.

### 2. Пре-создание WKWebView ("warm pool")

**Сейчас:** Каждый показ создаёт новый `WKWebView(frame:configuration:)`.

**Можно:** Создать 1-2 WKWebView заранее и держать в пуле. При показе — взять готовый.

**Нюанс:** WKWebView должен создаваться на main thread. Можно создать после `Mindbox.init` на main.

**Выигрыш:** ~100-300ms (инициализация WebKit процесса уже произошла)

**Сложность:** Средняя. Нужно учитывать lifecycle, утечки памяти, и то что `nonPersistent` data store создаётся per-webview.

### 3. Пре-рендеринг HTML в скрытом WebView

**Сейчас:** HTML загружается и рендерится только после триггера.

**Можно:** После получения конфига — загрузить HTML в скрытый WKWebView, пройти full render до состояния "JS bridge ready". Затем при триггере — отправить только init payload и показать.

**Выигрыш:** ~500-1500ms (убираем fetch + parse + render + bridge init)

**Сложность:** Высокая. Проблемы:
- Не знаем какой именно in-app покажется (зависит от таргетинга в момент триггера)
- Init payload содержит `operationName`, `operationBody` — неизвестны до триггера
- Нужна возможность "доотправить" init данные уже в готовый WebView
- Для этого нужно изменить JS-протокол: разделить `ready` на два этапа (pre-init + final-init)

### 4. Popup Forms (для Stories)

Popup forms загружаются отдельно от WebView. Для сториз, если они будут webview+js, popup forms можно закэшировать аналогично HTML контенту.

## Требование: мгновенный показ после триггера

**Оптимальная стратегия (поэтапная):**

### Этап 1 — Кэш HTML (Quick Win)
- После `fetchConfig` → скачать все `contentUrl` в фоне
- При показе: брать из кэша вместо сетевого запроса
- **Время показа: ~1-1.5с** (вместо 2+)

### Этап 2 — Warm WebView Pool
- Создать 1 WKWebView заранее
- При показе: переиспользовать уже инициализированный
- **Время показа: ~0.5-1с**

### Этап 3 — Пре-рендеринг (для Stories)
- Изменить JS-протокол: `preload` (без operation data) → `activate` (с operation data)
- После конфига: загрузить top-N in-app'ов в скрытые WebView
- При триггере: выбрать подходящий → отправить activate → показать
- **Время показа: ~100-200ms**

## Требование: безусловный показ по требованию

Сейчас показ привязан к `sendEvent()` → таргетинг → выбор. Для безусловного показа нужно:

1. **Новый публичный API:**
   ```swift
   Mindbox.shared.showInApp(id: "inapp-id")  // или showStory
   ```

2. **Обход таргетинга** — прямой вызов `presentationManager.present()` с заданным `InAppFormData`

3. **Нужен доступ к данным in-app'а по ID** — из закэшированного конфига

**Сложность:** Средняя. Основная работа — новый entry point, минуя `InAppCoreManager.sendEvent()`.

## Требование: показ в бэкграунде

**Проблема:** iOS не позволяет показывать UI в бэкграунде. `UIWindow` не будет видим.

**Варианты:**
- **"Подготовить в бэкграунде, показать при foreground"** — закэшировать/пре-рендерить, показать мгновенно при возвращении в foreground. Это реалистично.
- **Push notification с rich content** — для срочных сообщений.
- **Для stories:** кэшировать контент в бэкграунде, при клике на кружочек — показать мгновенно из кэша.

## Для будущих Stories (WebView + JS)

Архитектура хорошо ложится на stories:

1. **Кружочки (preview):** загрузить картинки/metadata из конфига, показать нативно
2. **Клик в кружочек → показ story:** по `inAppId` из кэша взять пре-рендеренный WebView → показать за ~100-200ms
3. **JS bridge** уже поддерживает всё нужное: local state, haptic, motion, operations, navigation
4. **Нужно добавить:** горизонтальный swipe между stories (на уровне native контейнера)

## Что нужно изменить (сводная таблица)

| Компонент | Изменение | Сложность |
|-----------|-----------|-----------|
| `MindboxWebViewFacade.fetchHTML()` | Добавить cache layer перед сетевым запросом | Низкая |
| Новый `WebViewContentCache` | Кэш HTML по contentUrl (memory + disk) | Низкая |
| `InAppConfigurationManager` | После парса конфига → запустить предзагрузку контента | Низкая |
| Новый `WebViewPool` | Пул пре-созданных WKWebView | Средняя |
| JS протокол | Разделить ready на preload/activate (для этапа 3) | Высокая (координация с фронтом) |
| `InAppCoreManager` | Новый метод `showInApp(id:)` для безусловного показа | Средняя |
| `InappScheduleManager` | Убрать background-блокировку для prepared inapps | Низкая |
| `WebViewController` | Поддержка переиспользования из пула | Средняя |

## Вывод

Предзагрузка реализуема поэтапно. Этап 1 (кэш HTML) даёт быстрый результат с минимальными изменениями. Этапы 2-3 нужны для stories и мгновенного показа за <200ms. Основной блокер этапа 3 — изменение JS-протокола (координация с бэкендом/фронтом).

## Ключевые файлы

| Файл | Роль |
|------|------|
| `Mindbox/InAppMessages/InAppCoreManager.swift` | Entry point, роутинг событий |
| `Mindbox/InAppMessages/Configuration/InAppConfigurationManager.swift` | Загрузка/кэш конфига |
| `Mindbox/InAppMessages/InAppConfigurationMapper/InappMapper.swift` | Таргетинг + выбор in-app |
| `Mindbox/InAppMessages/InappScheduleManager.swift` | Планировщик показа |
| `Mindbox/InAppMessages/Presentation/Views/WebView/WebViewController.swift` | ViewController для WebView |
| `Mindbox/InAppMessages/Presentation/Views/WebView/TransparentView.swift` | Lifecycle WebView + bridge handling |
| `Mindbox/InAppMessages/Presentation/Views/WebView/Debug/MindboxWebViewFacade.swift` | WKWebView конфиг + fetch HTML + init payload |
| `Mindbox/InAppMessages/Presentation/Views/WebView/Bridge/MindboxWebBridge.swift` | JS bridge коммуникация |
| `Mindbox/InAppMessages/Presentation/Views/WebView/Bridge/BridgeMessage.swift` | Протокол сообщений |
| `Mindbox/InAppMessages/Models/.../WebviewContentBackgroundLayer.swift` | Модель WebView слоя (baseUrl, contentUrl, params) |
| `Mindbox/InAppMessages/Models/InAppFormData.swift` | Данные для показа in-app |
