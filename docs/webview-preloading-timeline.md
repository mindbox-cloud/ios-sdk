# WebView In-App Preloading & Pre-rendering Timeline

## Measured on real device (2026-04-06)

**Config:** `Mpush-test.WebView`, 1 webview in-app (isPriority=true)  
**Content URL:** `https://mobile-static.mindbox.ru/stable/inapps/webview/content/index.html` (1517 chars)  
**Result:** `presentationTime = 0.997s`, `timeToDisplay = 1.008s`

---

## Full timeline

### Phase 1: Config download + HTML preload

| Time | Event | Log |
|------|-------|-----|
| T+0.000s | Config downloaded (HTTP 200) | `[TTL] Config download date successfully updated` |
| T+0.000s | HTML preload started | `[WebView Preload] Starting preload for 1 unique URL(s)` |
| T+0.000s | HTML cache invalidated (old cache cleared) | `[WebView Preload] HTML cache invalidated` |
| T+~0.1s | HTML cached in memory | `[WebView Preload] Cached HTML for ...index.html (1517 chars)` |

### Phase 2: Pre-rendering (after 2s delay)

| Time | Event | Log |
|------|-------|-----|
| T+2.0s | Pre-render started | `[WebView Prerender] Pre-rendering started for inAppId=66ede431...` |
| T+2.0s | Hidden WKWebView created, cached HTML loaded | `WKNavigationDelegate: allowing navigation (other) to URL https://inapp.local/popup` |
| T+~2.5s | WKWebView finished loading | `WKNavigationDelegate: Upload completed https://inapp.local/popup` |
| T+~2.5s | JS bridge ready check passed | `JS ready check for URL https://inapp.local/popup: true` |
| T+~2.5s | JS sent `.ready` message | `Bridge: received ready` |
| T+~2.5s | **Handshake HELD** (not sent to JS) | `[WebView Prerender] Ready received, holding handshake for inAppId=66ede431...` |

### Phase 3: Trigger + instant show

| Absolute time | Event | Log |
|---------------|-------|-----|
| 14:30:39.293 | User triggers `test1` operation | `[Mindbox] Send event to InApp messages if needed. Operation system name: Test1` |
| 14:30:39.293 | In-app scheduled | `[InappScheduleManager] Scheduled 66ede431... processingDuration=0:00:00.011` |
| 14:30:39.293 | Pre-rendered view **claimed** | `[WebView Prerender] Claimed pre-rendered view for inAppId=66ede431...` |
| 14:30:39.293 | Ready handshake sent to JS (with operation data) | `Bridge -> JS: sending response ... action=ready` |
| 14:30:39.293 | Handshake completed | `[WebView Prerender] Handshake completed for inAppId=66ede431...` |
| 14:30:40.262 | JS sent `.init` (content rendered) | `Bridge: received init` |
| 14:30:40.289 | Window made visible + `onPresented()` fired | `TransparentWebView: Window is now visible` |
| 14:30:40.289 | `Inapp.Show` event sent | `[MBDBRepo] Creating event 'Inapp.Show'` |

---

## Performance breakdown

```
processingTime   =  0.011s  (targeting + scheduling)
presentationTime =  0.997s  (from scheduled → onPresented)
timeToDisplay    =  1.008s  (total)
```

### What the 0.997s consists of

| Step | Duration | Notes |
|------|----------|-------|
| Claim pre-rendered view | ~0ms | In-memory lookup |
| Set delegates + update operation | ~0ms | Synchronous |
| Send ready handshake to JS | ~0ms | Bridge message |
| **JS render (ready → init)** | **~970ms** | JS framework processes payload, renders content |
| Window fade-in animation start | ~0ms | `UIView.animate(0.3s)` starts, `makeKeyAndVisible()` called |

### Bottleneck

The ~970ms is JS render time inside the WKWebView. This is on the JS/web side and cannot be optimized by the SDK. Everything the SDK controls (network, WKWebView creation, HTML loading, bridge setup) has been eliminated from the critical path.

---

## Comparison: before vs after

| Stage | Before (no preloading) | After (with preloading) |
|-------|----------------------|------------------------|
| HTML network fetch | 200-1000ms | 0ms (pre-cached) |
| WKWebView creation | ~100ms | 0ms (pre-created) |
| HTML load into WKWebView | ~200ms | 0ms (pre-loaded) |
| JS bridge setup + ready | ~200ms | 0ms (pre-received, held) |
| JS render after payload | ~1000ms | ~970ms (same) |
| **Total presentationTime** | **~1.7-2.5s** | **~1.0s** |

---

## Key logs to filter

| Filter | What it shows |
|--------|--------------|
| `[WebView Preload]` | HTML cache operations |
| `[WebView Prerender]` | Pre-rendering lifecycle |
| `[InAppMetric]` | Final timing metrics |
| `[InappScheduleManager] Scheduled` | Trigger → schedule timestamp |

---

## Fallback scenarios

| Scenario | Behavior | Expected presentationTime |
|----------|----------|--------------------------|
| Pre-rendered in-app matches trigger | Claim + instant handshake | ~1.0s (JS render only) |
| Different in-app triggered (claim miss) | Standard flow, HTML from cache | ~1.2-1.5s (skip network) |
| Memory warning before trigger | Caches cleared, standard flow | ~1.7-2.5s (full flow) |
| First launch (no cache yet) | Standard flow | ~1.7-2.5s (full flow) |
