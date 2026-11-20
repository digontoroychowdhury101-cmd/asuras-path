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


if __name__ == "__main__":
    unittest.main()
