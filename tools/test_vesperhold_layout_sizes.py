"""Layout.Piece sizes equal the Vesperhold manifests' bounding boxes (see tools/assets/vesperhold_layout_sizes.py to resync)."""
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


if __name__ == "__main__":
    unittest.main()
