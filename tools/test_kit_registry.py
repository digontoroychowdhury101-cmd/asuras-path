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


def build(root, kit, packs, far=False, reg=None, no_models=False):
    man, piece, subs = manifest(far)
    for p in packs:
        d = root / "assets/source/overworld/upload" / p
        d.mkdir(parents=True)
        (d / "upload_manifest.json").write_text(json.dumps(man))
    (root / "src/shared").mkdir(parents=True)
    pieces = {piece: {s: entry(far) for s in subs}} if reg is None else reg(piece, subs)
    models = {} if no_models else {pc: {"assetId": rid()} for pc in pieces}
    (root / f"assets/{K.KITS[kit][0]}_KIT_UPLOADED.json").write_text(json.dumps({"modelAssets": models, "pieces": pieces}))
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

    def test_model_asset_emitted_per_sub_and_required(self):
        build(self.root, "slice", ["slice"])
        want = json.loads((self.root / "assets/SLICE_KIT_UPLOADED.json").read_text())["modelAssets"]["Bell_Stair"]["assetId"]
        self.assertEqual(K.main(["slice", "--root", str(self.root)]), 0)
        text = (self.root / "src/shared/SliceKitRegistry.luau").read_text()
        self.assertEqual(text.count(f'Asset = "{want}"'), 2)  # one per sub-mesh
        with tempfile.TemporaryDirectory() as t:  # no modelAssets entry: refused, never invented
            build(Path(t), "slice", ["slice"], no_models=True)
            self.assertTrue(any("modelAssets.Bell_Stair.assetId" in e for e in K.validate("slice", Path(t))[0]))
        with tempfile.TemporaryDirectory() as t:  # non-numeric model id refused
            build(Path(t), "slice", ["slice"])
            f = Path(t) / "assets/SLICE_KIT_UPLOADED.json"
            d = json.loads(f.read_text())
            d["modelAssets"]["Bell_Stair"]["assetId"] = "rbxassetid://abc"
            f.write_text(json.dumps(d))
            self.assertEqual(K.main(["slice", "--check", "--root", t]), 1)

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

    def test_extra_metalness_and_shared_maps_allowed(self):
        def reg(p, s):
            a, b = entry(), entry()
            a["MetalnessMap"] = rid()
            b["NormalMap"], b["RoughnessMap"] = a["NormalMap"], a["RoughnessMap"]  # Roblox dedupes identical images
            return {p: {s[0]: a, s[1]: b}}
        build(self.root, "slice", ["slice"], reg=reg)
        self.assertEqual(K.validate("slice", self.root)[0], [])

    def test_bad_metalness_id_and_unlisted_other_map_refused(self):
        def reg(p, s):
            a = entry()
            a["MetalnessMap"] = "rbxassetid://abc"
            return {p: {s[0]: a, s[1]: entry()}}
        build(self.root, "slice", ["slice"], reg=reg)
        self.assertTrue(any("MetalnessMap" in e for e in K.validate("slice", self.root)[0]))
        with tempfile.TemporaryDirectory() as t:  # far material lists only ColorMap: a NormalMap is not a legit extra
            build(Path(t), "bellwood_far", ["bellwood_far"], far=True, reg=lambda p, s: {p: {s[0]: dict(entry(True), NormalMap=rid()), s[1]: entry(True)}})
            self.assertTrue(any("NormalMap" in e for e in K.validate("bellwood_far", Path(t))[0]))

    def test_bare_far_pieces_allowed_but_partial_refused(self):
        bare = lambda: {"MeshId": rid(), "ColorMap": "", "NormalMap": "", "RoughnessMap": "", "MetalnessMap": ""}
        build(self.root, "bellwood_far", ["bellwood_far"], far=True, reg=lambda p, s: {p: {s[0]: bare(), s[1]: bare()}})
        self.assertEqual(K.main(["bellwood_far", "--root", str(self.root)]), 0)
        self.assertNotIn("ColorMap", (self.root / "src/shared/BellwoodFarKitRegistry.luau").read_text())
        with tempfile.TemporaryDirectory() as t:  # missing MeshId is refused even on a bare piece
            build(Path(t), "bellwood_far", ["bellwood_far"], far=True, reg=lambda p, s: {p: {s[0]: dict(bare(), MeshId=""), s[1]: bare()}})
            self.assertTrue(any("MeshId" in e for e in K.validate("bellwood_far", Path(t))[0]))

    def test_shared_mesh_id_still_refused(self):
        def reg(p, s):
            a = entry()
            return {p: {s[0]: a, s[1]: dict(entry(), MeshId=a["MeshId"])}}
        build(self.root, "slice", ["slice"], reg=reg)
        self.assertTrue(any("already used" in e for e in K.validate("slice", self.root)[0]))


if __name__ == "__main__":
    unittest.main()
