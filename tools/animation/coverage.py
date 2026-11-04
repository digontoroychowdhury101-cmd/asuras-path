#!/usr/bin/env python3
"""Generates outputs/combat-recovery-2026-11-02/ANIMATION_COVERAGE.md from what the game actually resolves.

    python3 tools/animation/coverage.py [--readback STUDIO_NAME_PART]

Offline it runs tools/animation/coverage_dump.luau (AnimationCatalog and WeaponSchema as built), and reads the clip manifests, publish
records, src/shared/StrikeTrajectoryData.luau and the blade report. With --readback it loads every id through
KeyframeSequenceProvider in the open Studio (Edit) and saves mac-stage3/animation_readback.json: a cell is "loaded" only from that
evidence. Without it the last saved read-back is used, so a new id reads "not read back".
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "outputs/combat-recovery-2026-11-02"
READBACK = EVIDENCE / "mac-stage3/animation_readback.json"
ACTIONS = ["Idle", "Move", "Equip", "Light1", "Light2", "Light3", "Light4", "Heavy", "Running", "WeaponArt", "Guard", "GuardImpact"]
UNIVERSAL_NOTE = {
    "Deflect": "Upper-body sword pose from the Jian set: shared by every weapon. Two-handed weapons lose the left hand from the shaft for 0.32 s; dual and fist grips borrow it. Open: per-grip clip.",
    "Roll": "Low duck; arms keyed around the Jian grip. Shared.",
    "Backdash": "Backstep hop; arms keyed around the Jian grip. Shared.",
    "DashForward": "Directional dash: arms masked, so every grip keeps its own idle arms.",
    "DashLeft": "Directional dash: arms masked.",
    "DashRight": "Directional dash: arms masked.",
    "Hitstun_Light": "Shared flinch; arms keyed around the Jian grip.",
    "Hitstun_Heavy": "Shared recoil; arms keyed around the Jian grip.",
    "StanceBroken": "Shared break; arms keyed around the Jian grip.",
    "Recover": "Shared recovery; arms keyed around the Jian grip.",
    "Deathblow_Attacker": "Finisher. Weapon-agnostic strike keyed for a one-handed grip.",
    "Deathblow_Victim": "Forced to the knees.",
    "AltarRest": "Kneeling rest. Weapon lowered, one-handed grip.",
}


def dump():
    luau = ROOT / "work/bin/luau" / ("luau.exe" if sys.platform == "win32" else "luau")
    out = subprocess.run([str(luau), str(ROOT / "tools/animation/coverage_dump.luau")], capture_output=True, text=True, cwd=str(ROOT), check=True)
    return json.loads(out.stdout.strip().splitlines()[-1])


def clip_index():
    """asset id -> (clip name, problems, record path)."""
    index = {}
    for folder in ("assets/animations/jian", "assets/animations/families"):
        base = ROOT / folder
        manifest = json.loads((base / "manifest.json").read_text())["clips"]
        published = json.loads((base / "published.json").read_text())["clips"] if (base / "published.json").exists() else {}
        for name, record in published.items():
            entry = manifest.get(name, {})
            index[record["asset_id"]] = {"name": name, "problems": entry.get("problems", []), "notes": entry.get("notes", ""), "length": entry.get("length")}
    for key in ("monk", "swordsman", "warden", "bull"):
        path = ROOT / "assets/animations/opening_cast" / key / "published.json"
        if path.exists():
            for name, record in json.loads(path.read_text()).items():
                if isinstance(record, dict) and record.get("id"):
                    index[record["id"]] = {"name": name, "problems": [], "notes": "", "length": record.get("length")}
    return index


def all_ids(data):
    ids = set()
    for weapon in data["weapons"].values():
        ids.update(c["custom"] for c in weapon["slots"].values() if c["custom"])
    ids.update(v for v in data["universal"].values() if v)
    for slots in data["characters"].values():
        ids.update(v for v in slots.values() if v)
    return sorted(ids)


def read_back(want, ids):
    sys.path.insert(0, str(ROOT / "tools"))
    from studio_mcp import Client
    client = Client()
    studio = next(s["id"] for s in json.loads(client.call("list_roblox_studios", {})[1])["studios"] if want in (s.get("name") or ""))
    results = {}
    for start in range(0, len(ids), 12):
        chunk = ids[start:start + 12]
        code = """local P = game:GetService("KeyframeSequenceProvider")
