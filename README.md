# iOS AI Harness Starter

English | [Korean](README_kr.md)

This repository is a starter for installing a consistent AI working harness into iOS and SwiftUI codebases.

It generates project-specific rules, workflows, and task prompts so agents can work against the same constraints every time. This is not a buildable iOS app template. It is a harness starter for real app repositories.

Canonical GitHub repository:

`https://github.com/oozoofrog/ios-ai-harness-starter`

## Why This Exists

- Copying AI rules into every project by hand does not scale.
- Teams need a clean way to enable only the skills a task actually needs.
- Small projects need a lightweight setup, while larger products need stricter reviews and workflows.
- Repeating long setup prompts to Claude Code, ChatGPT, Codex, and similar agents is noisy and error-prone.

## What It Generates

The harness generates project-facing documents and state files like this:

```text
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
```

`Docs/` and `.ai-harness/` are first-class harness assets. Track them in version control by default.

The `./harness` shell entrypoint builds a local macOS Swift binary on first use, so no Python runtime is required.

## Link-Only Agent Setup

If an agent only receives this GitHub link, the expected installation flow is:

1. Clone or download this starter into a temporary directory.
2. Run the shell entrypoint from the starter checkout into the target app repository.
3. In the target repository, create `config/project.yaml`.
4. Run `init` from the target repository so generated files land in the app repository, not in the starter checkout.
5. Commit the generated `Docs/` and `.ai-harness/` files in the target repository.

Example:

```bash
git clone https://github.com/oozoofrog/ios-ai-harness-starter.git /tmp/ios-ai-harness-starter
/tmp/ios-ai-harness-starter/harness install --target /path/to/current-ios-repo

cd /path/to/current-ios-repo
test -f config/project.yaml || cp config/project.example.yaml config/project.yaml
./harness init \
  --config config/project.yaml \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,networking-rules,testing-rules
```

The first invocation builds a local Swift binary under `tools/harness-cli/.build/`. Do not run `./harness init` inside the starter checkout when the goal is to install the harness into another repository.

## Quick Start

This section assumes the current repository already contains the harness-managed files and that the macOS Swift toolchain is available.

### 1. Copy the example config

```bash
cp config/project.example.yaml config/project.yaml
```

### 2. Edit the values

Set the project-specific values in `config/project.yaml`.

### 3. Run the initializer interactively

```bash
./harness init --config config/project.yaml
```

### 4. Run the initializer non-interactively

```bash
./harness init \
  --config config/project.yaml \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,testing-rules,location-rules
```

### 5. Rerender or upgrade later

```bash
./harness render-context
./harness upgrade --to advanced
```

`upgrade` requires an existing `.ai-harness/state.json`, so run `init` first.

## Usage Scenarios

### 1. Create a Harness in a Brand-New Repository

Use this when the repository is empty or when the harness should exist before the app structure is fully defined.

Recommended flow:

1. Create the new repository or enter the empty repository root.
2. Clone this starter to a temporary directory.
3. Install the managed harness files into the new repository.
4. Create `config/project.yaml` and fill in the intended app context.
5. Start with a light profile and a small skill set.
6. Run `init` and commit the generated `Docs/` and `.ai-harness/`.

Example:

```bash
mkdir MyNewApp
cd MyNewApp
git init

git clone https://github.com/oozoofrog/ios-ai-harness-starter.git /tmp/ios-ai-harness-starter
/tmp/ios-ai-harness-starter/harness install --target "$PWD"

cp config/project.example.yaml config/project.yaml
./harness init \
  --config config/project.yaml \
  --profile basic \
  --skills ios-architecture,swiftui-rules,testing-rules
```

### 2. Apply the Harness to an Existing iOS Project

Use this when the app already exists and the harness should reflect the current project state instead of an idealized future structure.

Recommended flow:

1. Inspect the existing architecture, frameworks, permission surfaces, testing style, and naming conventions.
2. Install the managed harness files into the repository root.
3. Create `config/project.yaml` from the real project, not from aspiration.
4. Choose the profile and skills that match the current codebase.
5. Run `init`, review the generated docs against the current project, and commit them.

