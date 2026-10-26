# Privacy manifest gate

CI checks that the privacy manifests of `Mindbox`, `MindboxLogger` and `MindboxNotifications` declare exactly the
required-reason APIs their code uses. The tool is [xcprivacy-gate](https://github.com/mindbox-cloud/xcprivacy-gate);
its README lists every violation code and the limitations.

## What runs

| Workflow | When | Command |
|---|---|---|
| `linter_and_unit_tests.yml`, job `PrivacyManifest` | every pull request and push to `develop` and `mission/*` | `self-test`, then `check --config .github/privacy-manifest/config.json` |
| `privacy-rules.yml` | Mondays 06:00 UTC and by hand | `refresh --check --config .github/privacy-manifest/config.json` |

`refresh --check` fails when Apple changes the condition of a reason this SDK declares, or when Apple's list of SDKs
that need a privacy manifest and signature starts or stops naming Mindbox.

The action is pinned to a commit of xcprivacy-gate. Renovate proposes a new pin in its own pull request and never
merges it on its own: a new version can change the verdicts.

## Files

- `config.json`: the package root, the policies and the expected SDK-list verdict.
  - `userDefaultsAppGroup: true`: the SDK keeps its data in an App Group suite, so any UserDefaults use needs `1C8F.1`,
    and `UserDefaults.standard` or a suite in `privateUserDefaultsSuites` also needs `CA92.1`.
  - `trackingDisabled: true`: every manifest declares `NSPrivacyTracking` as `false`.
  - `appleSdkList`: Apple's list does not name Mindbox (checked 2026-10-26).
- `usage.json`: one entry per file that calls a required-reason API, with Apple's reason and why the SDK calls it.

## When the gate fails

- `UNREGISTERED_CALL`: a new call of a required-reason API. Add an entry to `usage.json` with the reason that matches
  what the code does, and declare that reason in the module's manifest.
- `STALE_ENTRY` or `LIKELY_MOVE`: a call was removed or moved. Update `usage.json`.
- `MISSING_CATEGORY`, `EXTRA_CATEGORY`, `REASONS_MISMATCH`: the manifest and the code disagree. Fix the manifest.

Run the gate locally from a clone of xcprivacy-gate at the pinned commit:

```sh
swift build -c release
.build/release/xcprivacy-gate check --config <path to ios-sdk>/.github/privacy-manifest/config.json
```
