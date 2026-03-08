# SwiftNest

English | [Korean](README_kr.md)

SwiftNest is a starter for installing a consistent agent workflow setup into iOS and SwiftUI codebases.

It generates project-specific rules, workflows, task prompts, and Codex entrypoints so agents can work against the same constraints every time. This is not a buildable iOS app template. It is a starter for real app repositories.

Canonical GitHub repository:

`https://github.com/oozoofrog/swift-nest`

## Why This Exists

- Copying AI rules into every project by hand does not scale.
- Teams need a clean way to enable only the skills a task actually needs.
- Small projects need a lightweight setup, while larger products need stricter reviews and workflows.
- Repeating long setup prompts to Claude Code, ChatGPT, Codex, and similar agents is noisy and error-prone.

## What It Generates

SwiftNest generates project-facing documents and state files like this:

```text
AGENTS.md
Docs/
  AI_RULES.md
  AI_WORKFLOWS.md
  AI_PROMPT_ENTRY.md
  AI_SKILLS/
    ...selected skills...
.swiftnest/
  state.json
  selected_profile.yaml
  selected_skills.txt
  rendered_context.md
  workflows/
    add-feature.md
    fix-bug.md
    refactor.md
    build.md
    onboarding-review.md
```

`Docs/` and `.swiftnest/` are first-class harness assets. Track them in version control by default.

The source repository keeps a repo-local `./swiftnest` shell entrypoint for developing SwiftNest itself. Managed target repositories do not receive a repo-local CLI wrapper or CLI sources; they use the globally installed `swiftnest` command instead.
To avoid overlapping bootstrap builds while developing the starter itself, the local wrapper now serializes builds and defaults to `SWIFTNEST_BUILD_JOBS=1`. Override it explicitly when you want more parallelism, for example `SWIFTNEST_BUILD_JOBS=2 ./swiftnest --help`.

## Link-Only Agent Setup

If an agent only receives this GitHub link, the expected installation flow is:

1. Make sure the global `swiftnest` command is installed and available on `PATH`.
2. Read the README from this repository first.
3. Run the global `swiftnest` command with `onboard` against the target app repository.
4. Review the generated `config/project.yaml`, `AGENTS.md`, and `Docs/` output in the target repository.
5. Start agent work from the target repository root.
6. Commit the generated `Docs/` and `.swiftnest/` files in the target repository.

Example:

```bash
swiftnest onboard \
  --target /path/to/current-ios-repo \
  --non-interactive
```

Use the source checkout's `./swiftnest` only when developing SwiftNest itself. Managed target repositories are expected to use the global `swiftnest` command.

When you omit `--target`, SwiftNest first looks for the current SwiftNest-managed repository root, then for the current Git repository root, and asks for confirmation before using that inferred location. Keep `--target <path>` for non-interactive flows or when you are bootstrapping a different repository.

## Homebrew Packaging

SwiftNest ships Homebrew packaging assets under `packaging/homebrew/` for a separate tap repository such as `oozoofrog/homebrew-swiftnest`.

Recommended release flow:

1. Create and push a Git tag from this repository.
2. Download the tagged source archive from GitHub and compute its SHA256.
3. Render `packaging/homebrew/swiftnest.rb.template` into the tap repository as `Formula/swiftnest.rb` with `packaging/homebrew/render_formula.sh`.
4. Commit and push the rendered formula in the tap repository.
5. Verify the published tap with `brew install swiftnest` and `brew test swiftnest`.

For the end-to-end release sequence to run after a feature lands on `main`, follow `AGENTS.md`.

Once the tap is published, the intended install flow is:

```bash
brew tap oozoofrog/swiftnest https://github.com/oozoofrog/homebrew-swiftnest
brew install swiftnest
swiftnest onboard --target /path/to/current-ios-repo
```

The Homebrew-installed `swiftnest` command is the primary runtime entrypoint. After onboarding, continue to run the same global command from inside the target repository for `init`, `workflow`, `render-context`, and `upgrade`.

## Quick Start

This section assumes the current repository already contains the SwiftNest-managed files and that the global `swiftnest` command is installed.

### 1. Run onboarding

