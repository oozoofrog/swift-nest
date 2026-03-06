# Rendered AI Harness Context

Profile: intermediate

Skills: concurrency-rules, ios-architecture, location-rules, swiftui-rules, testing-rules


<!-- AI_RULES.md -->

# AI Rules for RunTrack

## Purpose
This document defines the mandatory implementation rules for AI agents working in the RunTrack codebase.

Agents must read this file before making changes.

---

## Project Context
- Project name: RunTrack
- Platform: iOS / watchOS companion app enabled
- UI framework: SwiftUI
- Architecture style: MVVM with Repository pattern
- Minimum iOS version: iOS 17
- Package manager: Swift Package Manager
- Testing framework: XCTest
- Lint/format tools: SwiftLint, SwiftFormat
- Harness profile: intermediate

---

## Global Priorities
When making trade-offs, prefer:
1. Correctness
2. Maintainability
3. Testability
4. Consistency with existing codebase
5. Performance
6. Speed of implementation

Do not optimize prematurely.

## Architecture Rules
- Respect the existing project architecture.
- Do not introduce a new architectural pattern unless explicitly requested.
- UI code must stay in the UI layer.
- Business logic must not live in View code.
- Networking must go through APIClient + RemoteRepository.
- Persistence must go through LocalRepository.
- Dependency boundaries must remain clear.
- Reuse existing patterns before introducing new abstractions.

### Layer Responsibilities
- View:
  - renders state
  - handles user interaction forwarding
  - contains minimal presentation-only logic
- ViewModel / Presentation layer:
  - prepares UI state
  - coordinates async work
  - maps domain results to UI-facing state
- Domain / UseCase layer:
  - contains business rules
  - should remain platform-light where practical
- Repository / Service layer:
  - coordinates API / storage access
- Infrastructure layer:
  - API client
  - database
  - OS integrations
  - system frameworks

## Code Change Scope
- Modify only files necessary for the task.
- Avoid unrelated refactors.
- Do not rename files/types/functions unless necessary.
- If a broader refactor is truly needed, explain why before doing it.
- Prefer minimal, reviewable diffs.

## Naming and Style
- Follow existing naming conventions in the repository.
- Prefer explicit, intention-revealing names.
- Avoid vague names like `Manager`, `Helper`, `Util` unless already established.
- Keep types and functions focused.
- One primary type per file unless local helper types are clearly justified.

## File Size and Complexity
- Prefer files under 300 lines when practical.
- Break up overly large views or view models before they become hard to review.
- Extract subviews/helpers only when they improve clarity.
- Avoid unnecessary abstraction layers.

## SwiftUI / UI Rules
- Views should primarily describe layout and bindings.
- Avoid embedding business decisions directly in SwiftUI `body`.
- If `body` becomes complex, extract subviews or computed properties.
- Keep presentation state explicit.
- Handle loading, success, empty, and error states where relevant.
- Do not trigger heavy work repeatedly from rendering paths.
- Follow existing navigation and presentation patterns.

## Concurrency Rules
- Use structured concurrency by default.
- Prefer `async/await` over callback pyramids where project-compatible.
- UI-facing state updates must happen on the appropriate actor, usually the main actor.
- Support cancellation for user-triggered async flows where relevant.
- Do not use detached tasks unless explicitly justified.
- Avoid race-prone shared mutable state.
- Consider repeated taps / repeated refresh / screen re-entry behavior.

## Error Handling Rules
- No silent failures unless intentionally documented.
- Represent recoverable errors in a user-visible or developer-visible way.
- Prefer typed errors or structured error mapping where established.
- Preserve underlying causes when useful for debugging.
- Do not swallow important errors inside broad `catch` blocks.

## Networking Rules
- All network access must go through APIClient + RemoteRepository.
- Do not call remote APIs directly from Views.
- Parse and map responses in the appropriate layer.
- Handle timeout, cancellation, decoding failure, and server-side failure paths.

