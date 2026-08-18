# Project Context

## Build System
- This is an SDK project with minimum deployment target iOS 12
- Use `BuildProject` to compile, not shell commands

## Testing
- Run tests with `RunAllTests` or `RunSomeTests`
- Test results available via Xcode's test navigator
- Write all new tests using **Swift Testing** framework (`import Testing`), not XCTest
- Use the `swift-testing-expert` skill when writing tests
- Use existing tags from `Tag+Extensions.swift` (e.g. `.webView`, `.sdkVersion`)
- Run tests via XcodeBuildMCP `test_sim` tool, not shell commands

### Where to put new tests
- **First, look for an existing suite that already covers the same subject** — feature suite, per-type suite, or layer-driven parsing suite. Add to it whenever it fits, even if it grows. Avoid creating a new file just to have a "clean" home.
- Create a new file only when no existing one fits — then:
  - **Feature suite**: `<FeatureName>Tests.swift`, `.tags(.featureName)`. Lives in a per-feature folder if the feature owns its UI/flow, otherwise in the closest existing layer folder (e.g. `Network/`).
  - **Per-type unit suite**: `<TypeName>Tests.swift` (or `...PublicAPITests.swift` for public types). Place next to existing siblings of the same scope.
- When in doubt, put the new file where the closest sibling already is, not in a new top-level folder.
- Don't bulk-reorganize the test tree. Move tests only when you're already touching them for content reasons.

## Documentation
- Use `DocumentationSearch` to find Apple API docs
- WWDC session transcripts are searchable

## Commit messages
- Title: imperative, ≤72 chars, `MOBILE-XXXX` prefix.
- Body: 1–3 short paragraphs at most. Lead with the cause/why; the diff already shows the what.
- Drop sentences that restate what the code does. If the change is obvious (small refactor, dep bump, formatting), skip the body entirely.

## Code comments

**Default: no comment.** Write the code so none is needed — naming, decomposition and types carry the
meaning. Reaching for a comment is the signal to try a better name or a smaller function first.

- **The one-level bar.** A comment survives only if its knowledge cannot be recovered from the code
  within one level of where it stands (the declaration itself plus its direct callers and callees).
  That leaves: cross-platform and wire contracts, threading/lifetime invariants, process-global state,
  linker behavior, deliberate deviations from the obvious implementation. A well-written "why" whose
  answer a reader reconstructs by reading the function and one caller still goes. In doubt — delete.
- **Keep it short.** One or two lines. No paragraphs, no narratives, no restating what the code does;
  delete such comments when touching the code.
- **Tests carry their intent in their names, not in comments.** Test names may be full sentences —
  use that instead of a doc comment, and let the body show the mechanics. A test or suite gets a
  one-line comment only for a non-local constraint the code cannot show: shared/global state and its
  reset, dependence on serial execution, in-memory isolation, a cross-platform contract, or an
  infrastructure trap (a silent protocol default, a fake clock, a mock that runs production code).
- **Public API is the exception** — document it properly: what it does, what it promises, what the
  parameters mean and what happens on the edges. Same for API-level protocols: document every
  function, what it does and why it exists.
- No ticket/PR references in comments or test names — provenance lives in git history (commit titles
  carry MOBILE-XXXX). Exception: TODOs keep the ticket that tracks them.
- Name external contracts, not external artifacts: "in sync with Android and the server" — yes;
  foreign type names, repo paths — no.

## Decision Making
- You MUST push back on decisions that lead to hacks, security holes, or tech debt. Silent agreement with a bad decision is itself a mistake.
- Quality and security over speed. Do not accept "we'll fix it later", "good enough for MVP", or "it's temporary" — temporary solutions become permanent.
- Long-term maintainability over quick results. Choose solutions that scale, even if they take longer.
- If the user insists after pushback — clearly state the risks and document them in commit message, PR description, or relevant notes.

## Skill precedence
`superpowers` and `karpathy-guidelines` collide on small tasks: superpowers annexes the trivial zone (brainstorming "EVERY project regardless of perceived simplicity", TDD "Too simple to test → Simple code breaks", "you do not have a choice"), karpathy carves it out ("For trivial tasks, use judgment"). Neither defines a skill-vs-skill tiebreaker, so this repo sets it:

- **Trivial & behavior-preserving** (typo, rename, obvious one-liner, config-value bump): karpathy's "use judgment" wins — make the surgical change with a proportionate check (read/compile), skip the brainstorming/TDD/spec-doc gates.
- **Real design surface, ambiguity, or behavior change**: full superpowers process applies (brainstorming → writing-plans → TDD → verification → review).
- **Always**: spec docs under `docs/superpowers/specs/` and any commits happen only on explicit request — never auto-commit, never write an unrequested spec doc (this is a user instruction and outranks any skill, including brainstorming's commit-the-spec step).
- On an unclear/ungrounded request, surface the confusion and ask immediately after a lightweight skill check — don't interpose a spec/2-3-approaches/TDD round before the clarifying question.