# Контракт JS ↔ Native: `permission.request`

## Общая схема

Общение строится на `BridgeMessage` — единой обёрточной структуре для всех сообщений между JS и Native. Каждое сообщение содержит:

| Поле        | Тип          | Описание                                                                 |
|-------------|--------------|--------------------------------------------------------------------------|
| `version`   | `Int`        | Версия протокола                                                         |
| `type`      | `String`     | `"request"` / `"response"` / `"error"`                                   |
| `action`    | `String`     | Имя действия                                                             |
| `payload`   | `JSON string`| Тело сообщения (JSON-строка, которую принимающая сторона парсит через `JSON.parse`) |
| `id`        | `UUID`       | Уникальный идентификатор запроса (lowercase)                             |
| `timestamp` | `Int64`      | Unix-время в миллисекундах                                               |

Action `permission.request` входит в набор **deferred actions** — Native сам формирует и отправляет ответ (диспетчер не шлёт авто-ответ).

---

## 1. JS → Native: Request

JS отправляет сообщение с `action = "permission.request"`:

```json
{
  "version": 1,
  "type": "request",
  "action": "permission.request",
  "payload": "{\"type\":\"pushNotifications\"}",
  "id": "a1b2c3d4-e5f6-...",
  "timestamp": 1710340800000
}
```

**Payload** (после `JSON.parse`) — объект с единственным обязательным полем:

| Поле   | Тип      | Допустимые значения | Описание                        |
|--------|----------|---------------------|---------------------------------|
| `type` | `string` | см. таблицу ниже    | Тип запрашиваемого разрешения   |

### Допустимые значения `type`

| Значение             | Описание                          |
|----------------------|-----------------------------------|
| `"pushNotifications"`| Push-уведомления                  |
| `"location"`         | Геолокация (When In Use)          |
| `"camera"`           | Камера                            |
| `"microphone"`       | Микрофон                          |
| `"photoLibrary"`     | Фотобиблиотека                    |
| `"att"`              | App Tracking Transparency         |
| `"contacts"`         | Контакты                          |
| `"bluetooth"`        | Bluetooth                         |

---

## 2. Native → JS: Response (успех)

Если разрешение обработано успешно, Native отправляет `type = "response"` с тем же `id`:

```json
{
  "version": 1,
  "type": "response",
  "action": "permission.request",
  "payload": "{\"status\":\"granted\",\"dialogShown\":true}",
  "id": "a1b2c3d4-e5f6-...",
  "timestamp": 1710340800500
}
```

**Payload** — объект с полями:

| Поле          | Тип      | Описание                                                                 |
|---------------|----------|--------------------------------------------------------------------------|
| `status`      | `string` | `"granted"` / `"denied"`                                                 |
| `dialogShown` | `bool`   | `true` — системный диалог был показан пользователю; `false` — диалог не показывался (статус уже был определён ранее) |

### Матрица значений

| Сценарий                          | `status`    | `dialogShown` | Что произошло                                            |
|-----------------------------------|-------------|---------------|----------------------------------------------------------|
| Первый запрос → пользователь разрешил  | `"granted"` | `true`        | Системный диалог показан, пользователь нажал "Allow"     |
| Первый запрос → пользователь отклонил  | `"denied"`  | `true`        | Системный диалог показан, пользователь нажал "Don't Allow"|
| Повторный запрос, уже разрешено        | `"granted"` | `false`       | Разрешение уже было дано, диалог не показывался          |
| Повторный запрос, уже отклонено        | `"denied"`  | `false`       | Разрешение уже отклонено, диалог не показывался          |

JS может использовать эту комбинацию для принятия решений:
- `denied` + `dialogShown: false` → показать свой UI "Перейдите в настройки"
- `denied` + `dialogShown: true` → пользователь только что отказал, можно просто закрыть
- `granted` + `dialogShown: false` → разрешение уже есть, продолжаем работу

---

## 3. Native → JS: Error

Если произошла ошибка, Native отправляет `type = "error"` с тем же `id`:

```json
{
  "version": 1,
  "type": "error",
  "action": "permission.request",
  "payload": "{\"error\":\"Missing Info.plist key: NSLocationWhenInUseUsageDescription\"}",
  "id": "a1b2c3d4-e5f6-...",
  "timestamp": 1710340800500
}
```

**Payload** — объект с полем `error` (строка с описанием ошибки).

---

## 4. Сценарии ошибок

Native возвращает `error` в следующих случаях:

| Ошибка                                    | Сообщение                                                  |
|-------------------------------------------|------------------------------------------------------------|
| Отсутствует или пустое поле `type`        | `"Invalid payload: missing or empty 'type' field"`         |
| Неизвестный тип разрешения                | `"Unknown permission type: '<value>'"`                     |
| Нет зарегистрированного обработчика       | `"No handler registered for permission type: '<value>'"`   |
| Отсутствует ключ в Info.plist             | `"Missing Info.plist key: <key>"`                          |
| Ошибка на уровне ОС                      | Текст ошибки из `error.localizedDescription`               |

---

## 5. Поведение обработчиков по типам

### `pushNotifications`

- **requiredInfoPlistKeys**: нет (пустой массив)
- **notDetermined** → показывает системный диалог запроса → `granted` / `denied`
- **denied** → открывает настройки приложения (iOS 16+: настройки уведомлений, ниже — общие настройки) → возвращает `denied`
- **authorized / provisional / ephemeral** → сразу `granted`
- При `granted` дополнительно вызывает `UIApplication.shared.registerForRemoteNotifications()`

### `location`

- **requiredInfoPlistKeys**: `["NSLocationWhenInUseUsageDescription"]`
- **notDetermined** → показывает системный диалог `requestWhenInUseAuthorization()` → ожидает callback → `granted` / `denied`
- **denied / restricted** → сразу `denied`
- **authorizedWhenInUse / authorizedAlways** → сразу `granted`

---

## 6. Переход в настройки при `denied`

В iOS возможности deep-link в конкретную секцию настроек ограничены:

| Permission | Точечный переход в настройки | API |
|---|---|---|
| Push-уведомления | **Да** (iOS 16+) — открывает настройки уведомлений приложения | `UIApplication.openNotificationSettingsURLString` |
| Push-уведомления (iOS < 16) | Нет — общая страница настроек приложения | `UIApplication.openSettingsURLString` |
| Все остальные (Location, Camera, Microphone, Photos, Contacts, Bluetooth, ATT) | **Нет** — только общая страница настроек приложения | `UIApplication.openSettingsURLString` |

На общей странице настроек приложения пользователь видит все тоглы (Location, Camera, Microphone, Photos, Contacts и т.д.), но Native не может программно перейти к конкретному тоглу — это ограничение iOS.

### Решение: Native не открывает настройки

Native **не выполняет side-effect** (открытие Settings) при `denied`. Вместо этого JS получает `{ "status": "denied", "dialogShown": false }` и **сам решает**, показывать ли пользователю UI с кнопкой "Перейти в настройки".

Если JS решит перенаправить пользователя в настройки, он может использовать отдельный bridge action (например, `openLink` с URL `app-settings:`).

