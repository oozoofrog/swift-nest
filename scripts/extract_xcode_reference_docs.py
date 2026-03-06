#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CHAT_DOCS_ROOT = Path(
    "Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation"
)
SWIFT_DIAGNOSTICS_ROOT = Path(
    "Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/share/doc/swift/diagnostics"
)

APPLE_GUIDE_CATEGORIES = {
    "app-capabilities": [
        "AppIntents-Updates.md",
        "FoundationModels-Using-on-device-LLM-in-your-app.md",
        "Implementing-Visual-Intelligence-in-iOS.md",
        "MapKit-GeoToolbox-PlaceDescriptors.md",
        "StoreKit-Updates.md",
        "SwiftData-Class-Inheritance.md",
        "SwiftUI-AlarmKit-Integration.md",
    ],
    "ui-and-design": [
        "AppKit-Implementing-Liquid-Glass-Design.md",
        "Foundation-AttributedString-Updates.md",
        "Swift-Charts-3D-Visualization.md",
        "SwiftUI-Implementing-Liquid-Glass-Design.md",
        "SwiftUI-New-Toolbar-Features.md",
        "SwiftUI-Styled-Text-Editing.md",
        "SwiftUI-WebKit-Integration.md",
        "UIKit-Implementing-Liquid-Glass-Design.md",
        "WidgetKit-Implementing-Liquid-Glass-Design.md",
        "Widgets-for-visionOS.md",
    ],
    "accessibility-and-language": [
        "Implementing-Assistive-Access-in-iOS.md",
        "Swift-Concurrency-Updates.md",
        "Swift-InlineArray-Span.md",
    ],
}

DIAGNOSTIC_CATEGORIES = {
    "actor-isolation": [
        "actor-isolated-call.md",
        "conformance-isolation.md",
        "isolated-conformances.md",
        "nonisolated-nonsending-by-default.md",
        "preconcurrency-import.md",
    ],
    "sendable-and-safety": [
        "mutable-global-variable.md",
        "sendable-closure-captures.md",
        "sendable-metatypes.md",
        "sending-closure-risks-data-race.md",
        "sending-risks-data-race.md",
        "strict-memory-safety.md",
    ],
}


def read_plist(path: Path) -> Any:
    with path.open("rb") as handle:
        return plistlib.load(handle)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_slug(value: str) -> str:
    return value.replace("/", "-").replace(" ", "-")


def reset_output(output_root: Path) -> None:
    for name in ["apple-guides", "swift-diagnostics", "README.md", "SUMMARY.md", "MANIFEST.json"]:
        target = output_root / name
        if target.is_dir():
            shutil.rmtree(target)
        elif target.exists():
            target.unlink()


def copy_group(
    source_root: Path,
    output_root: Path,
    category_map: dict[str, list[str]],
    kind: str,
) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for category, names in category_map.items():
        for name in names:
            source = source_root / name
            if not source.exists():
                raise SystemExit(f"Missing source file: {source}")
            destination = output_root / category / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            records.append(
                {
                    "kind": kind,
                    "category": category,
                    "name": name,
                    "source": str(source),
                    "destination": str(destination),
                    "bytes": source.stat().st_size,
                    "sha256": sha256_file(source),
                }
            )
    return records


def build_readme(manifest: dict[str, Any]) -> str:
    top_apple = [
        "apple-guides/app-capabilities/FoundationModels-Using-on-device-LLM-in-your-app.md",
        "apple-guides/app-capabilities/AppIntents-Updates.md",
        "apple-guides/accessibility-and-language/Swift-Concurrency-Updates.md",
        "swift-diagnostics/actor-isolation/actor-isolated-call.md",
        "swift-diagnostics/sendable-and-safety/sending-risks-data-race.md",
    ]
    lines = [
        f"# Xcode {manifest['xcode_version']} Reference Docs",
        "",
        "이 폴더는 Xcode.app 안의 Apple 문서 중, 현재 하네스 설계에 직접 도움이 되는 자료만 골라 정리한 레퍼런스입니다.",
        "",
        "에이전트 프롬프트, 모델 메타데이터, 내부 실행 리소스는 의도적으로 제외했습니다.",
        "",
        "## 포함한 소스",
        "",
        f"- `{manifest['source_roots']['additional_documentation']}`",
        f"- `{manifest['source_roots']['swift_diagnostics']}`",
        "",
        "## 왜 유용한가",
        "",
        "- `concurrency-rules`를 Swift 6.2 진단 관점으로 더 구체화할 수 있습니다.",
        "- 새 스킬 후보를 평가할 때 Apple이 실제로 강조하는 API/패턴을 참고할 수 있습니다.",
        "- 하네스의 self-review 체크리스트를 Apple의 최신 경고/진단 언어와 맞출 수 있습니다.",
        "",
        "## 먼저 읽을 파일",
        "",
    ]
    lines.extend(f"- `{path}`" for path in top_apple)
    lines.extend(
        [
            "",
            "## 구조",
            "",
            "- `apple-guides/`: 기능/프레임워크 가이드",
            "- `swift-diagnostics/`: 동시성, 격리, Sendable, 안전성 관련 진단 문서",
            "- `SUMMARY.md`: 카테고리별 개요",
            "- `MANIFEST.json`: 파일 인덱스",
        ]
    )
    return "\n".join(lines) + "\n"


