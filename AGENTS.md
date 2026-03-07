# AGENTS.md for SwiftNest

You are working in the SwiftNest starter and CLI codebase.

## Start Here
- Inspect the relevant code before editing.
- Implement directly when the request is straightforward.
- Provide a brief plan first only when the task is ambiguous, risky, or explicitly asks for planning.
- Keep the diff minimal and reviewable.
- Run or describe verification before finishing.
- If the user asks for a review, lead with findings first.

## Project Context
- Product: SwiftNest starter + local CLI bootstrap tooling
- Primary surfaces: `swiftnest` shell entrypoint, `tools/swiftnest-cli`, starter templates, Homebrew packaging assets
- Packaging model: repo-local installation first, optional Homebrew bootstrap command via separate tap
- Harness profile: intermediate

## Required Reads
1. Read `Docs/AI_RULES.md`.
2. Read `Docs/AI_WORKFLOWS.md`.
3. Read the relevant files under `Docs/AI_SKILLS/`.
4. When the task matches a workflow below, read the corresponding file under `.ai-harness/workflows/`.

## Workflow Entry Points
- `add-feature`: Use for new CLI behavior, starter template capabilities, or packaging-visible additions. Read `.ai-harness/workflows/add-feature.md`.
- `fix-bug`: Use for CLI regressions, bootstrap/install issues, or packaging repairs. Read `.ai-harness/workflows/fix-bug.md`.
- `refactor`: Use for structure-only changes that preserve behavior. Read `.ai-harness/workflows/refactor.md`.
- `build`: Use for build, test, or packaging verification work. Read `.ai-harness/workflows/build.md`.

## Build and Test Commands
- CLI tests: `swift test --package-path tools/swiftnest-cli`
- CLI help smoke test: `./swiftnest --help`
- Localized smoke test example: `./swiftnest --lang ko list-profiles`
- Homebrew formula rendering: `make render-homebrew-formula RELEASE_TAG=<tag> RELEASE_ARCHIVE=<archive> FORMULA_OUTPUT=<path>`

## Feature Development Expectations
- Keep starter assets, CLI behavior, README guidance, and packaging changes aligned.
- If user-visible CLI output changes, update or add tests for English/Korean behavior when applicable.
- When changing Homebrew-visible behavior, update `packaging/homebrew/swiftnest.rb.template` and the related documentation in the same change.
- Preserve the bootstrap model: global Homebrew `swiftnest` installs into repos, then repo-local `./swiftnest` owns follow-up commands.

## Homebrew Release Follow-up
When a feature affects starter contents or Homebrew-visible behavior, finish the release in this order after it lands on `main`:
1. Verify the intended user-facing behavior locally from `main`.
2. Create and push a new Git tag from `swift-nest`.
3. Download the matching GitHub tag archive and compute its SHA256.
4. Render `packaging/homebrew/swiftnest.rb.template` into the tap repository as `Formula/swiftnest.rb`.
5. Commit and push the updated formula in `oozoofrog/homebrew-swiftnest` (or the active tap repo).
6. Verify with `brew install swiftnest`, `brew test swiftnest`, and at least one smoke test such as `swiftnest install --target <repo>` or `swiftnest --lang ko list-profiles`.

## Completion Expectations
- Summarize files changed.
- Summarize behavior impact.
- Mention tests run or explain why tests were not run.
- Call out risks or limitations briefly.
