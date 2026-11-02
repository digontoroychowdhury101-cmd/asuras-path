#!/usr/bin/env python3
"""Shows that the Stage 3 behaviour tests catch the defects they name: each mutation restores an old defect in the source, runs a suite and
expects failures, then restores the file exactly. Evidence type: offline behaviour test.

    python3 tools/qa/mutation_stage3.py
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "outputs/combat-recovery-2026-11-02/mac-stage3/mutation_checks.json"
# (name, file, old text, new text, suite)
MUTATIONS = [
    ("facing read at the present, not one instant", "src/server/CharacterService.luau", "local attackerThen = Lag.samplePoseAt(attacker.History, at)", "local attackerThen = nil", "test_stage3_motion"),
    ("rollback zeroes velocity", "src/simulation/LocalPrediction.luau",
     "return vx - ux * removed, vz - uz * removed", "return 0, 0", "test_stage3_motion"),
    ("rollback takes back the whole travelled line", "src/simulation/LocalPrediction.luau",
     "return math.max(0, math.min(travelled, driven))", "return driven", "test_stage3_motion"),
    ("chain confirms past the link window", "src/simulation/LocalPrediction.luau",
     "now > recovery + timing.ComboWindowSeconds - LINK_MARGIN", "false", "test_stage3_motion"),
    ("phase correction uncapped", "src/simulation/AnimationTiming.luau",
     "Timing.MAX_RATE = 1.5", "Timing.MAX_RATE = 2", "test_stage3_motion"),
    ("duplicate contact cues freeze twice", "src/client/Controllers/CombatFeedback.luau",
     "DUPLICATE_CUE = 0.03", "DUPLICATE_CUE = -1", "test_stage3_motion"),
    ("feet never unlock", "src/simulation/FootStep.luau", "local unlock = Foot.UNLOCK_RADIUS * input.Scale", "local unlock = math.huge", "test_stage3_motion"),
    ("sweep forgets the root's travel between samples", "src/server/CharacterService.luau", "MAX_SWEEP_TRAVEL = 6", "MAX_SWEEP_TRAVEL = 0", "test_stage3_motion"),
    ("the fade-in that delayed first motion returns", "src/client/Controllers/FighterAnimations.luau", "return if actor.Pose then 0 else fade", "return fade", "test_stage3_motion"),
    ("a press past the link is shown as the next light", "src/simulation/LocalPrediction.luau", "if opener.QiCost > 0 or s.Stamina - spent", "opener = Weapons.nextLight(weapon, current)\n\tif opener.QiCost > 0 or s.Stamina - spent", "test_stage3_motion"),
    ("a confirmed prediction keeps its local clock", "src/client/Controllers/FighterAnimations.luau", "actor.Timeline, actor.LocalBegan = elapsed, began", "actor.Timeline = elapsed", "test_stage3_motion"),
    ("no step past the pose budget", "src/client/Controllers/FighterAnimations.luau", "elseif actor.Stepper or actor.Step.Magnitude > 1e-3 then", "elseif false then", "test_stage3_motion"),
    ("the step ignores the rig's scale", "src/client/Controllers/FighterAnimations.luau", "-Trajectories.stepAt(data, clip) * actor.Model:GetScale()", "-Trajectories.stepAt(data, clip)", "test_stage3_motion"),
    ("a step writer accumulates", "src/client/Controllers/ActorPose.luau", "self.Written = CFrame.new(step) * self.Input", "self.Written = CFrame.new(step) * value", "test_stage3_motion"),
    ("a step writer stays on under a new pose writer", "src/client/Controllers/FighterAnimations.luau", "if actor.Stepper then\n\t\t\t\tactor.Stepper:Destroy()\n\t\t\t\tactor.Stepper = nil\n\t\t\tend\n\t\t\tactor.Pose = ActorPose.attach", "actor.Pose = ActorPose.attach", "test_stage3_motion"),
    ("trail points ignore the server's scale and bonus", "src/client/Controllers/WeaponTrails.luau", "local bonus = if strike then strike.Bonus else 0", "local bonus = 0", "test_stage3_motion"),
    ("trail points ignore the committed yaw", "src/client/Controllers/WeaponTrails.luau", "local frame = strikeFrame(root.CFrame, if strike then strike.Yaw else nil)", "local frame = root.CFrame", "test_stage3_motion"),
    ("an earlier swing's record is applied", "src/client/Controllers/WeaponTrails.luau", "and now - (latest.Start + latest.Active) < LIVE", "", "test_stage3_motion"),
    ("debug always draws the generic shape", "src/client/Controllers/WeaponTrails.luau", "local data = if strike.Baked and strike.Move then Trajectories.forMove(strike.Move) else nil\n\tlocal shape = { Arc = strike.Arc, Reach = strike.Reach, Lunge = strike.Lunge }\n\tif data or strike.Arc > Strike.SlashArc then\n\t\t-- The tip's path", "local data = nil\n\tlocal shape = { Arc = strike.Arc, Reach = strike.Reach, Lunge = strike.Lunge }\n\tif data or strike.Arc > Strike.SlashArc then\n\t\t-- The tip's path", "test_stage3_motion"),
    ("Destroy clears a table that does not exist", "src/client/Controllers/CombatFeedback.luau", "table.clear(self.Stops)", "table.clear(self.Frozen)", "test_stage3_motion"),
    ("hitstop freezes nothing", "src/client/Controllers/PlaybackScale.luau", "action = math.min(action, request.Scale)", "action = action", "test_stage3_motion"),
]


def run(suite):
    out = subprocess.run([sys.executable, "tools/lune_compat.py", "tools/%s.luau" % suite], capture_output=True, text=True, cwd=str(ROOT))
    text = out.stdout + out.stderr
    failing = [line.strip()[:120] for line in text.splitlines() if line.startswith("FAIL  ")]
    summary = next((line for line in text.splitlines() if " passed, " in line), "no summary: suite errored")
    return failing, summary


def main():
    results = []
    for name, rel, old, new, suite in MUTATIONS:
        path = ROOT / rel
        original = path.read_text()
        if old not in original:
            results.append({"mutation": name, "error": "text not found: " + old})
            continue
        try:
            path.write_text(original.replace(old, new, 1))
            failing, summary = run(suite)
        finally:
            path.write_text(original)
        results.append({"mutation": name, "file": rel, "caught": bool(failing) or "no summary" in summary, "summary": summary, "failing": failing[:6]})
        print(("CAUGHT " if results[-1]["caught"] else "MISSED ") + name, "|", summary[:90], flush=True)
    OUT.write_text(json.dumps(results, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