def build_summary(manifest: dict[str, Any]) -> str:
    lines = [
        f"# Xcode {manifest['xcode_version']} Reference Docs Summary",
        "",
        f"- Source app: `{manifest['xcode_app']}`",
        f"- Xcode build: `{manifest['xcode_build']}`",
        f"- Generated at: `{manifest['generated_at']}`",
        "",
        "## Counts",
        "",
        f"- Apple guides: {manifest['counts']['apple_guides']}",
        f"- Swift diagnostics: {manifest['counts']['swift_diagnostics']}",
        "",
        "## Apple Guides",
        "",
    ]
    for category, names in manifest["apple_guide_categories"].items():
        lines.append(f"### {category}")
        for name in names:
            lines.append(f"- `{name}`")
        lines.append("")
    lines.extend(["## Swift Diagnostics", ""])
    for category, names in manifest["diagnostic_categories"].items():
        lines.append(f"### {category}")
        for name in names:
            lines.append(f"- `{name}`")
        lines.append("")
    lines.extend(
        [
            "## Notes",
            "",
            "- This export excludes Xcode assistant prompts and model/runtime metadata.",
            "- The selected diagnostics are intentionally curated toward concurrency-safety review, not the entire Swift diagnostics corpus.",
        ]
    )
    return "\n".join(lines) + "\n"


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")


def extract_docs(xcode_app: Path, output_root: Path) -> Path:
    info = read_plist(xcode_app / "Contents" / "Info.plist")
    xcode_version = str(info.get("CFBundleShortVersionString", "unknown"))
    xcode_build = str(info.get("DTXcodeBuild", "unknown"))

    additional_docs_root = xcode_app / CHAT_DOCS_ROOT
    diagnostics_root = xcode_app / SWIFT_DIAGNOSTICS_ROOT
    if not additional_docs_root.exists():
        raise SystemExit(f"Missing AdditionalDocumentation root: {additional_docs_root}")
    if not diagnostics_root.exists():
        raise SystemExit(f"Missing Swift diagnostics root: {diagnostics_root}")

    if output_root.name == "AUTO":
        output_root = ROOT / "references" / f"xcode-{safe_slug(xcode_version)}-docs"

    output_root.mkdir(parents=True, exist_ok=True)
    reset_output(output_root)

    apple_records = copy_group(additional_docs_root, output_root / "apple-guides", APPLE_GUIDE_CATEGORIES, "apple-guide")
    diagnostic_records = copy_group(
        diagnostics_root,
        output_root / "swift-diagnostics",
        DIAGNOSTIC_CATEGORIES,
        "swift-diagnostic",
    )

    manifest = {
        "xcode_app": str(xcode_app),
        "xcode_version": xcode_version,
        "xcode_build": xcode_build,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_roots": {
            "additional_documentation": str(additional_docs_root),
            "swift_diagnostics": str(diagnostics_root),
        },
        "counts": {
            "apple_guides": len(apple_records),
            "swift_diagnostics": len(diagnostic_records),
        },
        "apple_guide_categories": APPLE_GUIDE_CATEGORIES,
        "diagnostic_categories": DIAGNOSTIC_CATEGORIES,
        "files": apple_records + diagnostic_records,
    }
    (output_root / "README.md").write_text(build_readme(manifest), encoding="utf-8")
    (output_root / "SUMMARY.md").write_text(build_summary(manifest), encoding="utf-8")
    write_json(output_root / "MANIFEST.json", manifest)
    return output_root


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract Apple-authored Xcode reference docs useful for harness design.")
    parser.add_argument("--xcode-app", required=True, help="Path to Xcode.app")
    parser.add_argument("--output", default="AUTO", help="Output directory. Defaults to references/xcode-<version>-docs")
    args = parser.parse_args()

    output = extract_docs(Path(args.xcode_app), Path(args.output))
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
