# win-88: Vesperhold gate-wall crown (Windows, 24 Nov 2026)

Defect: from the pilgrim road the castle reads as one flat dark box. The top of that box is the T1 gate wall's massing, which rises to `T1.Top` (190). The balustrade and pinnacle row sat at 170 and 178, so they were stuck to the wall face, and the skyline was a bare 20-stud band.

Fix (`VesperholdLayout.luau`): the T1 balustrade now stands at `T1.Top` and the pinnacles at `T1.Top + 8`. The arcades stop at 170, so 170 to 190 reads as a frieze under the crown. Slot ids and order are unchanged. The new `test_vesperhold_massing` check failed before the fix and passes after it.

Captures in `captures/win/vesp88`:
- 01: before, with no crown on the top line;
- 02: after, with the crown breaking the skyline;
- 03: close view of the balustrade and pinnacles on the wall top;
- 04: the dropout finding below.

## Finding for the next pass: kit meshes not drawn in Play
In Studio Play, some kit pieces were never drawn, even though each had `Transparency = 0` and `LocalTransparencyModifier = 0`:
- the outer top-row arcade bays;
- the outer 8 of 33 crown balustrades on each side.

A red `Highlight` on all 33 balustrades lit only the middle ones. Cloning one arcade Stone part made every arcade bay draw, which points to engine mesh streaming. `GraphicsMeshParts` was 44 MB in a 2.9 GB shared Studio process. Where kit is missing, the bare Massing box shows, and that is the "dark box behind the meshes" noted in win-86.

Not yet known: whether a real client shows this, outside Studio's shared server and client memory. Next pass: profile on a phone or a standalone client. If it does reproduce, cut what the client keeps resident (274 Persistent kit models, 17.2M source triangles).
