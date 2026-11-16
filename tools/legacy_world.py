"""Pre-cutover world for the archived campaign-builder suites (ticket 08).

Overworld is frozen and Luau require cannot be intercepted, so the suites that exercise the old corridor
(MonasteryService, CampaignWorld, the five layouts) run from a copy of src/ with Overworld.Active = false.
Generated tests go in <copy>/work/ so their "../src" and "../tools" requires resolve inside the copy.
"""
import shutil
from pathlib import Path


def build(root: Path) -> Path:
    copy = root / "work" / "legacy"
    if copy.exists():
        shutil.rmtree(copy)
    shutil.copytree(root / "src", copy / "src")
    shutil.copytree(root / "tools", copy / "tools", ignore=shutil.ignore_patterns("*.py", "__pycache__"))
    (copy / "work").mkdir()
    overworld = copy / "src" / "shared" / "Overworld.luau"
    text = overworld.read_text()
    assert "Overworld.Active = true" in text, "Overworld.Active line missing"
    overworld.write_text(text.replace("Overworld.Active = true", "Overworld.Active = false", 1))
    return copy
