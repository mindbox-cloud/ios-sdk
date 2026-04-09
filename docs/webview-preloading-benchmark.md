# WebView In-App Preloading: Benchmark Results

**Date:** 2026-04-06  
**Device:** iPhone (Simulator, iOS 26.2)  
**Config:** `Mpush-test.WebView`, 1 webview in-app (`isPriority=true`)  
**Content URL:** `https://mobile-static.mindbox.ru/stable/inapps/webview/content/index.html` (1517 chars)  
**SDK Version:** 2.15.0

---

## Results

| Metric | develop (baseline) | feature (preloading) | Difference |
|--------|-------------------|---------------------|------------|
| `processingTime` | 0.019s | 0.011s | -0.008s |
| **`presentationTime`** | **2.221s** | **0.997s** | **-1.224s (−55%)** |
| **`timeToDisplay`** | **2.240s** | **1.008s** | **-1.232s (−55%)** |

---

## Baseline: develop branch (no caching)

### Timeline

```
14:46:45.662  Trigger test1 → in-app scheduled
14:46:45.662  WebviewPresentationStrategy: Starting presentation
14:46:45.662  New WKWebView created (TransparentView + MindboxWebViewFacade)
     ~45.7s   fetchHTML → HTTP GET index.html (network request)
     ~46.0s   HTML downloaded → loadHTMLString into WKWebView
     ~46.9s   WKNavigationDelegate: Upload completed (URL: mobile-static.mindbox.ru/...index.html)
     ~46.9s   JS sent .ready → SDK immediately responds with payload
     ~47.8s   JS sent .init → content rendered
     ~47.9s   Window visible + Inapp.Show sent
```

### Time breakdown (2.221s)

| Step | Duration | Description |
|------|----------|-------------|
| WKWebView creation | ~50ms | TransparentView + MindboxWebViewFacade + WKWebView init |
| HTML network fetch | ~300ms | HTTP GET to CDN (1517 chars) |
| WKWebView load + render HTML | ~900ms | loadHTMLString → navigation → JS bridge init |
| JS render (ready → init) | ~970ms | JS framework processes payload, renders content |
| **Total presentationTime** | **~2.221s** | |

### Key log markers

```
[WebView] WKNavigationDelegate: Upload completed https://mobile-static.mindbox.ru/.../index.html
                                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                                  HTML was fetched from NETWORK
```

---

## Feature branch: with preloading + pre-rendering

### Timeline

```
14:30:20.000  Config downloaded
14:30:20.000  [WebView Preload] Starting preload for 1 unique URL(s)
     ~20.1s   [WebView Preload] Cached HTML (1517 chars)
14:30:22.000  [WebView Prerender] Pre-rendering started (after 2s delay)
     ~22.5s   WKWebView loaded cached HTML, JS bridge ready
     ~22.5s   [WebView Prerender] Ready received, holding handshake
              ... waiting for trigger ...
14:30:39.293  Trigger test1 → in-app scheduled
14:30:39.293  [WebView Prerender] Claimed pre-rendered view
14:30:39.293  Ready handshake sent to JS (with operation data)
     ~40.2s   JS sent .init → content rendered
     ~40.3s   Window visible + Inapp.Show sent
```

### Time breakdown (0.997s)

| Step | Duration | Description |
|------|----------|-------------|
| WKWebView creation | 0ms | Pre-created |
| HTML network fetch | 0ms | Pre-cached |
| WKWebView load + render HTML | 0ms | Pre-loaded |
| JS bridge setup + ready | 0ms | Pre-received, handshake held |
| Claim + send handshake | ~0ms | In-memory lookup + bridge message |
| JS render (ready → init) | ~970ms | JS framework processes payload, renders content |
| **Total presentationTime** | **~0.997s** | |

### Key log markers

```
[WebView] WKNavigationDelegate: Upload completed https://inapp.local/popup
                                                  ^^^^^^^^^^^^^^^^^^^^^^^^
                                                  HTML was loaded from CACHE (baseUrl, not contentUrl)

[WebView Prerender] Claimed pre-rendered view for inAppId=66ede431...
[WebView Prerender] Handshake completed for inAppId=66ede431...
```

---

## What was eliminated

| Step | Baseline | With preloading | Saved |
|------|----------|----------------|-------|
| WKWebView creation | ~50ms | 0ms (pre-created) | ~50ms |
| HTML network fetch | ~300ms | 0ms (pre-cached) | ~300ms |
| HTML load into WKWebView | ~200ms | 0ms (pre-loaded) | ~200ms |
| JS bridge init + ready | ~700ms | 0ms (pre-received) | ~700ms |
| **Total eliminated** | | | **~1.25s** |

## What remains (cannot be optimized by SDK)

| Step | Duration | Why |
|------|----------|-----|
| JS render after payload | ~970ms | JS framework renders content after receiving operation data. This is web-side logic. |

---

## Known difference: insets

| Field | Baseline | Preloading |
|-------|----------|------------|
| `insets.top` | 62 | 0 |
| `insets.bottom` | 34 | 0 |

Pre-rendered WKWebView is not yet in the window hierarchy when insets are computed. JS recalculates layout at `.init` time, so this does not affect visual correctness.

---

## How to reproduce

### Baseline (develop)
1. Checkout `develop`
2. Run app → trigger `test1` operation
3. Filter logs: `[InAppMetric]`

### With preloading (feature branch)
1. Checkout `feature/MOBILE-72`
2. Run app → wait 3-5 seconds (HTML download + pre-render)
3. Trigger `test1` operation
4. Filter logs: `[InAppMetric]`, `[WebView Preload]`, `[WebView Prerender]`
