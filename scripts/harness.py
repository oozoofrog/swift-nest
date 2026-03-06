#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
TEMPLATES = ROOT / "templates"
PROFILES = ROOT / "profiles"
STATE_DIR = ROOT / ".ai-harness"
STATE_FILE = STATE_DIR / "state.json"

AVAILABLE_SKILLS = sorted([p.stem for p in (TEMPLATES / "Docs" / "AI_SKILLS").glob("*.md")])

PROFILE_GUIDANCE = {
    "basic": "- Keep output concise and implementation-focused.\n- Prefer minimal abstractions.\n- Do not add extra process unless the task clearly benefits.",
    "intermediate": "- Include explicit self-review.\n- Add regression tests for bug fixes when practical.\n- Call out state transition risks when async or permission logic is involved.",
    "advanced": "- Require an explicit risks/limitations section.\n- Be strict about state transitions, privacy, and performance-sensitive paths.\n- Add regression tests for bug fixes and emphasize actor/thread correctness.",
}

WORKFLOW_GUIDANCE = {
    "basic": "- Keep reviews lightweight and focused on correctness.",
    "intermediate": "- Verify layer boundaries and regression risk before finishing.",
    "advanced": "- Verify privacy, performance, concurrency safety, and regression protection before finishing.",
}


def load_yaml_or_json(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    try:
        import yaml  # type: ignore
        data = yaml.safe_load(text)
        if not isinstance(data, dict):
            raise ValueError(f"Expected mapping in {path}")
        return data
    except ModuleNotFoundError:
        return parse_simple_yaml(text)


def parse_simple_yaml(text: str) -> dict[str, Any]:
    result: dict[str, Any] = {}
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        i += 1
        if not line or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            continue
        if line.startswith("  -"):
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        if value == "":
            items = []
            while i < len(lines) and lines[i].startswith("  -"):
                items.append(lines[i].split("-", 1)[1].strip())
                i += 1
            result[key] = items
            continue
        if value.lower() == "true":
            result[key] = True
        elif value.lower() == "false":
            result[key] = False
        elif value.startswith('"') and value.endswith('"'):
            result[key] = value[1:-1]
        else:
            result[key] = value
    return result


def save_state(data: dict[str, Any]) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def serialize_state_path(path: Path) -> str:
    resolved = path.resolve()
    try:
        return str(resolved.relative_to(ROOT))
    except ValueError:
        return str(resolved)


def resolve_state_path(path_str: str) -> Path:
    path = Path(path_str)
    return path if path.is_absolute() else ROOT / path


def load_state() -> dict[str, Any]:
    if not STATE_FILE.exists():
        raise SystemExit("No .ai-harness/state.json found. Run init first.")
    return json.loads(STATE_FILE.read_text(encoding="utf-8"))


def profile_path(name: str) -> Path:
    path = PROFILES / f"{name}.yaml"
    if not path.exists():
        raise SystemExit(f"Unknown profile: {name}")
    return path


def render_string(template: str, context: dict[str, Any]) -> str:
    for k, v in context.items():
        template = template.replace("{{" + k + "}}", str(v))
    return template


def normalize_context(config: dict[str, Any], profile_name: str) -> dict[str, Any]:
    mapping = {
        "PROJECT_NAME": config.get("project_name", "MyApp"),
        "OPTIONAL_WATCHOS_LINE": config.get("optional_watchos_line", ""),
        "UI_FRAMEWORK": config.get("ui_framework", "SwiftUI"),
        "ARCHITECTURE_STYLE": config.get("architecture_style", "MVVM"),
        "MIN_IOS_VERSION": config.get("min_ios_version", "iOS 17"),
        "PACKAGE_MANAGER": config.get("package_manager", "Swift Package Manager"),
        "TEST_FRAMEWORK": config.get("test_framework", "XCTest"),
        "LINT_TOOLS": config.get("lint_tools", "SwiftLint, SwiftFormat"),
        "NETWORK_LAYER_NAME": config.get("network_layer_name", "APIClient"),
        "PERSISTENCE_LAYER_NAME": config.get("persistence_layer_name", "Repository"),
        "LOGGING_SYSTEM": config.get("logging_system", "OSLog"),
        "PRIVACY_REQUIREMENTS": config.get("privacy_requirements", "least-privilege and privacy-safe handling"),
        "PREFERRED_FILE_LINE_LIMIT": config.get("preferred_file_line_limit", "300"),
        "HEALTHKIT_LAYER_NAME": config.get("healthkit_layer_name", "HealthKitManager"),
        "HARNESS_PROFILE": profile_name,
        "PROFILE_GUIDANCE": PROFILE_GUIDANCE[profile_name],
        "WORKFLOW_GUIDANCE": WORKFLOW_GUIDANCE[profile_name],
    }
    return mapping


def choose_skills_interactively(default_skills: list[str]) -> list[str]:
    print("Available skills:")
    for idx, skill in enumerate(AVAILABLE_SKILLS, start=1):
        mark = "*" if skill in default_skills else " "
        print(f"  {idx:>2}. [{mark}] {skill}")
    raw = input("Select skills by comma-separated numbers (Enter for defaults): ").strip()
    if not raw:
        return default_skills
    chosen = []
    for token in raw.split(","):
        token = token.strip()
        if not token:
            continue
        try:
            idx = int(token)
        except ValueError:
            raise SystemExit(f"Invalid selection: {token}")
        if idx < 1 or idx > len(AVAILABLE_SKILLS):
            raise SystemExit(f"Selection out of range: {token}")
        chosen.append(AVAILABLE_SKILLS[idx - 1])
    return sorted(set(chosen))


def choose_profile_interactively() -> str:
    profiles = sorted([p.stem for p in PROFILES.glob("*.yaml")])
    print("Profiles:")
    for idx, name in enumerate(profiles, start=1):
        print(f"  {idx}. {name}")
    raw = input("Choose profile number (default 1): ").strip() or "1"
    try:
        choice = int(raw)
    except ValueError:
        raise SystemExit("Invalid profile choice")
    if choice < 1 or choice > len(profiles):
        raise SystemExit("Profile choice out of range")
    return profiles[choice - 1]


def write_docs(root_dir: Path, context: dict[str, Any], skills: list[str], profile_name: str) -> None:
    docs_dir = root_dir / "Docs"
    skills_dir = docs_dir / "AI_SKILLS"
    docs_dir.mkdir(parents=True, exist_ok=True)
    skills_dir.mkdir(parents=True, exist_ok=True)

    for rel in ["Docs/AI_RULES.md", "Docs/AI_WORKFLOWS.md", "Docs/AI_PROMPT_ENTRY.md"]:
        src = TEMPLATES / rel
        dest = root_dir / rel
        rendered = render_string(src.read_text(encoding="utf-8"), context)
        dest.write_text(rendered, encoding="utf-8")

    # clear existing generated skills but keep unknown custom files
    manifest = skills_dir / ".generated_manifest.json"
    if manifest.exists():
        try:
            previous = json.loads(manifest.read_text(encoding="utf-8"))
            for fname in previous.get("files", []):
                p = skills_dir / fname
                if p.exists():
                    p.unlink()
        except Exception:
            pass

    generated_files = []
    for skill in skills:
        src = TEMPLATES / "Docs" / "AI_SKILLS" / f"{skill}.md"
        if not src.exists():
            raise SystemExit(f"Unknown skill template: {skill}")
        dest = skills_dir / src.name
        rendered = render_string(src.read_text(encoding="utf-8"), context)
        dest.write_text(rendered, encoding="utf-8")
        generated_files.append(src.name)
    manifest.write_text(json.dumps({"files": generated_files, "profile": profile_name}, indent=2), encoding="utf-8")


def render_context_bundle(root_dir: Path, profile_name: str, skills: list[str]) -> Path:
    docs_dir = root_dir / "Docs"
    out_dir = root_dir / ".ai-harness"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "rendered_context.md"

    sections = []
    for name in ["AI_RULES.md", "AI_WORKFLOWS.md", "AI_PROMPT_ENTRY.md"]:
        p = docs_dir / name
        if p.exists():
            sections.append(f"\n\n<!-- {name} -->\n\n" + p.read_text(encoding="utf-8"))
    for skill in skills:
        p = docs_dir / "AI_SKILLS" / f"{skill}.md"
        if p.exists():
            sections.append(f"\n\n<!-- AI_SKILLS/{skill}.md -->\n\n" + p.read_text(encoding="utf-8"))

    header = f"# Rendered AI Harness Context\n\nProfile: {profile_name}\n\nSkills: {', '.join(skills)}\n"
    out_path.write_text(header + "".join(sections), encoding="utf-8")
    return out_path


def init_cmd(args: argparse.Namespace) -> None:
    config = load_yaml_or_json(Path(args.config))
    profile_name = args.profile or choose_profile_interactively()
    profile = load_yaml_or_json(profile_path(profile_name))
    default_skills = list(profile.get("default_skills", []))

    if args.skills:
        skills = sorted(set([s.strip() for s in args.skills.split(",") if s.strip()]))
    else:
        skills = choose_skills_interactively(default_skills) if not args.non_interactive else default_skills

    context = normalize_context(config, profile_name)
    root_dir = ROOT
    write_docs(root_dir, context, skills, profile_name)
    context_path = render_context_bundle(root_dir, profile_name, skills)

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    (STATE_DIR / "selected_profile.yaml").write_text((PROFILES / f"{profile_name}.yaml").read_text(encoding="utf-8"), encoding="utf-8")
    (STATE_DIR / "selected_skills.txt").write_text("\n".join(skills) + "\n", encoding="utf-8")

    state = {
        "profile": profile_name,
        "skills": skills,
        "config_path": serialize_state_path(Path(args.config)),
        "context_path": serialize_state_path(context_path),
    }
    save_state(state)
    print(f"Initialized harness with profile '{profile_name}' and skills: {', '.join(skills)}")
    print(f"Rendered context: {context_path}")


def upgrade_cmd(args: argparse.Namespace) -> None:
    state = load_state()
    config_path = resolve_state_path(state["config_path"])
    if not config_path.exists():
        raise SystemExit(f"Config path not found: {config_path}")
    target = args.to
    profile = load_yaml_or_json(profile_path(target))
    config = load_yaml_or_json(config_path)
    current_skills = set(state.get("skills", []))
    skills = sorted(current_skills | set(profile.get("default_skills", [])))
    context = normalize_context(config, target)
    write_docs(ROOT, context, skills, target)
    context_path = render_context_bundle(ROOT, target, skills)
    state.update({"profile": target, "skills": skills, "context_path": serialize_state_path(context_path)})
    save_state(state)
    (STATE_DIR / "selected_profile.yaml").write_text((PROFILES / f"{target}.yaml").read_text(encoding="utf-8"), encoding="utf-8")
    (STATE_DIR / "selected_skills.txt").write_text("\n".join(skills) + "\n", encoding="utf-8")
    print(f"Upgraded harness to '{target}'.")
    print(f"Current skills: {', '.join(skills)}")


def render_context_cmd(args: argparse.Namespace) -> None:
    state = load_state()
    context_path = render_context_bundle(ROOT, state["profile"], state["skills"])
    print(context_path)


def list_skills_cmd(args: argparse.Namespace) -> None:
    for s in AVAILABLE_SKILLS:
        print(s)


def list_profiles_cmd(args: argparse.Namespace) -> None:
    for p in sorted(PROFILES.glob("*.yaml")):
        data = load_yaml_or_json(p)
        print(f"{p.stem}: {data.get('description', '')}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate AI harness docs for an iOS project.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_init = sub.add_parser("init", help="Initialize docs from config/profile/skills")
    p_init.add_argument("--config", required=True, help="Path to YAML/JSON config")
    p_init.add_argument("--profile", help="Profile name (basic/intermediate/advanced)")
    p_init.add_argument("--skills", help="Comma-separated skills")
    p_init.add_argument("--non-interactive", action="store_true", help="Use defaults without prompts")
    p_init.set_defaults(func=init_cmd)

    p_up = sub.add_parser("upgrade", help="Upgrade to a stricter profile")
    p_up.add_argument("--to", required=True, help="Target profile name")
    p_up.set_defaults(func=upgrade_cmd)

    p_ctx = sub.add_parser("render-context", help="Render combined context bundle")
    p_ctx.set_defaults(func=render_context_cmd)

    p_ls = sub.add_parser("list-skills", help="List available skills")
    p_ls.set_defaults(func=list_skills_cmd)

    p_lp = sub.add_parser("list-profiles", help="List available profiles")
    p_lp.set_defaults(func=list_profiles_cmd)

    args = parser.parse_args()
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