Example:

```bash
cd /path/to/existing-ios-repo

git clone https://github.com/oozoofrog/ios-ai-harness-starter.git /tmp/ios-ai-harness-starter
/tmp/ios-ai-harness-starter/harness install --target "$PWD"

test -f config/project.yaml || cp config/project.example.yaml config/project.yaml
./harness init \
  --config config/project.yaml \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,networking-rules,testing-rules
```

If the project already includes location, HealthKit, or logging-heavy code paths, add those skills explicitly during initialization.

### 3. Start With the Harness and Evolve It Over Time

Use this when you want a low-friction starting point first and stricter rules only after the project proves it needs them.

Recommended flow:

1. Install the harness once and initialize it with `basic` or `intermediate`.
2. Let the team work with the harness for a while.
3. Add skills as new domains become real in the codebase.
4. Upgrade the profile when review discipline needs to become stricter.
5. Regenerate and recommit the harness state whenever those choices change.

Example:

```bash
./harness init \
  --config config/project.yaml \
  --profile basic \
  --skills ios-architecture,swiftui-rules,testing-rules

./harness upgrade --to intermediate
./harness upgrade --to advanced
./harness render-context
```

In this model, `.ai-harness/state.json` is the continuity anchor for future rerenders and upgrades.

## Managed Files

The installer copies only the harness-managed files:

```text
Makefile
config/project.example.yaml
harness
profiles/
templates/
tools/harness-cli/Package.swift
tools/harness-cli/Sources/
```

If a managed file already exists in the target repository with different contents, the installer stops unless you pass `--force`.

Local build artifacts under `tools/harness-cli/.build/` are not part of the managed files and should stay ignored.

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
Use this repository as the harness starter:
https://github.com/oozoofrog/ios-ai-harness-starter

Your job is to install this AI harness into the current iOS repository.

Follow this process:
1. Clone or download the starter repository into a temporary directory.
2. Read the README from the starter repository first.
3. From the starter checkout, run:
   ./harness install --target <CURRENT_REPOSITORY_ROOT>
4. In the current repository, create config/project.yaml from config/project.example.yaml if it does not exist yet.
5. Edit config/project.yaml so it reflects the actual project state.
6. Choose an appropriate profile and skills for this codebase.
7. From the current repository root, run ./harness init --config config/project.yaml with explicit profile and skills.
8. Keep Docs/ and .ai-harness/ checked into the repository.
9. Summarize the selected profile, selected skills, generated files, and any assumptions.

Constraints:
- Do not run ./harness init from the starter checkout when the goal is to modify the current repository.
- Do not break the existing Xcode project structure.
- Do not ignore .ai-harness/.
- Prefer minimal, reviewable changes.
- If Docs/ already exists, merge carefully instead of blindly overwriting unrelated files.
- If .ai-harness/state.json already exists, treat it as the current harness state before rerendering or upgrading.
```

The point of this prompt is to let an agent use this starter repository as a source of harness files while installing the actual harness into the app repository that will be worked on.

## State Files

`.ai-harness/state.json` stores the current selected state and drives later rerendering or profile upgrades.

Other files in `.ai-harness/`:

- `selected_profile.yaml`
- `selected_skills.txt`
- `rendered_context.md`

Paths inside the state file are stored relative to the repository when possible, so the harness survives being moved to another machine.

## Commands

From a starter checkout or any repository that already contains the managed harness files:

```bash
./harness install --target /path/to/app-repo
make install-harness TARGET=/path/to/app-repo
```

From a repository where the harness has already been installed:

```bash
./harness list-skills
./harness list-profiles
./harness init --config config/project.yaml
./harness render-context
./harness upgrade --to intermediate
make init CONFIG=config/project.yaml
make context
make upgrade PROFILE=advanced
```

## Publish Your Own Copy

If you want to publish your own copy of this starter:

```bash
git init
git add .
git commit -m "Initial AI harness starter"
git branch -M main
git remote add origin <YOUR_GITHUB_REPO_URL>
git push -u origin main
```

## License

Replace this section with the license you want to use.
