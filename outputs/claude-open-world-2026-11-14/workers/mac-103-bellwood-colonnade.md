# mac-103: Bellwood ruined colonnade (concept bellwood_3), built, uploaded and placed

Goal: the stone colonnade that stands in the Sunken Temple's lake in `concepts/bellwood_3`. On the left a long run of carved columns under a lintel; on the right toppled pairs leaning under broken lintels. Hung with moss and red cloth.

## Art: `tools/blender/landmarks/bellwood_colonnade.py`
- The first two clay passes failed review: the creator said "Looks absolutely terrible lock in please". There were three problems:
  - thin Roman shafts;
  - lintels that read as a row of crates with knobs;
  - pock-marked carving.
- The rebuild follows the concept closely.
- **Columns.** Stocky, about five diameters tall, with slight entasis. Each stands on a square plinth with two torus rings. On top: an astragal bead, a necking, a flared echinus and a square abacus (`capital()`).
- **Carving (`relief()`, on the HIGH only).** Shallow relief in registers of five framed panels round each shaft, with raised fillets between panels. Each panel holds a sinuous stem and two opposed log-spiral scrolls, mirrored panel to panel. The carving wears away in fbm patches. `high()` subdivides the carved shafts to 0.06 studs so the lines hold.
- **Lintels (`lintel()`).** One moulded entablature swept from a three-course profile: architrave (two fasciae and a fillet), frieze and cornice. It is laid in a few long settled blocks. A snapped end loses more of each course going up, so breaks step back. The break faces get coarse conchoidal relief (`pc.breaks`).
- **Lintel tops.** A broken attic course of low stones with gaps, and moss pads.
- **Moss and cloth.** Moss hangs in tufts of thin wavy strands from the cornice drip edge and the soffit. Narrow red cloth bands are tied round the lintels, with 2–4 fluttering tails each.
- **`Bellwood_ColonnadeStanding`.** Three columns leaning -6, -2 and +2.5 degrees under one lintel snapped at both ends. A fourth column is broken to a stump, with its capital fallen beside it, plus rubble.
- **`Bellwood_ColonnadeToppled`.** A pair leaning 12 and 14 degrees under a lintel snapped at both ends. A third column leans 20 degrees the other way, still carrying a snapped stub of its lintel. A fourth has fallen in three drums, with its capital on the top drum.
- **Bake.** CC0 Poly Haven `medieval_blocks_03` (Stone), `bark_willow_02` (Vine) and `distressed_painted_planks` (Ribbon, faded vermilion). The looks match the gate towers. Stone collision is Hull; Vine and Ribbon have none.
- **Triangle counts** (low, per piece):

  | Piece | Stone | Vine | Ribbon |
  |---|---|---|---|
  | Standing | 10,088 | 4,728 | 1,236 |
  | Toppled | 9,048 | 3,204 | 1,236 |

  Maps are 2048. The HIGH Stone is about 726k triangles (bake only).
- **Renders:** `captures/mac/bellwood_colonnade/`. The clay close and side views show the carving; the baked close and q34 show moss and cloth.
- **Re-running:** run the script under Blender with `COL_MODE=clay` or `COL_MODE=bake` and `COL_PIECES=Standing,Toppled`. Outputs go to `assets/source/landmarks/bellwood_colonnade/` (gitignored).

## Upload (pilot first) and registry
- Maps were embedded with `vesp_embed.embed` (Standing 15.4 MB, Toppled 15.2 MB), then put through `glb_split.py` (one part each).
- Uploaded through the Development window's Open Cloud bridge (`upload_batch.py`). Both are Approved:
  - `Bellwood_ColonnadeStanding` → 127915433158542;
  - `Bellwood_ColonnadeToppled` → 94406393587207.
- Operation IDs are in `mac-103-landmark-ledger.json`.
- `registry_readback.py landmark` read back all 6 sub-meshes. The readback rewrites the whole JSON from one ledger, so only the two colonnade pieces were merged into `assets/LANDMARK_KIT_UPLOADED.json`; all 7 earlier pieces are unchanged.
- `kit_registry.py landmark` now also validates the `bellwood_colonnade` pack and regenerated `LandmarkKitRegistry.luau`. The `test_kit_registry` fixture gained the pack (18 tests OK).

## Placement: `LandmarkLayout` `Basin.Shallows`
| Piece | Along | Across | Scale | Yaw | R |
|---|---|---|---|---|---|
| Standing | 420 | 95 | 2.5 | 55 | 52 |
| Toppled | 350 | -100 | 2.5 | -35 | 52 |

- At Scale 2.5 the columns are about 42 studs tall and each piece runs about 100 studs.
- No new code: `LandmarkWorld` places Shallows entries from the merged kit registry (mac-102).
- `test_vesperhold_loader` passes 231/231: inside the shore, clear of the causeways and the gate, inside the reveal view, seated, and Hull collision on Stone.
- The first placement (Scale 2, Along 300–340) read too small and far: Standing hid under the gate tower's foot and Toppled against the temple (`mac103_first_pass_too_far.jpg`).
- A grid probe of the clearance test moved Toppled to Across -100. At -45 it was 13 studs from a causeway.

## Studio (Development, Play at the exit eye)
- Both pieces load with SurfaceAppearance on all 6 MeshParts. Their feet stand in the water.
- `mac103_exit_reveal_colonnade.jpg`: the colonnade frames the temple stair left and right, as in the concept. Carved, mossy stone and red cloth read at this distance.
- The temple's upper tiers and tree had not streamed in yet during that Play session (they show in mac-102's shot). That is streaming timing, not this change.
- Studio Edit digest matches the repo build: 295 / 3934626 / 1107903586.
- Saved to Development: "Saved new changes", 13:22Z on 25 Nov.

## Still against bellwood_3
- No lotus or lily pads yet (Blender kit in progress, see the handoff).
- `Reed_Clump_B` heads are still broken.
- The colonnade could use a third, deeper piece trailing toward the stair. More hanging moss would also help the silhouette in fog.
