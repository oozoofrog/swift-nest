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

## Quick Start

### 1. Copy the example config

```bash
cp config/project.example.yaml my-project.yaml
```

### 2. Edit the values

Set the project-specific values in `my-project.yaml`.

### 3. Run the initializer interactively

```bash
python3 scripts/harness.py init --config my-project.yaml
```

### 4. Run the initializer non-interactively

```bash
python3 scripts/harness.py init \
  --config my-project.yaml \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,testing-rules,location-rules
```

### 5. Upgrade to a stricter profile later

```bash
python3 scripts/harness.py upgrade --to advanced
```

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

## Optional Reference Docs

You can optionally extract Apple-authored reference documents that are useful when refining harness rules.

```bash
make extract-xcode-docs XCODE_APP=/Applications/Xcode.app
```

Or:

```bash
python3 scripts/extract_xcode_reference_docs.py --xcode-app /Applications/Xcode.app
```

This export does not include assistant prompts or model/runtime metadata. It only curates:

- `IDEIntelligenceChat.framework/Resources/AdditionalDocumentation/*.md`
- A selected subset of Swift diagnostics documents related to concurrency and safety

The output is written to `references/xcode-<version>-docs/` with this layout:

- `apple-guides/`
- `swift-diagnostics/`
- `README.md`
- `SUMMARY.md`
- `MANIFEST.json`

See [REFERENCE_UPDATE_NOTES.md](Docs/REFERENCE_UPDATE_NOTES.md) for the harness-facing changes derived from these references.

## Install Into an Existing iOS Repository

This starter is designed to work both as a standalone template repository and as a source of harness files for an existing iOS repository.

An agent can install the harness into a real app repository by following this process:

1. Read this README first.
2. Copy the required harness files into the target repository root.
3. Create or update `config/project.yaml` for that app.
4. Choose the correct profile and skills.
5. Run the initializer from the target repository root.
6. Commit the generated `Docs/` and `.ai-harness/` outputs.

Minimum files to copy into the target repository:

```text
scripts/harness.py
templates/
profiles/
config/project.example.yaml
Makefile
```

Recommended checks:

- Make sure `.ai-harness/` is not ignored by `.gitignore`.
- Review any existing `Docs/` directory before overwriting files.
- Pick an explicit profile and skill set rather than relying on assumptions.

Example installation flow:

```bash
git clone https://github.com/oozoofrog/ios-ai-harness-starter.git /tmp/ios-ai-harness-starter
rsync -av \
  /tmp/ios-ai-harness-starter/scripts \
  /tmp/ios-ai-harness-starter/templates \
  /tmp/ios-ai-harness-starter/profiles \
  /tmp/ios-ai-harness-starter/config \
  /tmp/ios-ai-harness-starter/Makefile \
  /path/to/your-ios-repo/

cd /path/to/your-ios-repo
cp config/project.example.yaml config/project.yaml
python3 scripts/harness.py init \
  --config config/project.yaml \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,networking-rules,testing-rules
```

## Agent Bootstrap Prompt

You can hand the following prompt to an agent together with this GitHub link:

```text
Use this repository as the harness starter:
https://github.com/oozoofrog/ios-ai-harness-starter

Your job is to install this AI harness into the current iOS repository.

Follow this process:
1. Read the README from the starter repository first.
2. Copy the required harness files into the current repository:
   - scripts/harness.py
   - templates/
   - profiles/
   - config/project.example.yaml
   - Makefile
3. Create or update config/project.yaml for this app based on the actual project.
4. Choose an appropriate profile and skills for this codebase.
5. Run the harness initializer from the current repository root.
6. Keep Docs/ and .ai-harness/ checked into the repository.
7. Summarize the selected profile, selected skills, generated files, and any assumptions.

Constraints:
- Do not break the existing Xcode project structure.
- Do not ignore .ai-harness/.
- Prefer minimal, reviewable changes.
- If Docs/ already exists, merge carefully instead of blindly overwriting unrelated files.
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

```bash
python3 scripts/harness.py list-skills
python3 scripts/harness.py list-profiles
python3 scripts/harness.py init --config my-project.yaml
python3 scripts/harness.py render-context
python3 scripts/harness.py upgrade --to intermediate
python3 scripts/extract_xcode_reference_docs.py --xcode-app /Applications/Xcode.app
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
