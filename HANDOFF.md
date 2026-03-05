# HANDOFF: InApp Trigger-to-Display Performance Metric

## 1. Context

Measure SDK processing time from in-app trigger to actual display, excluding intentional delay and background wait. Two duration variables are computed independently and summed to produce the result. Output via `print()` for now.

## 2. Load Estimation

One metric computation per shown in-app (1 per event at most). `handleInapps` returns `InAppFormData?` — at most one in-app per event. No allocations, no I/O — just `CACurrentMediaTime()` calls and arithmetic. Negligible overhead.

## 3. Key Design Decisions

### Two-segment measurement (excludes delay/background naturally)

- **`processingDuration` (var1):** from first line of `handleEvent()` to first line of `handleInapps` completion block. Measures mapping, filtering, targeting, image loading.
- **`presentationDuration` (var2):** from right before `presentInapp()` call (in foreground, after delay timer) to `onPresented` callback. Measures UI pipeline: window creation, factory, view controller, rendering.
- **Result** = `var1 + var2`.

Gap between var1-end and var2-start contains the delay timer and potential background wait — automatically excluded.

### Clock: `CACurrentMediaTime()` (monotonic, thread-safe, NTP-immune)

### Thread safety

`InAppFormData` is a struct (value semantics). `triggerTimestamp` is a local variable inside `handleEvent()` — no shared mutable state. `handleEvent` runs on `serialQueue`, events are processed sequentially.

### Timestamp propagation without protocol changes

`triggerTimestamp` is captured in `handleEvent()` as a local variable. In the `handleInapps` completion block, `processingDuration` is computed and set on the `InAppFormData` struct before passing it to `onReceivedInAppResponse`. No changes to `InAppConfigurationManagerProtocol` or `InappMapperProtocol`.

### Only successful presentations are tracked

If the in-app is nil, validation fails, or `onError` fires — no metric output.

### Config wait time is excluded

`handleEvent()` is only reachable after `isConfigurationReady == true` (enforced by guard in `sendEvent` and by `didPreparedConfiguration` → `handleQueuedEvents` call flow). Config download time is not measured.

### `presentInapp` has a single call site

`presentInapp` is only called from `showEligibleInapp()`. Adding `readyTimestamp` parameter does not break other call sites.

### Output format

```
[InAppMetric] inappId=<id> processingMs=<X.X> presentationMs=<Y.Y> totalMs=<Z.Z>
```

All values in milliseconds with 1 decimal place.

## 4. Definition of Done

- [ ] `InAppFormData` has `var processingDuration: TimeInterval = 0` field (default value preserves backward compatibility with existing initializer call sites)
- [ ] `InAppCoreManager.handleEvent()` captures `let triggerTimestamp = CACurrentMediaTime()` at entry. In the `handleInapps` completion: compute `processingDuration = CACurrentMediaTime() - triggerTimestamp`, set on `InAppFormData` before passing to `onReceivedInAppResponse`
- [ ] `InappScheduleManager.showEligibleInapp()` captures `let readyTimestamp = CACurrentMediaTime()` right before calling `presentInapp`
- [ ] `InappScheduleManager.presentInapp()` accepts `readyTimestamp: TimeInterval` parameter
- [ ] In `onPresented` callback inside `presentInapp`: compute `presentationDuration`, print using format above
- [ ] Remove existing `// Metric #1` / `// Metric #2` comments and `[InAppMetric]` log messages — replaced by actual implementation
- [ ] No print/metric output on error, nil in-app, or failed validation
- [ ] Existing unit tests and initializer call sites still compile (default value for new field)

## 5. Must-Read Files

- `Mindbox/InAppMessages/Models/InAppFormData.swift` — add `processingDuration` field
- `Mindbox/InAppMessages/InAppCoreManager.swift` — capture timestamp in `handleEvent`, set `processingDuration` in completion
- `Mindbox/InAppMessages/InappScheduleManager.swift` — capture `readyTimestamp` in `showEligibleInapp`, accept it in `presentInapp`, print metric in `onPresented`
