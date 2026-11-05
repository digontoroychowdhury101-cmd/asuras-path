#!/usr/bin/env python3
"""Grandmaster Shen's data contracts (local regression; says nothing about Studio, audio playback or real play).
Clips, contacts, gait rates, sound manifest, attachments, chunks and the loadout agree with each other and with what was authored."""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUAU = ROOT / "work/bin/luau/luau"
fails = 0


def check(ok, label):
    global fails
    if not ok:
        fails += 1
        print("FAIL", label)


manifest = json.loads((ROOT / "assets/animations/opening_cast/shen/manifest.json").read_text())["clips"]
ACTIONS = ["Idle", "Strike", "WalkForward", "RunForward", "WalkBackward", "StrafeLeft", "StrafeRight", "GuardLoop", "GuardHit", "HitLightFront", "PostureBreak", "DeathblowVictim", "Death", "Transform",
           "Guandao_L1", "Guandao_L2", "Guandao_L3", "Guandao_Heavy", "Guandao_Running", "Guandao_Art"]
for phase, moves in ((1, ["FlowingJian", "PrayerBeads", "AbbotSweep"]), (2, ["BloodWave", "GuandaoSkyfall", "CrimsonEmbrace"])):
    for action in ACTIONS + moves:
        check("GrandmasterShen_P%d_%s" % (phase, action) in manifest, "clip for phase %d %s" % (phase, action))
check(len(manifest) == 46, "46 clips")

probe = (ROOT / "work/test_shen.generated.luau")
data_src = (ROOT / "src/shared/ShenPresentationData.luau").read_text()
stub = "local Color3={fromRGB=function() return 0 end}\n"
probe.write_text('''
local function data()
%s
end
local Data=data()
local Rules=require("../src/shared/BossAnimationRules")
local World=require("../src/shared/WorldDefinitions")
local Attacks=require("../src/shared/BossAttackCatalog")
local function list(t) local o={} for k,v in t do table.insert(o,k.."="..table.concat(v,",")) end return table.concat(o,";") end
local shen=World.Bosses.GrandmasterShen
print("CONTACTS "..list(Rules.Contacts.GrandmasterShen))
print("WEAPONS "..shen.Phases[1].Weapon.." "..shen.Phases[2].Weapon.." "..shen.Phases[1].Stats.ReachBonus.." "..shen.Phases[2].Stats.ReachBonus.." "..tostring(shen.Scale))
print("REVEAL "..shen.Phases[2].Transition.Reveal.." "..shen.Phases[2].Transition.Duration)
print("GAIT "..Rules.Locomotion.GrandmasterShen.RunForward.." "..Rules.Locomotion.GrandmasterShen_P2.RunForward)
local a,b=Rules.gait("GrandmasterShen",7,1.3,1,0,nil,nil,2)
print("GAITP2 "..tostring(a).." "..b)
print("RATEZHAO "..select(2,Rules.gait("GeneralZhao",3,1.2,1,0,nil,nil,1)))
for _,list_ in {Attacks.Shen,Attacks.Chimera} do for _,m in list_ do print("MOVE "..m.Id.." "..tostring(m.DisplayName).." "..m.Windup.." "..tostring(m.Motion).." "..tostring(m.Count)) end end
print("WAVE "..Data.waveRadius(11,10,38,90).." "..Data.waveRadius(20,10,38,90))
print("TIER "..Data.tier(0,false).." "..Data.tier(2,false).." "..Data.tier(9,true).." "..Data.tier(9,false))
for event,layers in Data.Sfx do for _,l in layers do print("SFX "..event.." "..l.Key.." "..l.StandIn.." "..l.Attach) end end
''' % (stub + data_src))
out = subprocess.run([str(LUAU), str(probe)], capture_output=True, text=True, cwd=ROOT)
if out.returncode:
    print(out.stdout, out.stderr)
    sys.exit(1)
lines = out.stdout.splitlines()


def field(tag):
    return next(l[len(tag) + 1:] for l in lines if l.startswith(tag + " "))


contacts = dict(item.split("=") for item in field("CONTACTS").split(";"))
for action, value in contacts.items():
    want = [round(float(x), 3) for x in value.split(",")]
    for phase in (1, 2):
        clip = manifest.get("GrandmasterShen_P%d_%s" % (phase, action))
        if clip:
            got = [round(float(x), 3) for x in clip["contacts"]]
            check(all(abs(a - b) < 0.02 for a, b in zip(want, got)) and len(want) == len(got), "contacts of %s phase %d: %s vs %s" % (action, phase, want, got))
weapons = field("WEAPONS").split()
check(weapons[:2] == ["Guandao", "Guandao"], "guandao in both phases")
check(weapons[2:4] == ["0", "0"], "no reach bonus: the visible blade is the reach")
check(weapons[4] == "1.3", "scale 1.3")
reveal, duration = [float(x) for x in field("REVEAL").split()]
check(abs(manifest["GrandmasterShen_P1_Transform"]["length"] - 1.7) < 0.01 and abs(reveal + manifest["GrandmasterShen_P2_Transform"]["length"] - duration) < 0.01, "reveal + phase 2 Transform fills the 2.4 s transition")
check(field("GAIT") == "6.11 7.48", "gait rates per phase")
action, rate = field("GAITP2").split()
check(action == "RunForward" and abs(float(rate) - 7 / (7.48 * 1.3)) < 0.01, "phase 2 reads its own stride")
moves = {l.split()[1]: l.split(" ", 2)[2] for l in lines if l.startswith("MOVE ")}
check("Flowing Glaive" in moves["FlowingJian"], "the id FlowingJian stays, the display name says glaive")
check("7" in moves["PrayerBeads"] and "1.1" in moves["PrayerBeads"], "seven beads, windup 1.1")
check(field("WAVE") == "38 90", "wave radius is the server's speed x age, clamped")
check(field("TIER") == "Mid Low Low High", "tier rule")
audio = (ROOT / "src/shared/PresentationAssets.luau").read_text()
wavs = json.loads((ROOT / "assets/build/shen_audio/manifest.json").read_text())
sfx = [l.split()[1:] for l in lines if l.startswith("SFX ")]
check(len(sfx) >= 20, "sound manifest populated")
for event, key, stand, attach in sfx:
    check(key in wavs, "%s: original layer %s authored" % (event, key))
    check(re.search(r"\b%s\s*=\s*\"rbxassetid://\d+\"" % stand, audio) is not None, "%s: stand-in %s is an owned id" % (event, stand))
    check(attach in ("BladeTip", "BladeBase", "BeadHand", "ChestCore", "Root"), "%s: attachment %s" % (event, attach))
source = (ROOT / "src/client/Controllers/ShenPresentation.luau").read_text()
check("task.delay(" not in source, "cancellation is dropping the event list: no task.delay can outlive it")
check("Characters" not in source and "ApplyBossAttack" not in source, "presentation never touches gameplay")
for phase, name in ((1, "shen1"), (2, "shen2")):
    path = ROOT / "work/opening_cast_bake" / name / "pieces.json"
    if path.exists():
        pieces = json.loads(path.read_text())
        fx = pieces.pop("__fx", {})
        check(set(fx) >= {"BladeTip", "BladeBase", "BeadHand", "ChestCore"} and all(v.get("piece") in pieces or v.get("limb") for v in fx.values()), "attachments name real pieces or limbs, phase %d" % phase)
        check(max(p["tris"] for p in pieces.values()) < 20000, "every chunk under 20,000, phase %d" % phase)
print("Shen integration: %s" % ("FAILED %d" % fails if fails else "ok"))
sys.exit(1 if fails else 0)