```bash
swiftnest onboard
```

### 2. Or run onboarding non-interactively

```bash
swiftnest onboard \
  --config config/project.yaml \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,testing-rules,location-rules \
  --workflows permissions,review \
  --non-interactive
```

### 3. Use the lower-level commands when you need finer control

```bash
cp config/project.example.yaml config/project.yaml
swiftnest init --config config/project.yaml
```

### 4. Rerender or upgrade later

```bash
swiftnest render-context
swiftnest upgrade --to advanced
swiftnest workflow list
swiftnest workflow scaffold permissions review
```

`upgrade` requires an existing `.swiftnest/state.json`, so run `init` first.

### 5. After onboarding, hand off to agent review

Start the next agent task from the repository root and point it at:

- `.swiftnest/workflows/onboarding-review.md`

That workflow is intended to verify:

- `config/project.yaml` against the real repository
- the selected profile, skills, and workflows
- whether generated docs should be rerendered with better repository-specific inputs

## Usage Scenarios

### 1. Create a Harness in a Brand-New Repository

Use this when the repository is empty or when SwiftNest should exist before the app structure is fully defined.

Recommended flow:

1. Create the new repository or enter the empty repository root.
2. Make sure the global `swiftnest` command is installed and available on `PATH`.
3. Run `onboard` into the new repository so SwiftNest installs, creates config, and initializes docs in one flow.
4. Review `config/project.yaml` and the generated `AGENTS.md`.
5. Start with a light profile and a small skill set if you need to rerun onboarding with explicit options.
6. Commit the generated `Docs/` and `.swiftnest/`.

Example:

```bash
mkdir MyNewApp
cd MyNewApp
git init

swiftnest onboard --target "$PWD"
```

### 2. Apply the Harness to an Existing iOS Project

Use this when the app already exists and SwiftNest should reflect the current project state instead of an idealized future structure.

Recommended flow:

1. Inspect the existing architecture, frameworks, permission surfaces, testing style, and naming conventions.
2. Make sure the global `swiftnest` command is installed and then run `onboard` into the repository root so SwiftNest installs, infers config defaults, and initializes docs together.
3. Review `config/project.yaml` so it reflects the real project, not an aspiration.
4. Start the first follow-up review from `.swiftnest/workflows/onboarding-review.md`.
5. Choose the profile, skills, and workflows that match the current codebase when rerunning onboarding or init with explicit options.
6. Review the generated docs against the current project and commit them.

Example:

```bash
cd /path/to/existing-ios-repo

swiftnest onboard \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,networking-rules,testing-rules \
  --workflows networking,review
```

If the project already includes location, HealthKit, or logging-heavy code paths, add those skills explicitly during initialization. Optional workflow scaffolds such as `permissions`, `networking`, or `review` can be added later with `swiftnest workflow scaffold ...`.

### 3. Start With the Harness and Evolve It Over Time

Use this when you want a low-friction starting point first and stricter rules only after the project proves it needs them.

Recommended flow:

1. Install SwiftNest once and onboard with `basic` or `intermediate`.
2. Let the team work with SwiftNest for a while.
3. Add skills as new domains become real in the codebase.
4. Upgrade the profile when review discipline needs to become stricter.
5. Regenerate and recommit the SwiftNest state whenever those choices change.

Example:

```bash
swiftnest onboard \
  --profile basic \
  --skills ios-architecture,swiftui-rules,testing-rules \
  --non-interactive

swiftnest upgrade --to intermediate
swiftnest upgrade --to advanced
swiftnest render-context
```

In this model, `.swiftnest/state.json` is the continuity anchor for future rerenders and upgrades.

Optional workflows stay opt-in. Re-running `init` resets the workflow set back to the default core workflows.

## Managed Files

The installer copies only the SwiftNest-managed files:

```text
Makefile
config/project.example.yaml
profiles/
templates/
```

If a managed file already exists in the target repository with different contents, the installer stops unless you pass `--force`.

Managed target repositories no longer receive a repo-local CLI wrapper or `tools/swiftnest-cli` sources.

## Profiles

### `basic`

- Minimal rule set
- Good for solo projects and MVPs
- Keeps process overhead low

