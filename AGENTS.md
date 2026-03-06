# AGENTS.md for RunTrack

You are working in the RunTrack iOS codebase.

## Start Here
- Inspect the relevant code before editing.
- Implement directly when the request is straightforward.
- Provide a brief plan first only when the task is ambiguous, risky, or explicitly asks for planning.
- Keep the diff minimal and reviewable.
- Run or describe verification before finishing.
- If the user asks for a review, lead with findings first.

## Project Context
- Architecture: MVVM with Repository pattern
- UI framework: SwiftUI
- Networking boundary: APIClient + RemoteRepository
- Persistence boundary: LocalRepository
- Logging system: OSLog
- Harness profile: intermediate

## Required Reads
1. Read `Docs/AI_RULES.md`.
2. Read `Docs/AI_WORKFLOWS.md`.
3. Read the relevant files under `Docs/AI_SKILLS/`.
4. When the task matches a workflow below, read the corresponding file under `.ai-harness/workflows/`.

## Enabled Skills
- `concurrency-rules`
- `ios-architecture`
- `location-rules`
- `swiftui-rules`
- `testing-rules`

## Workflow Entry Points
- `add-feature`: Use for new features or visible behavior additions. Read `.ai-harness/workflows/add-feature.md`.
- `fix-bug`: Use for bug fixes and regression repairs. Read `.ai-harness/workflows/fix-bug.md`.
- `refactor`: Use for structure-only changes that preserve behavior. Read `.ai-harness/workflows/refactor.md`.
- `build`: Use for build or test verification work. Read `.ai-harness/workflows/build.md`.

## Build and Test Commands
- Build: xcodebuild -scheme RunTrack build
- Test: xcodebuild test -scheme RunTrack

## Completion Expectations
- Summarize files changed.
- Summarize behavior impact.
- Mention tests run or explain why tests were not run.
- Call out risks or limitations briefly.
