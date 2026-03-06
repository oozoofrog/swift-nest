#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]

MANAGED_PATHS = [
    Path("Makefile"),
    Path("config/project.example.yaml"),
    Path("profiles"),
    Path("scripts/harness.py"),
    Path("scripts/install_harness.py"),
    Path("templates"),
]


def iter_managed_files() -> list[tuple[Path, Path]]:
    files: list[tuple[Path, Path]] = []
    for rel_path in MANAGED_PATHS:
        source = ROOT / rel_path
        if not source.exists():
            raise SystemExit(f"Managed path is missing from starter: {rel_path}")
        if source.is_dir():
            for child in sorted(source.rglob("*")):
                if child.is_file():
                    files.append((child, child.relative_to(ROOT)))
        else:
            files.append((source, rel_path))
    return files


def file_contents_match(source: Path, destination: Path) -> bool:
    return destination.exists() and source.read_bytes() == destination.read_bytes()


def gitignore_blocks_state(target_root: Path) -> bool:
    gitignore = target_root / ".gitignore"
    if not gitignore.exists():
        return False

    for raw_line in gitignore.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line in {".ai-harness", ".ai-harness/"}:
            return True
    return False


def install_files(target_root: Path, force: bool, dry_run: bool) -> tuple[int, int]:
    conflicts: list[str] = []
    copied = 0
    unchanged = 0

    for source, rel_path in iter_managed_files():
        destination = target_root / rel_path
        if destination.exists() and destination.is_dir():
            raise SystemExit(f"Expected file but found directory at target path: {rel_path}")
        if destination.exists():
            if file_contents_match(source, destination):
                unchanged += 1
                continue
            if not force:
                conflicts.append(str(rel_path))
                continue

        if dry_run:
            action = "overwrite" if destination.exists() else "copy"
            print(f"{action}: {rel_path}")
            copied += 1
            continue

        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        copied += 1

    if conflicts:
        joined = "\n".join(f"- {path}" for path in conflicts)
        raise SystemExit(
            "Refusing to overwrite managed files in the target repository.\n"
            "Re-run with --force if these files should be replaced:\n"
            f"{joined}"
        )

    return copied, unchanged


def print_warnings(target_root: Path) -> None:
    warnings: list[str] = []
    if gitignore_blocks_state(target_root):
        warnings.append(".gitignore ignores .ai-harness/. Remove that rule before committing generated state.")
    if (target_root / "Docs").exists():
        warnings.append("Docs/ already exists. Review generated files after init before committing.")
    if (target_root / ".ai-harness").exists():
        warnings.append(".ai-harness/ already exists. Review current state before rerendering or upgrading.")

    for message in warnings:
        print(f"warning: {message}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Install harness-managed files into a target repository."
    )
    parser.add_argument(
        "--target",
        required=True,
        help="Path to the repository directory that should receive the harness files.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite conflicting managed files in the target repository.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show which managed files would be copied without writing anything.",
    )
    args = parser.parse_args()

    target_root = Path(args.target).expanduser().resolve()
    if target_root == ROOT:
        raise SystemExit("Target repository must be different from the starter repository root.")
    target_root.mkdir(parents=True, exist_ok=True)

    copied, unchanged = install_files(target_root, force=args.force, dry_run=args.dry_run)
    print_warnings(target_root)

    mode = "Previewed" if args.dry_run else "Installed"
    print(f"{mode} harness-managed files into {target_root}")
    print(f"Changed files: {copied}")
    print(f"Unchanged files: {unchanged}")

    if not args.dry_run:
        print("Next steps:")
        print(f"  cd {target_root}")
        print("  test -f config/project.yaml || cp config/project.example.yaml config/project.yaml")
        print("  edit config/project.yaml")
        print("  python3 scripts/harness.py init --config config/project.yaml --profile intermediate")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
