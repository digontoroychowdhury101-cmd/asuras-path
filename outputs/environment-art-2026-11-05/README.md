# Bamboo ridge gate continuation — 5 November 2026

The environment goal remains active and unfinished. This pass improves the new ridge shortcut gate
on the latest Foundry/combat/equipment build; it does not certify the broader Windows acceptance queue.

## Visible change and asset cost

The north approach showed four large black panels at the top of the stairs. Framed timber boards,
back/front diagonal braces and bronze hinge straps now replace those exposed box visuals. The existing
red posts and roof remain. All geometry/maps reuse the original uploaded lobby kit; no uploads,
paid generation, spending, public publication or master replacement occurred.

The first architrave-mesh attempt looked like a grille and was rejected. The final solid board uses
Gate_Plaque__Timber (44 triangles, read back from the real uploaded EditableMesh). Four panels total
60 mesh parts / 2,640 triangles, sharing existing wood and bronze PBR sets. Sources and IDs are in
`assets/BAMBOO_GATE_ART.json`. This increases render instances; it is not a measured speedup.

## Running-client evidence

- `bamboo-baseline/before_*` and `bamboo-current/after_*`: all eight required poses plus root detail,
  1271×685, FOV70, same lighting, Automatic/FRM1, 100 HP in Bamboo. The avatar is parked at the disclosed
  safe entry stand while the player-height observer camera moves. These are matched low-detail
  placement diagnostics, **not final gameplay-quality, earned traversal or performance acceptance**.
- `gate-interaction-clean/`: a fresh local Play test, normal Z hold at a seeded crest-side position.
  Both original leaves open; visual/collider pivot position and angle error are zero in the samples.
  Original leaf and wing dimensions are checked; all 60 added parts have no collision/query/touch.
  HP stays 100. The probe restores camera/keys and confirms Edit with no cleanup errors.
- `gate-solid-review/`: closer treatment inspection, Automatic FRM3/5; useful material/composition
  diagnostics but its quality differs from the main before/after pairs.
- `rejected-baseline-death/`: the first avatar-per-view sequence suffered a death, then two wrong-region
  lighting shots. Rejected; not acceptance evidence. The capture helper now refuses dead/wrong-region
  shots and supports an explicit safe observer stand without combat/health overrides.
- `rejected-gate-lattice/`: rejected first geometry. `gate-first-review/` records a failed startup after
  live sync could not insert a new module under the service folder capabilities. The normal rebuilt
  local place was opened and the complete native build verified instead. No capabilities were changed.
- `gate-interaction/`: earlier successful interaction, but the late onboarding controls card covers the
  open-state image. Its replacement checks and closes the card through normal H input before each shot.

Canonical and open Edit source match **281 scripts / 2,240,350 bytes / digest 1070832415**. The existing
native libraries are unchanged. Full 14-stage local verification passes (`verification.log`); the first
run exposed a missing new dependency in the offline loader list (`verification-initial-missing-loader.log`).
The loader was corrected and the focused campaign build passes 27 checks. These are offline evidence;
the real Z interaction is a separate single-client Studio integration check.

## Remaining defects and next action

1. The grove/shrine still exposes broad empty ground; canopy continuity and the opposite/reverse views
   need normal-quality inspection. Preserve combat lanes while adding convincing litter/roots/patches.
2. Arena edges still read as black primitive palisade strips. Replace them with a deliberate reusable
   bamboo/timber treatment that preserves collision, camera clearance and attack visibility.
3. Frost-step supports still stretch their stone maps. Correct UV/texel scale and walk the ordinary
   climb/return route. Original jumping blocks were preserved, but prior offline checks are insufficient.

Next: a representative frost support/material correction, then grove-floor and palisade treatments.
Final foreground-quality comparisons, continuous full-route/lock-on/combat footage, qualified desktop
p95, physical-mobile timing and the other campaign regions remain incomplete. No Windows combat,
armour, boss, persistence or device acceptance is newly claimed by this art pass.
