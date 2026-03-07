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
.ai-harness/
  state.json
  selected_profile.yaml
  selected_skills.txt
  rendered_context.md
  workflows/
    add-feature.md
    fix-bug.md
    refactor.md
    build.md
```

`Docs/` and `.ai-harness/` are first-class harness assets. Track them in version control by default.

The `./swiftnest` shell entrypoint builds a local macOS Swift binary on first use, so no Python runtime is required.

## Link-Only Agent Setup

If an agent only receives this GitHub link, the expected installation flow is:

1. Clone or download this starter into a temporary directory.
2. Run the shell entrypoint from the starter checkout into the target app repository with `onboard`.
3. Review the generated `config/project.yaml`, `AGENTS.md`, and `Docs/` output in the target repository.
4. Start agent work from the target repository root.
5. Commit the generated `Docs/` and `.ai-harness/` files in the target repository.

Example:

```bash
git clone https://github.com/oozoofrog/swift-nest.git /tmp/swift-nest
/tmp/swift-nest/swiftnest onboard \
  --target /path/to/current-ios-repo \
  --non-interactive
```

The first invocation builds a local Swift binary under `tools/swiftnest-cli/.build/`. Do not run `./swiftnest onboard` or `./swiftnest init` inside the starter checkout when the goal is to install SwiftNest into another repository.

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

The Homebrew-installed `swiftnest` command is bootstrap-oriented. When the current directory already contains a repo-local `./swiftnest`, the tap wrapper should delegate to that local entrypoint so follow-up commands continue to run against the repository copy.

The repo-local `./swiftnest` script still builds a local macOS Swift binary on first use, so the target repository continues to require the macOS Swift toolchain.

## Quick Start

This section assumes the current repository already contains the SwiftNest-managed files and that the macOS Swift toolchain is available.

### 1. Run onboarding

```bash
./swiftnest onboard
```

### 2. Or run onboarding non-interactively

```bash
./swiftnest onboard \
  --config config/project.yaml \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,testing-rules,location-rules \
  --workflows permissions,review \
  --non-interactive
```

### 3. Use the lower-level commands when you need finer control

```bash
cp config/project.example.yaml config/project.yaml
./swiftnest init --config config/project.yaml
```

### 4. Rerender or upgrade later

```bash
./swiftnest render-context
./swiftnest upgrade --to advanced
./swiftnest workflow list
./swiftnest workflow scaffold permissions review
```

`upgrade` requires an existing `.ai-harness/state.json`, so run `init` first.

## Usage Scenarios

### 1. Create a Harness in a Brand-New Repository

Use this when the repository is empty or when SwiftNest should exist before the app structure is fully defined.

Recommended flow:

1. Create the new repository or enter the empty repository root.
2. Clone this starter to a temporary directory.
3. Run `onboard` into the new repository so SwiftNest installs, creates config, and initializes docs in one flow.
4. Review `config/project.yaml` and the generated `AGENTS.md`.
5. Start with a light profile and a small skill set if you need to rerun onboarding with explicit options.
6. Commit the generated `Docs/` and `.ai-harness/`.

Example:

```bash
mkdir MyNewApp
cd MyNewApp
git init

git clone https://github.com/oozoofrog/swift-nest.git /tmp/swift-nest
/tmp/swift-nest/swiftnest onboard --target "$PWD"
```

### 2. Apply the Harness to an Existing iOS Project

Use this when the app already exists and SwiftNest should reflect the current project state instead of an idealized future structure.

Recommended flow:

1. Inspect the existing architecture, frameworks, permission surfaces, testing style, and naming conventions.
2. Run `onboard` into the repository root so SwiftNest installs, infers config defaults, and initializes docs together.
3. Review `config/project.yaml` so it reflects the real project, not an aspiration.
4. Choose the profile, skills, and workflows that match the current codebase when rerunning onboarding or init with explicit options.
5. Review the generated docs against the current project and commit them.

Example:

```bash
cd /path/to/existing-ios-repo

