# Optional Rojo 7.7.1 editor warning repair

The game build does not need this patch. Computer A's installed plugin was patched locally; installed plugins are not synced through Git. The patch fixes Notification Sound `203785492` being preloaded as an image. A future official plugin may already contain the fix; do not apply blindly to another version.

For Rojo 7.7.1 on computer B, close Studio, use Studio's **Plugins Folder** location to find the actual installed `Rojo.rbxm`, and copy it to `work/rojo-warning/Rojo.original.rbxm` (create the directory first). Keep that backup. From the repository root, with Python and Rojo installed:

```text
rojo build tools/qa/rojo_preloader_fix/convert.project.json -o work/rojo-warning/Rojo.original.rbxmx
python tools/qa/patch_rojo_preloader.py work/rojo-warning/Rojo.original.rbxmx work/rojo-warning/Rojo.patched.rbxmx
rojo build tools/qa/rojo_preloader_fix/patched.project.json -o work/rojo-warning/Rojo.patched.rbxm
```

On macOS use `python3` if necessary. Replace the installed plugin with the patched binary only after the commands succeed, then restart Studio. To undo, restore the original backup. The patcher asserts the expected module shape and changes only `preloadAssets`.

Validated original SHA-256: `50a8d83db87deab4d65fd6100eb74396de232355b1ae89c641035d02c49db6f4`.
Computer A's patched binary SHA-256: `30e19c8ba64908be6617f0865dc6093746cc3d3045719a0182486246d0945d44` (binary serialization can differ).

References: https://github.com/rojo-rbx/rojo/issues/1342 and https://github.com/rojo-rbx/rojo/pull/1344. The original plugin and installed machine files remain local; the patcher and conversion projects are portable.
