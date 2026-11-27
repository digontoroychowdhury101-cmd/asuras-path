# win-107 · Interface and equipment inspection

The Shrine’s warm metalwork and lacquer set the interface palette. Cinnabar marks health, jade marks Qi, and straw gold marks posture. The combat plate and action keys sit below the fight. Respite, the loading cover, the map, and the navigation tools use the same materials and type. Touch controls retain their own layout.

The reference clip showed a full item framed on a stand, with a camera move into each component. Asura’s Arsenal uses that interaction with its own slate stand and existing game items. Weapons can be examined at the edge or head, fittings, grip, and pommel where present. Armour can be examined at the torso, arms, and legs. Drag, turn, and zoom controls operate on the display camera. The player can browse armour in the Arsenal. Gao still handles acquiring, wearing, and reinforcing it through his existing transactions.

## Windows Studio · single client

- Opened the Arsenal with the live default inventory. The Jian rendered in the case, and choosing Edge moved the camera closer and marked the focus button. The armour tab rendered the game’s Ashen Pilgrim mesh on the stand.
- Selected Iron Fist Discipline and pressed Wield. The real player rig reported `AsuraWeapon=Unarmed` after the existing server action completed.
- Opened Respite from the normal key binding and inspected the new combat HUD in the Shrine.
- The Arsenal reflowed in Studio fixtures for 390×700 and 844×390. The model view fit both and its turn and zoom buttons were 44 pixels in each layout. This was viewport emulation.

## Windows Studio · two clients

- Five checks passed with mock profiles. Both clients loaded the HUD, rendered independent weapon and armour previews, changed the component camera, and reflowed the equipment view at portrait and landscape widths.
- Equipping unarmed through the existing server action changed the first client’s character while the other client still wielded the Jian.

## Local verification and save

All 14 stages passed. The Arsenal and Codex suite passed 177 checks, cast visuals 51, HUD layout 274, and device layout 90. Studio Edit matched the build at 300 scripts, 4,005,653 source bytes, digest `1829367315` after removing both temporary probes. Save to Roblox returned Development v86 for place `118614906972571`. Physical device profiling remains open.