git clone https://github.com/oozoofrog/swift-nest.git /tmp/swift-nest
/tmp/swift-nest/swiftnest onboard \
  --target "$PWD" \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,networking-rules,testing-rules \
  --workflows networking,review
```

If the project already includes location, HealthKit, or logging-heavy code paths, add those skills explicitly during initialization. Optional workflow scaffolds such as `permissions`, `networking`, or `review` can be added later with `./swiftnest workflow scaffold ...`.

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
./swiftnest onboard \
  --profile basic \
  --skills ios-architecture,swiftui-rules,testing-rules \
  --non-interactive

./swiftnest upgrade --to intermediate
./swiftnest upgrade --to advanced
./swiftnest render-context
```

In this model, `.ai-harness/state.json` is the continuity anchor for future rerenders and upgrades.

Optional workflows stay opt-in. Re-running `init` resets the workflow set back to the default core workflows.

## Managed Files

The installer copies only the SwiftNest-managed files:

```text
Makefile
config/project.example.yaml
swiftnest
harness
profiles/
templates/
tools/swiftnest-cli/Package.swift
tools/swiftnest-cli/Sources/
tools/swiftnest-cli/Tests/
```

If a managed file already exists in the target repository with different contents, the installer stops unless you pass `--force`.

Local build artifacts under `tools/swiftnest-cli/.build/` are not part of the managed files and should stay ignored.

`harness` remains as a compatibility shim that forwards to `swiftnest`.

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
1. Clone or download the starter repository into a temporary directory.
2. Read the README from the starter repository first.
3. From the starter checkout, run:
   ./swiftnest onboard --target <CURRENT_REPOSITORY_ROOT>
4. Review config/project.yaml so it reflects the actual project state.
5. Review the generated AGENTS.md, Docs/, and .ai-harness/ output.
6. If needed, rerun ./swiftnest onboard or ./swiftnest init with explicit profile, skills, or workflows.
7. Keep Docs/ and .ai-harness/ checked into the repository.
8. Summarize the selected profile, selected skills, generated files, and any assumptions.

Constraints:
- Do not run ./swiftnest onboard or ./swiftnest init from the starter checkout when the goal is to modify the current repository.
- Do not break the existing Xcode project structure.
- Do not ignore .ai-harness/.
- Prefer minimal, reviewable changes.
- If Docs/ already exists, merge carefully instead of blindly overwriting unrelated files.
- If .ai-harness/state.json already exists, treat it as the current harness state before rerendering or upgrading.
```

The point of this prompt is to let an agent use this starter repository as a source of SwiftNest files while installing the actual setup into the app repository that will be worked on.

## State Files

`.ai-harness/state.json` stores the current selected state and drives later rerendering or profile upgrades.

Other files in `.ai-harness/`:

- `selected_profile.yaml`
- `selected_skills.txt`
- `rendered_context.md`
- `workflows/*.md`

Paths inside the state file are stored relative to the repository when possible, so SwiftNest survives being moved to another machine.

## Commands

From a starter checkout or any repository that already contains the managed SwiftNest files:

```bash
./swiftnest onboard --target /path/to/app-repo
make onboard TARGET=/path/to/app-repo
./swiftnest install --target /path/to/app-repo
make install-swiftnest TARGET=/path/to/app-repo
```

From a repository where SwiftNest has already been installed:

```bash
./swiftnest onboard
make onboard CONFIG=config/project.yaml
./swiftnest list-skills
./swiftnest list-profiles
./swiftnest init --config config/project.yaml --workflows permissions,review
./swiftnest workflow list
./swiftnest workflow print add-feature
./swiftnest workflow scaffold permissions review
./swiftnest render-context
./swiftnest upgrade --to intermediate
make init CONFIG=config/project.yaml
make context
make upgrade PROFILE=advanced
```

Runtime output language can be selected with a global option or environment variable:

```bash
./swiftnest --lang ko --help
SWIFTNEST_LANG=ko ./swiftnest list-profiles
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
