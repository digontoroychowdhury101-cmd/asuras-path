"""Validate the staged upload and merge only the new Model assets into the landmark registry."""
from contextlib import chdir
import hashlib
import json
import os
from pathlib import Path
import sys
from tempfile import TemporaryDirectory

ROOT = Path.cwd()
sys.path.insert(0, str(ROOT / "tools/assets"))
import registry_readback as rb

RUN = ROOT / "work/sol-bellwood-v20"
STUDIO_LEDGER = RUN / "upload-ledger.json"
REGISTRY = ROOT / "assets/LANDMARK_KIT_UPLOADED.json"
GUARDIANS = ROOT / "work/sol-bellwood-guardian-pilot"
OLD = ROOT / "work/landmark_upload_sol_gate"
HANDOFF = ROOT / "outputs/claude-open-world-2026-11-14/workers/mac-90-landmark-ledger.json"


def read(path):
    return json.loads(path.read_text())


def prepare():
    (RUN / "upload").mkdir(exist_ok=True)
    if not STUDIO_LEDGER.exists():
        STUDIO_LEDGER.write_text((RUN / "pilot-upload.json").read_text())
    if not (RUN / "upload/readback.json").exists():
        (RUN / "upload/readback.json").write_text((RUN / "pilot-readback.json").read_text())


def finish():
    expected_parts = {}
    expected_pieces = set()
    for directory in (RUN / "upload/temple", GUARDIANS / "split"):
        for manifest in directory.glob("*.split.json"):
            expected_pieces.add(manifest.name.removesuffix(".split.json"))
            for asset, nodes in read(manifest)["parts"].items():
                expected_parts[f"landmark/{Path(asset).stem}"] = (directory / asset, nodes)
    assert len(expected_pieces) == 3
    ledger = read(STUDIO_LEDGER)
    assert set(ledger) == set(expected_parts), "The upload ledger is incomplete"
    for key, (path, _nodes) in expected_parts.items():
        entry = ledger[key]
        if not entry.get("assetId") or entry.get("moderation") != "Approved":
            raise SystemExit(f"{key} still lacks an approved asset ID")
        assert entry["sha256"] == hashlib.file_digest(path.open("rb"), "sha256").hexdigest(), key
    cache = RUN / "upload/readback.json"
    mirror = rb.readback([entry["assetId"] for entry in ledger.values()], cache)
    for key, (_path, names) in expected_parts.items():
        model = mirror[ledger[key]["assetId"]]
        if sorted(model) != sorted(names) or any(not fields.get(field) for fields in model.values()
                                                    for field in ("MeshId", *rb.MAPS)):
            raise SystemExit(f"{key}: mesh names or PBR maps did not match readback")

    before = read(REGISTRY)
    with TemporaryDirectory(dir=RUN) as scratch:
        stage = Path(scratch)
        prior = read(HANDOFF)
        prior.update(read(OLD / "upload-ledger.json"))
        all_splits = stage / "splits"
        for folder in [folder for folder in (OLD / "all").iterdir() if folder.is_dir()] + [RUN / "upload/temple", GUARDIANS / "split"]:
            group = all_splits / folder.name
            group.mkdir(parents=True)
            for split in folder.glob("*.split.json"):
                (group / split.name).write_bytes(split.read_bytes())
        staging_cache = stage / "cache.json"
        staging_cache.write_text(json.dumps({**read(OLD / "rb.json"), **mirror}))
        target = stage / "assets" / REGISTRY.name
        target.parent.mkdir()
        target.write_bytes(REGISTRY.read_bytes())
        combined = {**prior, **ledger}
        assert all(row["assetId"] in read(staging_cache) for row in combined.values())
        with chdir(stage):
            rb.vesp(combined, all_splits, staging_cache, "landmark", "LANDMARK")
        result = read(target)
        for section in ("modelAssets", "pieces"):
            assert set(result[section]) == set(before[section]) | expected_pieces, section
            assert all(result[section][key] == old for key, old in before[section].items()), section
        temporary = RUN / REGISTRY.name
        temporary.write_bytes(target.read_bytes())
        os.replace(temporary, REGISTRY)
    print(f"Registered all {len(expected_parts)} approved GLBs in three pieces; existing registry IDs match.")


if __name__ == "__main__":
    if "--prepare" in sys.argv:
        prepare()
    else:
        finish()