local H = game:GetService("HttpService")
local out = {}
for _, id in %s do
	local ok, seq = pcall(function() return P:GetKeyframeSequenceAsync(id) end)
	if ok then
		local last, poses = 0, 0
		local keys = seq:GetKeyframes()
		for _, k in keys do
			last = math.max(last, k.Time)
			for _, p in k:GetDescendants() do
				if p:IsA("Pose") and p.Weight > 0 then poses += 1 end
			end
		end
		out[id] = { keyframes = #keys, length = last, poses = poses, loop = seq.Loop }
	else
		out[id] = { error = tostring(seq) }
	end
end
return H:JSONEncode(out)""" % ("{" + ",".join('"%s"' % i for i in chunk) + "}")
        ok, text = client.call("execute_luau", {"code": code, "datamodel_type": "Edit", "studio_id": studio})
        results.update(json.loads(text[text.index("{"):text.rindex("}") + 1]))
    client.close()
    READBACK.parent.mkdir(parents=True, exist_ok=True)
    READBACK.write_text(json.dumps({"note": "KeyframeSequenceProvider read-back in Studio on the Mac (Edit, signed-in owner account). Evidence: runtime asset load.", "ids": results}, indent=0))
    return results


def main():
    data = dump()
    ids = all_ids(data)
    if "--readback" in sys.argv:
        readback = read_back(sys.argv[sys.argv.index("--readback") + 1], ids)
    else:
        readback = json.loads(READBACK.read_text())["ids"] if READBACK.exists() else {}
    index = clip_index()
    baked = set(re.findall(r"^\t(\w+) = \{$", (ROOT / "src/shared/StrikeTrajectoryData.luau").read_text(), re.M))
    report = json.loads((EVIDENCE / "mac-stage3/blade_vs_volume.json").read_text())
    missing_rb = [i for i in ids if i not in readback or "error" in readback[i]]
    empty = [i for i in ids if i in readback and readback[i].get("poses", 1) == 0]
    L = ["# Animation coverage", "",
         "Generated by `tools/animation/coverage.py` from the built catalog, the clip manifests and a Studio read-back of every id. It is not hand-maintained. "
         "**Published and loading does not mean it reads well:** the family sets are keyed from one parametric strike and pass the validators (reach, floor, sliding feet, weapon through body, pops). How they look in motion is human judgment, not yet done.", "",
         "Read-back: %d of %d ids loaded with keyed poses (`mac-stage3/animation_readback.json`, %s); %d not loaded; %d empty." % (len(ids) - len(missing_rb) - len(empty), len(ids), "Studio on the Mac" if readback else "not run", len(missing_rb), len(empty)), "",
         "## Weapon entries and the sets they actually play", "",
         "12 weapon entries play 11 sets. The Calamity Bone Cleaver plays the Odachi's clips: identical frame data, blade length and grip class.", "",
         "| Weapon | Grip (schema) | Lights | Set played | Clips present | Baked blade moves | Open |", "|---|---|---|---|---|---|---|"]
    open_notes = {
        "Unarmed": "Two lights strike with the left hand; volume stays generic. No blade trajectory.",
        "ChainScythe": "The 15-stud reach is the chain; a body clip only moves the hand and the chain is welded rigid. The hit volume far exceeds the visible weapon.",
        "PrayerOfTheDefiled": "The 12-stud reach is the censer; its chain is welded rigid, so it swings as a stiff flail. The hit volume far exceeds the visible weapon.",
        "Catalyst": "Staff strikes reach about 4 studs visibly; 8-stud volume is generic.",
        "Odachi": "Blade 6 studs vs reach 13: visibly short by 3+ studs even with the step. Decision: longer model or shorter reach (MAC_TO_WINDOWS).",
        "CalamityBoneCleaver": "As the Odachi.",
        "HeavenPiercingGuandao": "Blade 7 studs vs reach 14: as the Odachi.",
    }
    for wid, w in data["weapons"].items():
        slots = w["slots"]
        played = sorted({c["slot"].split(".")[0] for c in slots.values()})
        present = sum(1 for k in ACTIONS if slots[k]["custom"])
        usable = [k for k in ACTIONS if not k.startswith("Light") or int(k[5:]) <= w["lights"]]
        have = sum(1 for k in usable if slots[k]["custom"])
        moves = [m for m in baked if m.startswith(wid + "_")]
        L.append("| %s | %s | %d | %s | %d of %d usable | %d | %s |" % (wid, w["grip"], w["lights"], ", ".join(played), have, len(usable), len(moves), open_notes.get(wid, "Human review of motion.")))
    L += ["", "## Player weapon actions", "", "Each cell: clip name, or **none** if nothing plays. `·` is a light the weapon's chain never requests. `*` is a baked blade that hit volumes, trails and the step share.", ""]
    L.append("| Weapon | " + " | ".join(ACTIONS) + " |")
    L.append("|---|" + "---|" * len(ACTIONS))
    MOVE = {"Light1": "_L1", "Light2": "_L2", "Light3": "_L3", "Light4": "_L4", "Heavy": "_Heavy", "Running": "_Running", "WeaponArt": "_Art"}
    for wid, w in data["weapons"].items():
        cells = []
        for key in ACTIONS:
            slot = w["slots"][key]
            if key.startswith("Light") and int(key[5:]) > w["lights"]:
                cells.append("·")
                continue
            if not slot["custom"]:
                cells.append("**none**")
                continue
            info = index.get(slot["custom"], {"name": slot["custom"].split("//")[-1]})
            mark = "*" if key in MOVE and (wid + MOVE[key]) in baked else ""
            short = info["name"].replace("HeavenPiercingGuandao", "HPG").replace("PrayerOfTheDefiled", "Prayer").replace("TwinDaggers", "Twin").replace("ChainScythe", "Chain")
            cells.append("`%s`%s" % (short, mark))
        L.append("| %s | %s |" % (wid, " | ".join(cells)))
    L += ["", "## Universal actions (every player and any fighter without its own)", "", "| Action | Clip | Loaded | Mapping |", "|---|---|---|---|"]
    for key, cid in data["universal"].items():
        info = index.get(cid or "", {})
        loaded = "no clip" if not cid else ("yes" if cid in readback and "error" not in readback[cid] else "NOT read back")
        L.append("| %s | %s | %s | %s |" % (key, "`%s`" % info.get("name", cid) if cid else "**none**", loaded, UNIVERSAL_NOTE.get(key, "")))
    L += ["", "## Production mobs (own clips, listed apart from the player sets)", "",
          "A key a mob lacks falls back to its weapon's set. Their blades stay generic: `StrikeTrajectories.forFighter` returns nil, and the mob clips are not baked (open).", "",
          "| Definition | Weapon | Keys with clips | Falls back to its weapon set for |", "|---|---|---|---|"]
    weapon_of = {"CorruptWanderingMonk": "Unarmed", "CursedSwordsman": "Dao", "HollowBellWarden": "Guandao"}
    for definition, slots in sorted(data["characters"].items()):
        have = sorted(k for k, v in slots.items() if v)
        L.append("| %s | %s | %s | %s |" % (definition, weapon_of.get(definition, "?"), ", ".join(have), ", ".join(k for k in ACTIONS if k not in have) or "nothing"))
    L += ["", "SparringPhantom (Unarmed, tutorial) has no own clips: it plays the Unarmed set and the universal actions.", "",
          "## Bosses (BossAnimationRules, own resolver)", "",
          "Bosses never use the sets above: `FighterAnimations` skips them and `BossAnimations` resolves `<Look>_P<n>_<Action>` from `AsuraBossAnimations` (General Zhao: 59 published clips in `assets/animations/general_zhao`). A boss's blade stays generic even when its schema weapon has a baked set (`CharacterService.commitStrike`). "
          "Slots without a clip fall back to a stock stand-in for humanoids and procedural motion for creatures, as listed by `tools/test_boss_presentation.luau`; `Catalog.Enemies` Shen slots: %s. **Open:** boss contact alignment (pulses, signature attacks, scaled bodies) is unmeasured in Studio." % ", ".join("%s %s" % (k, "clip" if v else "none") for k, v in sorted(data["enemies"].items())), "",
          "## Blade against hit volume", "", "From `mac-stage3/blade_vs_volume.json`. Reach removed is an evidenced balance change to approve or revert. A move marked *generic* keeps its old volume: its clip shows too little, so the clip is what to revise.", "",
          "| Move | Design reach | Clip tip | Presented step | Visible | Removed | Design arc | Visible sweep |", "|---|---|---|---|---|---|---|---|"]
    for move, row in sorted(report.items()):
        L.append("| %s | %.2f | %.2f | %.2f | %.2f | %.2f | %.0f | %.1f |" % (move + (" *generic*" if row.get("kept_generic") else ""), row["design_reach"], row["clip_tip_reach"], row["step"], row["visible_reach"], row["reach_removed_from_volume"], row["design_arc"], row["visible_sweep_deg"]))
    problems = [(v["name"], v["problems"]) for v in index.values() if v["problems"]]
    L += ["", "## Validator problems in published clips", "", "None." if not problems else "\n".join("- %s: %s" % p for p in problems), ""]
    (EVIDENCE / "ANIMATION_COVERAGE.md").write_text("\n".join(L))
    print("ids", len(ids), "not loaded", len(missing_rb), "empty", len(empty), "problems", len(problems))


if __name__ == "__main__":
    main()
