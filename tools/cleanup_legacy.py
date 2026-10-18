#!/usr/bin/env python3
"""Move Cagebound Phase 12 leftovers out of the active tree, reversibly.

Rules
  * Active source = every file reachable from a `$path` in default.project.json. Any other file
    under src/ is legacy (e.g. PredictionController, ArenaService, MatchmakingService, src/data).
  * Legacy tooling = the obsolete phase 2-11 tests and QA clients, the superseded Phase 12 HUD and
    input harnesses, plus every file under tools/ that references a legacy file (closure).
  * Protected files are never moved; if one still references legacy code the run aborts.
  * The run aborts before touching anything if an active source still requires a legacy module,
    or if a destination already exists.

Everything is moved (never deleted) to work/cleanup-backups/legacy-phase12/ with relative paths
preserved and a manifest.json recording each file's SHA-256. `--restore` moves them back.

Usage
  python3 tools/cleanup_legacy.py --dry-run   # print the plan only
  python3 tools/cleanup_legacy.py             # move
  python3 tools/cleanup_legacy.py --restore   # undo using the manifest
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'default.project.json'
DEST = ROOT / 'work' / 'cleanup-backups' / 'legacy-phase12'
MANIFEST = DEST / 'manifest.json'

PROTECTED = {
    'tools/build.py',
    'tools/cleanup_legacy.py',
    'tools/test_asura_stage1.luau',
    'tools/test_asura_stage2.luau',
    'tools/test_asura_stage2.py',
    'tools/test_asura_stage3.luau',
    'tools/test_backend.luau',
    'tools/test_profile_integrity.luau',
    'tools/test_commercial_systems.luau',
}

# Obsolete regardless of references: phase 2-11 suites and QA clients, and the Phase 12 HUD and
# input harnesses that assert pre-Asura behaviour of controllers rewritten in Stage 4.
OBSOLETE_PATTERNS = [
    r'^tools/test_phase([2-9]|1[01])\.luau$',
    r'^tools/qa/Phase([2-9]|1[01])\.client\.luau$',
    r'^tools/test_ui_startup\.py$',
    r'^tools/test_input_pointer\.py$',
]

SOURCE_SUFFIXES = {'.luau', '.lua', '.py', '.json', '.md'}


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def mapped_paths(node: dict) -> list[str]:
    found: list[str] = []
    if '$path' in node:
        found.append(node['$path'])
    for key, child in node.items():
        if not key.startswith('$') and isinstance(child, dict):
            found.extend(mapped_paths(child))
    return found


def active_sources() -> set[str]:
    project = json.loads(PROJECT.read_text())
    active: set[str] = set()
    for entry in mapped_paths(project['tree']):
        target = ROOT / entry
        if not target.exists():
            raise SystemExit(f'default.project.json maps a missing path: {entry}')
        if target.is_dir():
            active.update(rel(p) for p in target.rglob('*') if p.is_file())
        else:
            active.add(rel(target))
    return active


def module_name(path: str) -> str:
    name = Path(path).name
    for suffix in ('.server.luau', '.client.luau', '.luau', '.lua', '.py'):
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return name


def reference_keys(path: str) -> list[str]:
    """Strings by which other files refer to `path` (repo path and tools-relative form, no suffix)."""
    stem = path
    for suffix in ('.luau', '.lua', '.py'):
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
            break
    keys = [stem]
    if stem.startswith('tools/'):
        keys.append(stem[len('tools/'):])
    return keys


def references(text: str, keys: list[str]) -> bool:
    for key in keys:
        if re.search(r'(?<![\w])' + re.escape(key) + r'(?![\w])', text):
            return True
    return False


def requires_module(text: str, name: str) -> bool:
    pattern = re.compile(r'(require|WaitForChild|FindFirstChild)\s*\(?[^\n]*\b' + re.escape(name) + r'\b')
    return any(pattern.search(line) for line in text.splitlines() if not line.lstrip().startswith('--'))


def plan() -> list[str]:
    active = active_sources()
    legacy_src = sorted(rel(p) for p in (ROOT / 'src').rglob('*') if p.is_file() and rel(p) not in active)

    # Active code must not depend on anything about to move.
    problems = []
    for path in sorted(active):
        if not path.endswith('.luau'):
            continue
        text = (ROOT / path).read_text(errors='replace')
        for legacy in legacy_src:
            if legacy.endswith('.luau') and requires_module(text, module_name(legacy)):
                problems.append(f'{path} requires legacy module {module_name(legacy)} ({legacy})')
    if problems:
        raise SystemExit('Refusing to move: active code still depends on legacy modules:\n  ' + '\n  '.join(problems))

    tools = sorted(rel(p) for p in (ROOT / 'tools').rglob('*') if p.is_file() and p.suffix in SOURCE_SUFFIXES)
    moving: set[str] = set(legacy_src)
    for path in tools:
        if path not in PROTECTED and any(re.match(pattern, path) for pattern in OBSOLETE_PATTERNS):
            moving.add(path)

    # Closure: a tool that loads, runs or embeds a moving file is itself legacy.
    changed = True
    while changed:
        changed = False
        keys = [key for path in moving for key in reference_keys(path)]
        for path in tools:
            # This script names legacy files in its own rules; it is never a consumer of them.
            if path in moving or path == 'tools/cleanup_legacy.py':
                continue
            text = (ROOT / path).read_text(errors='replace')
            # Studio-side scripts reach modules by instance name rather than by file path.
            by_name = path.endswith('.luau') and any(
                m.startswith('src/') and m.endswith('.luau') and requires_module(text, module_name(m)) for m in moving
            )
            if by_name or references(text, keys):
                if path in PROTECTED:
                    hits = [m for m in sorted(moving) if references(text, reference_keys(m))]
                    raise SystemExit(f'Protected file {path} references legacy files: {", ".join(hits)}')
                moving.add(path)
                changed = True
    return sorted(moving)


def prune_empty(directory: Path) -> None:
    for folder in sorted((p for p in directory.rglob('*') if p.is_dir()), key=lambda p: len(p.parts), reverse=True):
        if not any(folder.iterdir()):
            folder.rmdir()


def move(paths: list[str], dry_run: bool) -> None:
    if not paths:
        print('Nothing to move: the active tree is already clean.')
        return
    clashes = [p for p in paths if (DEST / p).exists()]
    if clashes:
        raise SystemExit('Refusing to overwrite existing backups:\n  ' + '\n  '.join(clashes))
    print(f'{"Would move" if dry_run else "Moving"} {len(paths)} files to {rel(DEST)}/')
    for path in paths:
        print(f'  {path}')
    if dry_run:
        return
    previous = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {'runs': []}
    entries = []
    for path in paths:
        source = ROOT / path
        target = DEST / path
        digest = sha256(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(source), str(target))
        assert sha256(target) == digest, f'Checksum mismatch after moving {path}'
        entries.append({'path': path, 'sha256': digest})
    previous['runs'].append({'moved_at': dt.datetime.now().isoformat(timespec='seconds'), 'files': entries})
    MANIFEST.write_text(json.dumps(previous, indent=2) + '\n')
    for folder in (ROOT / 'src', ROOT / 'tools'):
        prune_empty(folder)
    print(f'Moved {len(entries)} files; manifest at {rel(MANIFEST)}')


def restore(dry_run: bool) -> None:
    if not MANIFEST.exists():
        raise SystemExit('No manifest found; nothing to restore.')
    manifest = json.loads(MANIFEST.read_text())
    files = [entry for run in manifest['runs'] for entry in run['files']]
    clashes = [e['path'] for e in files if (ROOT / e['path']).exists()]
    if clashes:
        raise SystemExit('Refusing to restore over existing files:\n  ' + '\n  '.join(clashes))
    for entry in files:
        source = DEST / entry['path']
        if not source.exists():
            raise SystemExit(f'Backup missing: {entry["path"]}')
        if sha256(source) != entry['sha256']:
            raise SystemExit(f'Backup changed since it was moved: {entry["path"]}')
    print(f'{"Would restore" if dry_run else "Restoring"} {len(files)} files')
    if dry_run:
        return
    for entry in files:
        target = ROOT / entry['path']
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(DEST / entry['path']), str(target))
    MANIFEST.unlink()
    prune_empty(DEST)
    print('Restored.')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--dry-run', action='store_true', help='print the plan without moving anything')
    parser.add_argument('--restore', action='store_true', help='move files listed in the manifest back')
    args = parser.parse_args()
    if args.restore:
        restore(args.dry_run)
    else:
        move(plan(), args.dry_run)
    return 0


if __name__ == '__main__':
    sys.exit(main())