## Persistence Rules
- All storage access must go through LocalRepository.
- Avoid leaking storage-specific concerns into UI code.
- Keep persistence writes deliberate and reviewable.
- Consider stale cache and missing data states where relevant.

## State Management Rules
- UI state should be explicit and testable.
- Prefer deterministic state transitions.
- Avoid hidden implicit state mutations.
- Distinguish:
  - initial
  - loading
  - success
  - empty
  - error
  - permission-denied / restricted states when applicable

## Permissions / OS Integration Rules
- Never assume permissions are granted.
- Always handle denied, restricted, and not-determined states where applicable.
- Re-check permission-dependent state after app lifecycle changes if relevant.
- Keep OS framework integrations behind clear boundaries.

## Testing Rules
- New non-trivial logic must include tests.
- Bug fixes should include regression tests when practical.
- Tests should validate behavior, not implementation trivia.
- Prefer deterministic tests.
- Avoid brittle timing-dependent tests unless necessary.
- Mock or fake external dependencies where appropriate.

## Logging / Diagnostics
- Use OSLog for developer diagnostics.
- Do not add noisy logs without purpose.
- Prefer structured logs where supported.
- Never log secrets, tokens, raw personal data, or protected health data.

## Security / Privacy
- Do not hardcode secrets.
- Do not expose tokens or credentials in logs.
- Follow least-privilege access to APIs and device capabilities.
- Treat user privacy-sensitive data carefully.
- Respect App Privacy disclosure and least-privilege data handling.

## Performance
- Do not move expensive work onto the main thread.
- Avoid unnecessary recomputation in rendering paths.
- Avoid excessive location / sensor usage unless required.
- Prefer measured optimization over speculative optimization.

## Forbidden Patterns
- No force unwrap in production code unless explicitly justified and truly safe.
- No networking directly inside View code.
- No persistence access directly inside View code.
- No unrelated refactor during feature implementation.
- No dead code left behind.
- No commented-out code in final output unless requested.
- No fake placeholders presented as complete implementation.

## Profile-Specific Guidance
- Include explicit self-review.
- Add regression tests for bug fixes when practical.
- Call out state transition risks when async or permission logic is involved.

## Required Delivery Format for Agent Responses
Before implementation, provide:
1. Applicable rules summary
2. Planned file changes
3. Short implementation strategy
4. Test plan

After implementation, provide:
1. Files changed
2. Behavior summary
3. Tests added/updated
4. Risks / limitations
5. Any rule deviations, if any


<!-- AI_WORKFLOWS.md -->

# AI Workflows for RunTrack

This document defines standard execution workflows for AI agents.

## Workflow: Add Feature
1. Read `Docs/AI_RULES.md` and relevant `Docs/AI_SKILLS/*` files.
2. Summarize applicable rules.
3. Inspect existing implementation patterns before proposing new ones.
4. Propose a minimal implementation strategy.
5. Identify files to modify.
6. Implement in correct layer order:
   - model/domain
   - repository/service
   - presentation/viewmodel
   - view
7. Add/update tests.
8. Review for rule violations.
9. Summarize changes and remaining risks.

## Workflow: Fix Bug
1. State the bug in one sentence.
2. Identify the likely failing layer.
3. Describe the root cause hypothesis.
4. Confirm impacted state transitions / user flows.
5. Implement root-cause fix, not symptom-only patch.
6. Add regression test when practical.
7. Review for side effects.
8. Summarize what changed and why.

## Workflow: Refactor
1. Explain why refactor is needed.
2. Confirm no feature behavior should change unless stated.
3. Keep scope narrow.
4. Preserve public interfaces unless required.
5. Add/update tests to protect behavior.
6. Summarize before/after structure.

## Workflow: Permissions-Related Feature
1. Identify all relevant permission states.
2. Separate explanation UI, permission request trigger, and active feature behavior.
3. Handle denied/restricted/notDetermined/authorized states.
4. Consider app foreground re-entry.
5. Add state transition tests where practical.

