#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import plistlib
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_SUBPATH = Path("Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources")
DEFAULT_XCODE_CANDIDATES = [
    Path("/Applications/Xcode.app"),
    Path("/Volumes/eyedisk/Applications/Xcode.app"),
]

PROMPT_CATEGORIES = {
    "system-core": {
        "description": "Top-level assistant personas and tool-aware system prompts that shape the harness voice and default coding rules.",
        "start_here": [
            "BasicSystemPrompt",
            "ReasoningSystemPrompt",
            "ToolAssistedBasicSystemPrompt",
            "AgentSystemPromptAddition",
        ],
        "files": [
            "AgentSystemPromptAddition",
            "BasicSystemPrompt",
            "ReasoningSystemPrompt",
            "TextEditorToolSystemPrompt",
            "ToolAssistedBasicSystemPrompt",
            "ToolAssistedReasoningSystemPrompt",
        ],
    },
    "integration-and-editing": {
        "description": "Edit-oriented prompts that show how Xcode structures full-file rewrites, fast-apply edits, and code integration flows.",
        "start_here": [
            "IntegratorSystemPrompt",
            "IntegratorUserPrompt",
            "FastApplyIntegratorSystemPrompt",
            "NewCodeIntegratorSystemPrompt",
        ],
        "files": [
            "FastApplyIntegratorSystemPrompt",
            "FastApplyIntegratorUserPrompt",
            "IntegratorSystemPrompt",
            "IntegratorUserPrompt",
            "NewCodeIntegratorSystemPrompt",
            "NewCodeIntegratorUserPrompt",
            "OriginalFile",
        ],
    },
    "planning-and-variants": {
        "description": "Planner and variant prompts that show orchestration strategies, model-specific prompt variants, and experimental branches.",
        "start_here": [
            "PlannerExecutorStylePlannerSystemPrompt",
            "PlannerExecutorStylePlannerSystemPrompt-gpt_5",
            "VariantASystemPrompt",
            "VariantBSystemPrompt",
        ],
        "files": [
            "PlannerExecutorStyleNoClassify",
            "PlannerExecutorStylePlannerSystemPrompt",
            "PlannerExecutorStylePlannerSystemPrompt-gpt_5",
            "VariantASystemPrompt",
            "VariantBSystemPrompt",
        ],
    },
    "context-and-grounding": {
        "description": "Context-packing templates that explain what Xcode injects alongside the user query: files, selections, issues, snippets, and other grounding inputs.",
        "start_here": [
            "Query",
            "CurrentFile",
            "CurrentSelection",
            "ContextItems",
            "AgentAdditionalContext",
        ],
        "files": [
            "AdditionalFiles",
            "AgentAdditionalContext",
            "ContextItems",
            "CurrentFile",
            "CurrentFileAbbreviated",
            "CurrentFileName",
            "CurrentSelection",
            "Interfaces",
            "Issues",
            "NewKnowledge",
            "NoSelection",
            "Query",
            "SearchResults",
            "Snippets",
        ],
    },
    "guidelines-and-retrieval": {
        "description": "Guideline and retrieval support prompts that reveal how Xcode constrains answers, expands searches, and injects retrieval hints.",
        "start_here": [
            "InQueryDetailedGuidelines",
            "ToolAssistedInQueryDetailedGuidelines",
            "InstructionEmbeddingsQueryExpansion",
            "LocalInfillEmbeddingsQueryExpansion",
        ],
        "files": [
            "ChatTitleResolver",
            "InQueryDetailedGuidelines",
            "InQueryShortGuidelines",
            "InstructionEmbeddingsQueryExpansion",
            "LocalInfillEmbeddingsQueryExpansion",
            "ToolAssistedInQueryDetailedGuidelines",
            "ToolAssistedInQueryShortGuidelines",
        ],
    },
    "generation-tools": {
        "description": "Task-shaped templates for explanation, documentation, preview generation, and playground generation that can inspire harness workflows.",
        "start_here": [
            "CodingToolTemplateExplain",
            "CodingToolTemplateDocument",
            "GenerateDocumentation",
            "GeneratePreview",
        ],
        "files": [
            "CodingToolTemplateDocument",
            "CodingToolTemplateExplain",
            "CodingToolTemplateGeneratePlayground",
            "CodingToolTemplateGeneratePreview",
            "GenerateDocumentation",
            "GeneratePlayground",
            "GeneratePreview",
        ],
    },
}

PROMPT_LOOKUP = {
    filename: category
    for category, metadata in PROMPT_CATEGORIES.items()
    for filename in metadata["files"]
}

DOCS_START_HERE = [
    "FoundationModels-Using-on-device-LLM-in-your-app.md",
    "Swift-Concurrency-Updates.md",
    "SwiftUI-WebKit-Integration.md",
    "Implementing-Visual-Intelligence-in-iOS.md",
]

