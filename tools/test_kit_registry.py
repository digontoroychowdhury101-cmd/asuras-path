"""Tests for tools/assets/kit_registry.py. Fixtures live in a temp dir with obviously fake IDs; nothing is written to assets/ or src/."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/assets"))
import kit_registry as K  # noqa: E402

LUAU = ROOT / "work/bin/luau/luau-compile"
n = iter(range(900001, 999999))


def rid():
    return f"rbxassetid://{next(n)}"


def manifest(far=False):
    mat = "Bell_Far_A" if far else "Bell_Stone"
    maps = {"ColorMap": {"file": "c.png"}} if far else {"ColorMap": "c.png", "NormalMap": "n.png", "RoughnessMap": "r.png"}
    subs = ["Canopy_Tree_A_Far__Bark", "Canopy_Tree_A_Far__Leaves"] if far else ["Bell_Stair__Stone", "Bell_Stair__Rail"]
    piece = subs[0].split("__")[0]
    return {"materials": {mat: maps}, "pieces": {piece: {"sub_mesh_materials": {s: mat for s in subs}}}}, piece, subs


def entry(far=False):
    e = {"MeshId": rid(), "ColorMap": rid()}
    if not far:
        e.update(NormalMap=rid(), RoughnessMap=rid())
    return e


def build(root, kit, packs, far=False, reg=None):
    man, piece, subs = manifest(far)
    for p in packs:
        d = root / "assets/source/overworld/upload" / p
        d.mkdir(parents=True)
        (d / "upload_manifest.json").write_text(json.dumps(man))
    (root / "src/shared").mkdir(parents=True)
    pieces = {piece: {s: entry(far) for s in subs}} if reg is None else reg(piece, subs)
    (root / f"assets/{K.KITS[kit][0]}_KIT_UPLOADED.json").write_text(json.dumps({"pieces": pieces}))
    return piece, subs


class KitRegistry(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.root = Path(self.t.name)
        self.addCleanup(self.t.cleanup)

    def test_valid_write_parses(self):
        build(self.root, "slice", ["slice"])
        self.assertEqual(K.main(["slice", "--root", str(self.root)]), 0)
        out = self.root / "src/shared/SliceKitRegistry.luau"
        text = out.read_text()
        self.assertIn('["Bell_Stair__Stone"] = { MeshId = "rbxassetid://', text)
        if LUAU.exists():
            r = subprocess.run([str(LUAU), "--null", str(out)], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)

    def test_check_writes_nothing(self):
        build(self.root, "slice", ["slice"])
        self.assertEqual(K.main(["slice", "--check", "--root", str(self.root)]), 0)
        self.assertFalse((self.root / "src/shared/SliceKitRegistry.luau").exists())

    def test_missing_sub_refused_unless_listed(self):
        build(self.root, "slice", ["slice"], reg=lambda p, s: {p: {s[0]: entry()}})
        self.assertEqual(K.main(["slice", "--root", str(self.root)]), 1)
        self.assertFalse((self.root / "src/shared/SliceKitRegistry.luau").exists())
        self.assertEqual(K.main(["slice", "--root", str(self.root), "--allow-missing", "Bell_Stair__Rail"]), 0)
        self.assertNotIn("Bell_Stair__Rail", (self.root / "src/shared/SliceKitRegistry.luau").read_text())

    def test_non_numeric_id_refused(self):
        def reg(p, s):
            bad = entry()
            bad["MeshId"] = "rbxassetid://12ab56"
            return {p: {s[0]: bad, s[1]: entry()}}
        build(self.root, "slice", ["slice"], reg=reg)
        errs, _ = K.validate("slice", self.root)
        self.assertTrue(any("MeshId" in e for e in errs))
        self.assertEqual(K.main(["slice", "--root", str(self.root)]), 1)
        self.assertFalse((self.root / "src/shared/SliceKitRegistry.luau").exists())

    def test_duplicate_mesh_id_and_unknown_sub_refused(self):
        def reg(p, s):
            a = entry()
            b = entry()
            b["MeshId"] = a["MeshId"]
            return {p: {s[0]: a, s[1]: b, p + "__Ghost": entry()}}
        build(self.root, "slice", ["slice"], reg=reg)
        errs, _ = K.validate("slice", self.root)
        self.assertTrue(any("already used" in e for e in errs))
        self.assertTrue(any("Ghost" in e for e in errs))

    def test_far_keys(self):
        piece, subs = build(self.root, "bellwood_far", ["bellwood_far"], far=True)
        self.assertEqual(K.main(["bellwood_far", "--root", str(self.root)]), 0)
        text = (self.root / "src/shared/BellwoodFarKitRegistry.luau").read_text()
        self.assertIn('["Canopy_Tree_A_Far"] = {', text)
        self.assertIn('["Canopy_Tree_A_Far__Leaves"] = {', text)
        self.assertNotIn("NormalMap", text)  # far materials carry a colour map only

    def test_missing_required_map_refused(self):
        def reg(p, s):
            e = entry()
            del e["NormalMap"]
            return {p: {s[0]: e, s[1]: entry()}}
        build(self.root, "slice", ["slice"], reg=reg)
        self.assertEqual(K.main(["slice", "--check", "--root", str(self.root)]), 1)


if __name__ == "__main__":
    unittest.main()
