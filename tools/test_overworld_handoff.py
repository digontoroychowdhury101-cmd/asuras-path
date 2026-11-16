"""Asset handoff integrity and conflict-preservation checks (no network or Studio)."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location("handoff", Path(__file__).parent / "assets/overworld_handoff.py")
handoff = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handoff)


class HandoffTest(unittest.TestCase):
    def fixture(self, base, corrupt=False):
        data = b"original model contents\0\xff"
        digest = hashlib.sha256(data).hexdigest()
        paths = ["assets/source/overworld/a.glb", "assets/source/overworld/upload/a.glb"]
        raw = json.dumps({"format": 1, "files": [
            {"path": p, "bytes": len(data), "sha256": digest} for p in paths
        ]}).encode()
        archive = base / "fixture.zip"
        with zipfile.ZipFile(archive, "w") as z:
            z.writestr("ASSET_MANIFEST.json", raw)
            z.writestr("blobs/" + digest, b"corrupt" if corrupt else data)
        return archive, raw, paths, data

    def test_dry_run_apply_and_preserve_newer_work(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            archive, raw, paths, data = self.fixture(base)
            root = base / "checkout"
            self.assertEqual(handoff.restore_archive(archive, raw, root, False), 0)
            self.assertFalse(root.exists())
            self.assertEqual(handoff.restore_archive(archive, raw, root, True), 0)
            self.assertEqual([(root / p).read_bytes() for p in paths], [data, data])
            (root / paths[0]).write_bytes(b"newer local work")
            self.assertEqual(handoff.restore_archive(archive, raw, root, True), 2)
            self.assertEqual((root / paths[0]).read_bytes(), b"newer local work")

    def test_corruption_writes_nothing(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            archive, raw, _, _ = self.fixture(base, corrupt=True)
            root = base / "checkout"
            with self.assertRaises(ValueError):
                handoff.restore_archive(archive, raw, root, True)
            self.assertFalse(root.exists())

    def test_manifest_paths_and_aliases(self):
        for rel in ("assets/source/overworld/../../escape", "../escape", "C:/escape",
                    "assets/source/overworld\\escape", "src/server/Bootstrap.server.luau"):
            with self.assertRaises(ValueError, msg=rel):
                handoff.destination(handoff.ROOT, rel)
        digest = "a" * 64
        raw = json.dumps({"format": 1, "files": [
            {"path": p, "sha256": digest, "bytes": 1} for p in
            ("assets/source/overworld/A.glb", "assets/source/overworld/a.glb")
        ]})
        with self.assertRaises(ValueError):
            handoff.checked_manifest(raw)

    def test_symlink_destination_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            root, outside = base / "repo", base / "outside"
            (root / "assets/source").mkdir(parents=True)
            outside.mkdir()
            try:
                (root / "assets/source/overworld").symlink_to(outside, target_is_directory=True)
            except OSError as error:
                self.skipTest(f"Symlinks unavailable: {error}")
            with self.assertRaises(ValueError):
                handoff.destination(root, "assets/source/overworld/a.glb")


if __name__ == "__main__":
    unittest.main()