### `intermediate`

- Balanced default for product development
- Adds stronger self-review and regression expectations
- Good fit for most active app codebases

### `advanced`

- Strict review posture for long-lived or complex products
- Stronger expectations around risks, privacy, performance, and state transitions
- Adds more explicit delivery discipline

## Available Skills

- `ios-architecture`
- `swiftui-rules`
- `concurrency-rules`
- `location-rules`
- `healthkit-rules`
- `networking-rules`
- `testing-rules`
- `logging-rules`

### Recommended Set for a Typical SwiftUI App

- `ios-architecture`
- `swiftui-rules`
- `concurrency-rules`
- `networking-rules`
- `testing-rules`

### Recommended Set for a Running or Fitness App

- `ios-architecture`
- `swiftui-rules`
- `concurrency-rules`
- `location-rules`
- `healthkit-rules`
- `testing-rules`
- `logging-rules`

## Agent Bootstrap Prompt

You can hand the following prompt to an agent together with this GitHub link:

```text
Use this repository as the SwiftNest starter:
https://github.com/oozoofrog/swift-nest

Your job is to install SwiftNest into the current iOS repository.

Follow this process:
1. Make sure the global `swiftnest` command is installed and available on `PATH`.
2. Read the README from this repository first.
3. Run the global command:
   swiftnest onboard --target <CURRENT_REPOSITORY_ROOT>
4. Start the first follow-up review from ./.swiftnest/workflows/onboarding-review.md.
5. Review config/project.yaml so it reflects the actual project state.
6. Review the generated AGENTS.md, Docs/, and .swiftnest/ output.
7. If needed, rerun swiftnest onboard or swiftnest init with explicit profile, skills, or workflows.
8. Keep Docs/ and .swiftnest/ checked into the repository.
9. Summarize the selected profile, selected skills, generated files, any workflow changes, and any assumptions.

Constraints:
- Do not run swiftnest onboard or swiftnest init from the starter checkout when the goal is to modify the current repository.
- Do not break the existing Xcode project structure.
- Do not ignore .swiftnest/.
- Prefer minimal, reviewable changes.
- If Docs/ already exists, merge carefully instead of blindly overwriting unrelated files.
- If .swiftnest/state.json already exists, treat it as the current harness state before rerendering or upgrading.
```

The point of this prompt is to let an agent use this starter repository as the reference for SwiftNest while the globally installed `swiftnest` command updates the actual app repository.

## State Files

`.swiftnest/state.json` stores the current selected state and drives later rerendering or profile upgrades.

Other files in `.swiftnest/`:

- `selected_profile.yaml`
- `selected_skills.txt`
- `rendered_context.md`
- `workflows/*.md`

Paths inside the state file are stored relative to the repository when possible, so SwiftNest survives being moved to another machine.

## Commands

From any shell where the global `swiftnest` command is installed:

```bash
swiftnest onboard --target /path/to/app-repo
make onboard TARGET=/path/to/app-repo
cd /path/to/app-repo && swiftnest install
make install-swiftnest TARGET=/path/to/app-repo
```

From a repository where SwiftNest has already been installed:

```bash
swiftnest onboard
make onboard CONFIG=config/project.yaml
swiftnest list-skills
swiftnest list-profiles
swiftnest --version
swiftnest init --config config/project.yaml --workflows permissions,review
swiftnest workflow list
swiftnest workflow print onboarding-review
swiftnest workflow print add-feature
swiftnest workflow scaffold permissions review
swiftnest render-context
swiftnest upgrade --to intermediate
make init CONFIG=config/project.yaml
make context
make upgrade PROFILE=advanced
```

Runtime output language can be selected with a global option or environment variable:

```bash
swiftnest --lang ko --help
swiftnest --version
SWIFTNEST_LANG=ko swiftnest list-profiles
```

## Publish Your Own Copy

If you want to publish your own copy of this starter:

```bash
git init
git add .
git commit -m "Initial SwiftNest starter"
git branch -M main
git remote add origin <YOUR_GITHUB_REPO_URL>
git push -u origin main
```

## License

Replace this section with the license you want to use.
