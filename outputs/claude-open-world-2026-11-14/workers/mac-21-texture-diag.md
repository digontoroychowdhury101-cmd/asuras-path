# mac-21 texture diagnosis (supersedes nothing; linked from CONTINUATION.md "Mac resume — 2026-11-18" lane table)

Plan: 0 setup (copy rbxlx, open Studio, local+digest asserts) -> A far trees LoadAsset/GetProductInfo/Preload -> B built pieces -> C Play writability -> D teardown.
Files touched: work/mac-resume-2026-11-17/diag21/AsurasPath_diag21.rbxlx (copy only), this note. No source edits, no uploads.

## Log
- memory_pressure before: System-wide memory free percentage: 52%
- Step 0: copied rbxlx to diag21/ (10.8 MB). `open -a RobloxStudio` twice: Studio auto-updated 0.747->0.748, relaunched with -protocolString file URL, but both instances stayed at the start page / MCP "Place is not open" for 7+ min (not in File>Recent either). Full-screen control for a File>Open dialog was interrupted by the user (computer_batch "user interrupt" x2), so I stopped. NO diagnosis A/B/C done. Quit requested: osascript quit returned "User cancelled"; one Studio process (pid 13843, start page, no place) was left running; memory_pressure after: 44% free.

## mac-21b run
Plan: confirm Studio+digest (done: PlaceId 0, 281/3254714/1882323309, mem free 40%); A far-tree dump + GetProductInfo/Preload; B built pieces; C Play writability + far count; D teardown.
- Step 0 OK: Studio AsurasPath_diag21.rbxlx persistedToCloud=false, digest matches.
- A1: LoadAsset of 6 far + Canopy_Tree_C control OK. Far MeshParts (12): TextureID set, NO SurfaceAppearance, Color 163,162,165, Plastic, no MaterialVariant, refl 0, dbl false. Only 2 DISTINCT far TextureIDs: 91720252765631 (A,B,C,D,Old_Gnarled; 256x128) and 99638223377132 (Conifer; 256x128). Control: TextureID empty, SA on every MeshPart with CM/NM/RM/MM (CM 102367205742520 leaves, 73636723925754 bark; 512x512).
- A2: GetProductInfo: all far/control images AssetTypeId=1 (Image), name "image", Creator User 3148600636, Public=false; far mesh 97341778136107 AssetTypeId=4 (Mesh). Far images created 13:28 on 2026-11-16, control 13:18.
- A3: PreloadAsync by STRING id is unreliable (first call Failure for everything incl. controls, later Success for far1); instance preload (ImageLabel/Decal/MeshPart.TextureID) = Success for far tex; AssetService:CreateEditableImageAsync succeeds for all 4 images (256x128 far, 512x512 ctrl). Console: "No asset content representation found..." only once (91720252765631) from first string preload; mesh string-preload gives "Asset type does not match requested type" (expected, probe artefact).
- B: 11 built pieces (Pavilion, Cart_A/B, Crate_A/B/C, Hermit_Hut, Shrine, Well + Lantern_Stone, Fern_Bracken) all MeshParts have SurfaceAppearance, ColorMap non-empty, Color 163,162,165, Plastic. 24 distinct map ids; CreateEditableImageAsync succeeds for all 24 (0 failures). No load failure in dark built pieces.
- C (Play): Server execute_luau runs with Plugin capability, so ColorMap writes succeed there (not representative). Real Script in workspace: far MeshPart.TextureID write OK; SA.Color write OK; SA.ColorMap/NormalMap read+write ERR "The current thread cannot read 'ColorMap' (lacking capability Plugin)". Far parts after dressing completes (~66 s): 176 (Bark 88, Leaves 87, Needles 1), 174 use 91720252765631, 2 use 99638223377132, no SA, Color 163,162,165, Plastic. Console in Play: 0 "No asset content representation" lines.
- D: Play stopped; teardown/digest see below.