## Workflow: Networking Change
1. Confirm API integration point.
2. Define request/response mapping clearly.
3. Handle decoding error, network failure, cancellation, and server-side failure.
4. Avoid leaking API models into unrelated layers.
5. Add repository/service tests where practical.

## Final Self-Review Checklist
- no force unwrap introduced
- no unrelated file changes
- no business logic moved into View
- async state updates are actor-safe
- errors are not silently swallowed
- tests cover the intended behavior
- implementation matches existing project conventions

## Profile-Specific Review Additions
- Verify layer boundaries and regression risk before finishing.


<!-- AI_PROMPT_ENTRY.md -->

# AI Prompt Entry Template for RunTrack

You are working on the RunTrack iOS codebase.

Before doing any implementation:
1. Read `Docs/AI_RULES.md`
2. Read `Docs/AI_WORKFLOWS.md`
3. Read the relevant files under `Docs/AI_SKILLS/` for this task

Then:
1. Summarize the applicable rules
2. Propose a minimal implementation strategy
3. List files to modify
4. Provide a test plan
5. Implement
6. Perform a self-review against the rules

Constraints:
- Follow the established architecture: MVVM with Repository pattern
- Use SwiftUI
- Networking must go through APIClient + RemoteRepository
- Persistence must go through LocalRepository
- Avoid unrelated refactors
- Do not place business logic in View code
- Add tests for non-trivial logic
- Keep the diff minimal and reviewable

Output format:
1. Applicable rules
2. Strategy
3. Files to change
4. Test plan
5. Implementation
6. Self-review
7. Risks / limitations


<!-- AI_SKILLS/concurrency-rules.md -->

# Concurrency Rules

Apply this skill whenever async work, task orchestration, cancellation, or actor correctness is involved.

- Prefer structured concurrency.
- Use `async/await` when consistent with the codebase.
- UI-facing state changes should happen on the correct actor.
- Support cancellation for user-triggered async operations where relevant.
- Consider re-entrancy and repeated invocation behavior.
- Prefer predictable state transitions over ad hoc async mutation.


<!-- AI_SKILLS/ios-architecture.md -->

# iOS Architecture Rules

Apply this skill whenever the task touches app structure, screen composition, or responsibility boundaries.

- Preserve the current architectural style: MVVM with Repository pattern
- Keep Views presentation-focused.
- Keep business logic out of Views.
- Keep API and persistence concerns out of Views.
- Prefer dependency injection over hidden globals.
- Reuse existing abstractions before creating new ones.
- Avoid generic manager/helper types unless already established.


<!-- AI_SKILLS/location-rules.md -->

# Location Rules

Apply this skill whenever Core Location, running/walking tracking, region monitoring, or location permissions are involved.

- Distinguish authorization status from accuracy authorization where applicable.
- Handle not determined, denied, restricted, authorized when in use, and authorized always.
- Do not assume high accuracy is always available.
- Separate permission request flow from active tracking flow.
- Keep `CLLocationManager` integration away from View code.
- Model degraded location quality explicitly if it affects UX.
- Consider battery impact for continuous tracking.


<!-- AI_SKILLS/swiftui-rules.md -->

# SwiftUI Rules

Apply this skill whenever the task touches SwiftUI screens or UI state.

- Views should primarily describe UI.
- Avoid embedding heavy logic directly in `body`.
- Prefer explicit screen states.
- Extract subviews when complexity meaningfully decreases.
- Preserve existing navigation and presentation patterns.
- Avoid repeated side effects triggered by rerendering.


<!-- AI_SKILLS/testing-rules.md -->

# Testing Rules

Apply this skill whenever logic changes are introduced.

- New non-trivial logic requires tests.
- Prefer behavior-oriented tests.
- Use deterministic inputs and assertions.
- Mock or fake external dependencies.
- Test state transitions for view models/presenters.
- Add regression tests for bug fixes where practical.
