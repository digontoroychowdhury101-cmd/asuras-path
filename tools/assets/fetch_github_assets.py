"""Download the curated, pinned CC0 files; verify Git blob hashes before saving.

No repository code is executed. See assets/GITHUB_REUSE.json for source and license.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def download(url):
    return subprocess.run(
        ["curl", "--fail", "--location", "--silent", "--show-error", "--max-time", "45", url],
        check=True, capture_output=True, timeout=50,
    ).stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", default="assets/GITHUB_REUSE.json")
    args = parser.parse_args()
    manifest_path = ROOT / args.manifest
    manifest = json.loads(manifest_path.read_text())
    for entry in manifest["files"]:
        if "repository" not in entry:
            entry["repository"] = manifest["repository"]
        if "commit" not in entry:
            entry["commit"] = manifest["commit"]
        target = ROOT / entry["file"]
        url = f"https://raw.githubusercontent.com/{entry['repository']}/{entry['commit']}/{entry['path']}"
        if target.exists() and entry.get("lfs_sha256"):
            data = target.read_bytes()
            if hashlib.sha256(data).hexdigest() != entry["lfs_sha256"]:
                raise ValueError(f"LFS asset mismatch: {target}")
            print(f"Verified {entry['file']} ({len(data):,} bytes)")
            continue
        if target.exists():
            data = target.read_bytes()
        else:
            data = download(url)
        if len(data) > 10_000_000:
            raise ValueError("Asset exceeds the curated size limit")
        digest = hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()
        if digest != entry["blob_sha"]:
            raise ValueError(f"Source blob mismatch: {entry['path']}")
        if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
            pointer = data.decode()
            fields = dict(line.split(" ", 1) for line in pointer.splitlines())
            expected = fields["oid"].removeprefix("sha256:")
            if int(fields["size"]) > 10_000_000:
                raise ValueError("LFS asset exceeds size limit")
            media = f"https://media.githubusercontent.com/media/{entry['repository']}/{entry['commit']}/{entry['path']}"
            data = download(media)
            if hashlib.sha256(data).hexdigest() != expected or len(data) != int(fields["size"]):
                raise ValueError(f"LFS content mismatch: {entry['path']}")
            entry["lfs_sha256"], entry["source_pointer"] = expected, pointer
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        entry["sha256"] = hashlib.sha256(data).hexdigest()
        entry["bytes"] = len(data)
        print(f"Verified {entry['file']} ({len(data):,} bytes)")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
