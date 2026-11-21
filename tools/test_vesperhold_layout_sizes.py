"""Vesperhold layout dimensions and the client module mapping used in the place build."""
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/assets"))
import vesperhold_layout_sizes as S  # noqa: E402


class LayoutSizes(unittest.TestCase):
    def test_pieces_match_manifests(self):
        bad, n = S.drift()
        self.assertGreaterEqual(n, 38)
        self.assertEqual(bad, [], "Layout.Piece drifted from the manifests; run vesperhold_layout_sizes.py --write and re-run the massing test")

    def test_unknown_piece_is_left_alone(self):
        self.assertIsNone(S.wanted("Mist_Anchor", S.manifest_sizes()))


class ClientMapping(unittest.TestCase):
    def test_weather_packages_its_atmosphere_module(self):
        root = Path(__file__).resolve().parents[1]
        tree = json.loads((root / "default.project.json").read_text(encoding="utf-8"))["tree"]
        controllers = tree["StarterPlayer"]["StarterPlayerScripts"]["AsurasPath"]["Controllers"]
        atmosphere = controllers["VesperholdAtmosphere"]["$path"]
        weather = root / controllers["WeatherController"]["$path"]
        self.assertEqual(weather.parent / "VesperholdAtmosphere.luau", root / atmosphere)
        self.assertTrue((root / atmosphere).is_file())

    def test_required_services_and_shared_modules_are_mapped(self):
        # mac-86: LandmarkWorld / LandmarkLayout existed in src but not in the project, so the server failed to start in Studio.
        import re
        root = Path(__file__).resolve().parents[1]
        tree = json.loads((root / "default.project.json").read_text(encoding="utf-8"))["tree"]
        services = tree["ServerScriptService"]["AsurasPath"]["Services"]
        shared = tree["ReplicatedStorage"]["AsurasPath"]["Shared"]
        sibling = re.compile(r'script\.Parent(?:\.(\w+)|:WaitForChild\("(\w+)"\))')
        in_shared = re.compile(r'WaitForChild\("Shared"\):WaitForChild\("(\w+)"\)')
        missing = []
        for folder in (services, shared):
            for name, node in folder.items():
                path = isinstance(node, dict) and node.get("$path")
                if not (path and path.endswith(".luau") and (root / path).is_file()):
                    continue
                text = (root / path).read_text(encoding="utf-8")
                for m in sibling.finditer(text):
                    dep = m.group(1) or m.group(2)
                    if dep not in folder and dep not in ("Parent", "Name"):
                        missing.append(f"{name} -> script.Parent.{dep}")
                missing += [f"{name} -> Shared.{d}" for d in in_shared.findall(text) if d not in shared]
        self.assertEqual(missing, [], "required by a mapped module but not in default.project.json")


if __name__ == "__main__":
    unittest.main()