METADATA_FILES = {
    "AgentVersions.plist": "AgentVersions.json",
    "ApprovedIntegrationModelPairings.plist": "ApprovedIntegrationModelPairings.json",
    "version.plist": "version.json",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract and reorganize Xcode IDEIntelligenceChat prompt resources.")
    parser.add_argument(
        "--xcode-app",
        type=Path,
        default=default_xcode_app(),
        help="Path to Xcode.app",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Output directory. Defaults to references/xcode-<version>",
    )
    return parser.parse_args()


def default_xcode_app() -> Path:
    for candidate in DEFAULT_XCODE_CANDIDATES:
        if candidate.exists():
            return candidate
    return DEFAULT_XCODE_CANDIDATES[0]


def read_plist(path: Path) -> object:
    with path.open("rb") as handle:
        return plistlib.load(handle)


def xcode_version(xcode_app: Path) -> str:
    info_path = xcode_app / "Contents/Info.plist"
    info = read_plist(info_path)
    if not isinstance(info, dict) or "CFBundleShortVersionString" not in info:
        raise SystemExit(f"Unable to read Xcode version from {info_path}")
    return str(info["CFBundleShortVersionString"])


def resource_root(xcode_app: Path) -> Path:
    root = xcode_app / RESOURCE_SUBPATH
    if not root.exists():
        raise SystemExit(f"IDEIntelligenceChat resources not found under {root}")
    return root


def output_root_for(args: argparse.Namespace, version: str) -> Path:
    if args.output:
        return args.output.resolve()
    return ROOT / "references" / f"xcode-{version}"


def clean_output(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def prompt_category(stem: str) -> str:
    return PROMPT_LOOKUP.get(stem, "uncategorized")


def markdown_wrapper(
    *,
    title: str,
    xcode_version_value: str,
    category: str,
    resource_kind: str,
    source_app: Path,
    source_file: Path,
    body: str,
) -> str:
    normalized_body = body.rstrip()
    parts = [
        "---",
        f"title: {title}",
        f"xcode_version: {xcode_version_value}",
        f"category: {category}",
        f"resource_kind: {resource_kind}",
        f"source_app: {source_app}",
        f"source_file: {source_file}",
        f"original_filename: {source_file.name}",
        "---",
        "",
        f"# {title}",
        "",
        f"Source app: `{source_app}`",
        f"Source file: `{source_file}`",
        f"Category: `{category}`",
        f"Kind: `{resource_kind}`",
        "",
        "## Extracted Content",
        "",
        normalized_body,
        "",
    ]
    return "\n".join(parts)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def extract_prompts(resources: Path, output_root: Path, version: str, xcode_app: Path) -> list[dict[str, str]]:
    records: list[dict[str, str]] = []
    prompt_paths = sorted(resources.glob("*.idechatprompttemplate"))
    for path in prompt_paths:
        stem = path.stem
        category = prompt_category(stem)
        content = path.read_text(encoding="utf-8")
        destination = output_root / "prompts" / category / f"{stem}.md"
        write_text(
            destination,
            markdown_wrapper(
                title=stem,
                xcode_version_value=version,
                category=category,
                resource_kind="prompt-template",
                source_app=xcode_app,
                source_file=path,
                body=content,
            ),
        )
        records.append(
            {
                "title": stem,
                "category": category,
                "source_file": str(path),
                "output_file": str(destination.relative_to(output_root)),
            }
        )
    return records


def extract_docs(resources: Path, output_root: Path, version: str, xcode_app: Path) -> list[dict[str, str]]:
    records: list[dict[str, str]] = []
    docs_root = resources / "AdditionalDocumentation"
    if not docs_root.exists():
        return records
    for path in sorted(docs_root.glob("*.md")):
        content = path.read_text(encoding="utf-8")
        destination = output_root / "docs" / "additional-documentation" / path.name
        write_text(
            destination,
            markdown_wrapper(
                title=path.stem,
                xcode_version_value=version,
                category="additional-documentation",
                resource_kind="reference-documentation",
                source_app=xcode_app,
                source_file=path,
                body=content,
            ),
        )
        records.append(
            {
                "title": path.stem,
                "category": "additional-documentation",
                "source_file": str(path),
                "output_file": str(destination.relative_to(output_root)),
            }
        )
    return records


def extract_metadata(resources: Path, output_root: Path) -> list[dict[str, str]]:
    records: list[dict[str, str]] = []
    metadata_root = output_root / "metadata"
    metadata_root.mkdir(parents=True, exist_ok=True)
    for plist_name, json_name in METADATA_FILES.items():
        path = resources / plist_name
        payload = read_plist(path)
        destination = metadata_root / json_name
        destination.write_text(json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True), encoding="utf-8")
        records.append(
            {
                "title": path.stem,
                "category": "metadata",
                "source_file": str(path),
                "output_file": str(destination.relative_to(output_root)),
            }
        )
    return records


def build_manifest(
    *,
    version: str,
    xcode_app: Path,
    resources: Path,
    output_root: Path,
    prompts: list[dict[str, str]],
    docs: list[dict[str, str]],
    metadata: list[dict[str, str]],
) -> dict[str, object]:
    category_summary: dict[str, dict[str, object]] = {}
    for category, meta in PROMPT_CATEGORIES.items():
        category_prompts = [item for item in prompts if item["category"] == category]
        category_summary[category] = {
            "description": meta["description"],
            "start_here": meta["start_here"],
            "count": len(category_prompts),
            "files": [item["title"] for item in category_prompts],
        }
    uncategorized = [item for item in prompts if item["category"] == "uncategorized"]
    if uncategorized:
        category_summary["uncategorized"] = {
            "description": "Files that did not match the current categorization rules.",
            "start_here": [item["title"] for item in uncategorized],
            "count": len(uncategorized),
            "files": [item["title"] for item in uncategorized],
        }
    return {
        "xcode_version": version,
        "source_app": str(xcode_app),
        "resource_root": str(resources),
        "output_root": str(output_root),
        "prompt_categories": category_summary,
        "prompt_count": len(prompts),
        "documentation_count": len(docs),
        "metadata_count": len(metadata),
        "documentation_start_here": DOCS_START_HERE,
        "documentation_files": [item["title"] for item in docs],
        "metadata_files": [item["title"] for item in metadata],
    }


def render_readme(manifest: dict[str, object]) -> str:
    version = manifest["xcode_version"]
    category_summary = manifest["prompt_categories"]
    if not isinstance(category_summary, dict):
        raise SystemExit("Invalid manifest format")

    sections = [
        f"# Xcode {version} IDEIntelligenceChat Reference",
        "",
        "This folder contains a harness-friendly reorganization of Xcode's IDEIntelligenceChat resources.",
        "It is meant as reference material for evolving this project's prompt templates, workflow docs, and future profile/skill design.",
        "",
        "## Why This Structure Is Useful",
        "",
        "- `prompts/system-core/` exposes the top-level assistant persona and Apple-first coding rules that most closely map to harness-level instructions.",
        "- `prompts/integration-and-editing/` isolates the edit/integration prompts that are useful when designing precise full-file rewrite flows.",
        "- `prompts/planning-and-variants/` separates planner orchestration and variant prompts so model-specific differences are easy to compare.",
        "- `prompts/context-and-grounding/` shows how Xcode packages query, file, selection, issue, and snippet context around the model.",
        "- `prompts/guidelines-and-retrieval/` surfaces the retrieval and answer-shaping helpers that are relevant for future skill design.",
        "- `prompts/generation-tools/` groups task-specific prompt templates for explanation, documentation, preview, and playground generation.",
        "- `docs/additional-documentation/` keeps Apple-first topical reference docs in one place for fast browsing.",
        "- `metadata/` provides model and pairing metadata in JSON for quick inspection.",
        "",
        "## Prompt Categories",
        "",
    ]

    for category, info in category_summary.items():
        if not isinstance(info, dict):
            continue
        description = info.get("description", "")
        count = info.get("count", 0)
        start_here = info.get("start_here", [])
        sections.append(f"### {category}")
        sections.append(f"- Count: {count}")
        sections.append(f"- Why it matters: {description}")
        if isinstance(start_here, list) and start_here:
            sections.append(f"- Start here: {', '.join(start_here)}")
        sections.append("")

    docs_start = manifest.get("documentation_start_here", [])
    sections.extend(
        [
            "## Additional Documentation",
            "",
            "- Folder: `docs/additional-documentation/`",
            f"- Start here: {', '.join(docs_start) if isinstance(docs_start, list) else ''}",
            "",
            "## Metadata",
            "",
            "- `metadata/AgentVersions.json` shows bundled agent binary versions.",
            "- `metadata/ApprovedIntegrationModelPairings.json` shows approved executor pairings.",
            "- `metadata/version.json` captures the code intelligence bundle version metadata.",
            "",
        ]
    )
    return "\n".join(sections).rstrip() + "\n"


def main() -> int:
    args = parse_args()
    xcode_app = args.xcode_app.resolve()
    if not xcode_app.exists():
        raise SystemExit(f"Xcode.app not found at {xcode_app}")

    version = xcode_version(xcode_app)
    resources = resource_root(xcode_app)
    output_root = output_root_for(args, version)

    clean_output(output_root)
    prompts = extract_prompts(resources, output_root, version, xcode_app)
    docs = extract_docs(resources, output_root, version, xcode_app)
    metadata = extract_metadata(resources, output_root)

    manifest = build_manifest(
        version=version,
        xcode_app=xcode_app,
        resources=resources,
        output_root=output_root,
        prompts=prompts,
        docs=docs,
        metadata=metadata,
    )
    write_text(output_root / "manifest.json", json.dumps(manifest, indent=2, ensure_ascii=False, sort_keys=True) + "\n")
    write_text(output_root / "README.md", render_readme(manifest))

    print(f"Extracted Xcode {version} IDEIntelligenceChat resources to {output_root}")
    print(f"Prompts: {len(prompts)}")
    print(f"Documentation files: {len(docs)}")
    print(f"Metadata files: {len(metadata)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
