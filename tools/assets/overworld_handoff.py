#!/usr/bin/env python3
"""Pack/restore the ignored overworld sources without checking out the asset branch.

The code branch pins both the archive and every source file by SHA-256. Restore is
a dry run unless --apply is given, and never replaces a differing local file.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
NOTES = ROOT / "outputs/claude-open-world-2026-11-14/handoff"
SOURCES = ("assets/source/overworld", "assets/source/audio/overworld")
BRANCH = "codex/overworld-assets-2026-11-16"
ARCHIVE = "overworld-assets-2026-11-16.zip"
HASH = re.compile(r"[0-9a-f]{64}\Z")


def sha(path):
    with Path(path).open("rb") as handle:
        return stream_sha(handle)


def stream_sha(handle):
    digest = hashlib.sha256()
    for block in iter(lambda: handle.read(1024 * 1024), b""):
        digest.update(block)
    return digest.hexdigest()


def encoded(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def destination(root, rel):
    p = PurePosixPath(rel)
    if (p.is_absolute() or "\\" in rel or any(x in (".", "..") for x in rel.split("/"))
            or not any(rel.startswith(prefix + "/") for prefix in SOURCES)):
        raise ValueError(f"Invalid source path: {rel}")
    root = Path(root).resolve()
    target = root.joinpath(*p.parts)
    if not target.resolve().is_relative_to(root):
        raise ValueError(f"Source path escapes destination: {rel}")
    for node in (target, *target.parents):
        if node == root:
            break
        if node.is_symlink():
            raise ValueError(f"Symlink in destination: {rel}")
    return target


def checked_manifest(raw):
    manifest = json.loads(raw)
    if manifest.get("format") != 1 or not manifest.get("files"):
        raise ValueError("Unsupported or empty asset manifest")
    seen = set()
    for entry in manifest["files"]:
        rel, digest, size = entry["path"], entry["sha256"], entry["bytes"]
        destination(ROOT, rel)
        if rel.casefold() in seen or not HASH.fullmatch(digest) or not isinstance(size, int) or size < 0:
            raise ValueError(f"Invalid or duplicate manifest entry: {rel}")
        seen.add(rel.casefold())
    return manifest


def pack(output):
    output = Path(output).resolve()
    if output.exists() and any(output.iterdir()):
        raise ValueError("Use a new empty output directory; existing bundles are immutable")
    output.mkdir(parents=True, exist_ok=True)
    files, objects = [], {}
    excluded = []
    for prefix in SOURCES:
        if not (ROOT / prefix).is_dir():
            raise ValueError(f"Missing source directory: {prefix}")
        for path in sorted((ROOT / prefix).rglob("*")):
            if path.is_symlink():
                raise ValueError(f"Symlink in source: {path}")
            if not path.is_file():
                continue
            rel = path.relative_to(ROOT).as_posix()
            if path.suffix == ".blend1":
                excluded.append(rel)
                continue
            before = path.stat()
            digest = sha(path)
            if (before.st_size, before.st_mtime_ns) != (path.stat().st_size, path.stat().st_mtime_ns):
                raise ValueError(f"Source changed during snapshot: {rel}")
            files.append({"path": rel, "bytes": before.st_size, "sha256": digest})
            objects.setdefault(digest, path)
    manifest_raw = encoded({"format": 1, "files": files, "excluded_blender_backups": excluded})
    checked_manifest(manifest_raw)
    archive = output / ARCHIVE
    print(f"Packing {len(files)} files, {len(objects)} unique contents (Blender .blend1 backups excluded)", flush=True)
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        z.writestr("ASSET_MANIFEST.json", manifest_raw)
        for digest, path in objects.items():
            z.write(path, "blobs/" + digest)
    parts = []
    with archive.open("rb") as src:
        for index in range(10000):
            block = src.read(80 * 1024 * 1024)
            if not block:
                break
            name = f"{ARCHIVE}.part{index:03d}"
            (output / name).write_bytes(block)
            parts.append({"name": name, "bytes": len(block), "sha256": hashlib.sha256(block).hexdigest()})
    bundle = encoded({"format": 1, "branch": BRANCH, "archive": ARCHIVE,
                      "archive_sha256": sha(archive), "archive_bytes": archive.stat().st_size,
                      "manifest_sha256": hashlib.sha256(manifest_raw).hexdigest(),
                      "file_count": len(files), "source_bytes": sum(f["bytes"] for f in files),
                      "unique_contents": len(objects), "parts": parts})
    NOTES.mkdir(parents=True, exist_ok=True)
    for name, data in (("BUNDLE.json", bundle), ("ASSET_MANIFEST.json", manifest_raw)):
        (output / name).write_bytes(data)
        (NOTES / name).write_bytes(data)
    print(f"Archive {archive.stat().st_size:,} bytes, {len(parts)} parts; SHA-256 {sha(archive)}", flush=True)


def git_bytes(repo, *args):
    return subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True).stdout


def join_parts(repo, branch, bundle, cache):
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / ARCHIVE
    if archive.is_file() and sha(archive) == bundle["archive_sha256"]:
        return archive
    temp = archive.with_suffix(".joining")
    try:
        with temp.open("wb") as dst:
            for index, part in enumerate(bundle["parts"]):
                if part["name"] != f"{ARCHIVE}.part{index:03d}" or not HASH.fullmatch(part["sha256"]):
                    raise ValueError("Invalid or out-of-order archive part")
                digest, length = hashlib.sha256(), 0
                with subprocess.Popen(["git", "cat-file", "blob", f"{branch}:{part['name']}"],
                                      cwd=repo, stdout=subprocess.PIPE) as proc:
                    for block in iter(lambda: proc.stdout.read(1024 * 1024), b""):
                        digest.update(block)
                        length += len(block)
                        dst.write(block)
                    if proc.wait() != 0:
                        raise ValueError(f"Cannot read {part['name']}; fetch the asset branch first")
                if length != part["bytes"] or digest.hexdigest() != part["sha256"]:
                    raise ValueError(f"Archive part checksum mismatch: {part['name']}")
        if temp.stat().st_size != bundle["archive_bytes"] or sha(temp) != bundle["archive_sha256"]:
            raise ValueError("Joined archive checksum mismatch")
        temp.replace(archive)
    finally:
        if temp.exists():
            temp.unlink()
    return archive


def restore_archive(archive, manifest_raw, root, apply):
    manifest = checked_manifest(manifest_raw)
    objects = {}
    for entry in manifest["files"]:
        prior = objects.setdefault(entry["sha256"], entry["bytes"])
        if prior != entry["bytes"]:
            raise ValueError("Conflicting sizes for identical content")
    with zipfile.ZipFile(archive) as z:
        expected = {"ASSET_MANIFEST.json"} | {"blobs/" + h for h in objects}
        if len(z.namelist()) != len(expected) or set(z.namelist()) != expected:
            raise ValueError("Archive entries do not match the manifest")
        if z.read("ASSET_MANIFEST.json") != manifest_raw:
            raise ValueError("Archive manifest differs from the code branch's pinned manifest")
        for digest, size in objects.items():
            name = "blobs/" + digest
            with z.open(name) as handle:
                if z.getinfo(name).file_size != size or stream_sha(handle) != digest:
                    raise ValueError(f"Archive content checksum mismatch: {digest}")
        counts = {"add": 0, "same": 0, "DIFFERENT": 0}
        additions = []
        for entry in manifest["files"]:
            target = destination(root, entry["path"])
            if target.exists():
                state = "same" if target.is_file() and sha(target) == entry["sha256"] else "DIFFERENT"
            else:
                state = "add"
                additions.append(entry)
            counts[state] += 1
            if state == "DIFFERENT":
                print(f"DIFFERENT (preserved): {entry['path']}")
        print(json.dumps(counts, sort_keys=True), flush=True)
        if apply:
            for entry in additions:
                target = destination(root, entry["path"])
                target.parent.mkdir(parents=True, exist_ok=True)
                # Exclusive creation also prevents overwriting a file changed after the plan.
                with z.open("blobs/" + entry["sha256"]) as src, target.open("xb") as dst:
                    shutil.copyfileobj(src, dst)
            print(f"Restored {len(additions)} missing files; no existing file overwritten", flush=True)
        else:
            print("Dry run: no source files written. Add --apply to restore missing files.", flush=True)
        return 2 if counts["DIFFERENT"] else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    pack_args = sub.add_parser("pack")
    pack_args.add_argument("--output-dir", type=Path, required=True)
    restore = sub.add_parser("restore")
    restore.add_argument("--branch", default="origin/" + BRANCH)
    restore.add_argument("--root", type=Path, default=ROOT, help="Destination checkout; defaults to this repository")
    restore.add_argument("--archive", type=Path, help="Use a local joined archive instead of reading the asset branch")
    restore.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if args.command == "pack":
        pack(args.output_dir)
        return 0
    bundle_raw = (NOTES / "BUNDLE.json").read_bytes()
    bundle = json.loads(bundle_raw)
    manifest_raw = (NOTES / "ASSET_MANIFEST.json").read_bytes()
    if bundle.get("format") != 1 or hashlib.sha256(manifest_raw).hexdigest() != bundle["manifest_sha256"]:
        raise ValueError("Pinned manifest does not match bundle")
    if args.archive:
        archive = args.archive
    else:
        if git_bytes(ROOT, "show", f"{args.branch}:BUNDLE.json") != bundle_raw:
            raise ValueError("Asset branch bundle differs from this code checkpoint")
        archive = join_parts(ROOT, args.branch, bundle, args.root / "work/overworld_handoff")
    if archive.stat().st_size != bundle["archive_bytes"] or sha(archive) != bundle["archive_sha256"]:
        raise ValueError("Archive does not match the pinned bundle checksum")
    return restore_archive(archive, manifest_raw, args.root, args.apply)


if __name__ == "__main__":
    raise SystemExit(main())
