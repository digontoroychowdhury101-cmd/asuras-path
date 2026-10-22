"""Register the Shrine lobby kit in the Rojo tree from verified uploads (never invents IDs).
python3 tools/assets/register_lobby_kit.py
Maps ServerStorage.AsuraLobbyKit -> assets/models/AsuraLobbyKit.rbxmx, writes one MaterialVariant
per kit texture set into MaterialService (the same uploaded maps the kit's SurfaceAppearances use,
at the kit's studs-per-tile) so primitives match the meshes, and registers the lobby modules.
Idempotent; the rest of default.project.json is left as it is.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ID = re.compile(r"rbxassetid://[1-9][0-9]{5,19}")
# Texture set -> (a kit part carrying it, variant name, base material, studs per tile).
VARIANTS = {
    "Paving": ("Paving_Medallion__Paving", "AsuraPaving", "Slate", 16),
    "Stone": ("Rail_Bay__Stone", "AsuraStone", "Slate", 8),
    "Rock": ("Cliff_Ledge__Rock", "AsuraRock", "Rock", 32),
    "Lacquer": ("Column_Lacquer__Lacquer", "AsuraLacquer", "Wood", 8),
    "Timber": ("Bracket_Set__Timber", "AsuraTimber", "Wood", 8),
    "Bronze": ("Column_Lacquer__Bronze", "AsuraBronze", "Metal", 4),
    "Roof": ("Roof_Hall__Roof", "AsuraRoofTile", "Slate", 17.6),
}
MODULES = ["SanctuaryKit", "SanctuaryFrame", "SanctuaryRails", "SanctuaryProps", "SanctuaryCourtyard", "SanctuaryCloisters",
           "SanctuaryForge", "SanctuaryDuelCourt", "SanctuaryAscent", "SanctuaryTerrace", "SanctuaryHorizon"]


def main():
    registry = json.loads((ROOT / "assets/LOBBY_KIT_UPLOADED.json").read_text())
    parts = {name: ids for piece in registry["pieces"].values() for name, ids in piece.items()}
    path = ROOT / "default.project.json"
    project = json.loads(path.read_text())
    tree = project["tree"]
    tree["ServerStorage"]["AsuraLobbyKit"] = {"$path": "assets/models/AsuraLobbyKit.rbxmx"}
    service = tree.setdefault("MaterialService", {"$className": "MaterialService"})
    for key, (part, variant, base, studs) in VARIANTS.items():
        ids = parts[part]
        for label in ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap"):
            if not ID.fullmatch(ids[label]):
                raise SystemExit(f"{part} has no verified {label}")
        service[variant] = {"$className": "MaterialVariant", "$properties": {
            "BaseMaterial": base, "StudsPerTile": studs,
            "ColorMapContent": ids["ColorMap"], "NormalMapContent": ids["NormalMap"],
            "RoughnessMapContent": ids["RoughnessMap"], "MetalnessMapContent": ids["MetalnessMap"]}}
    services = tree["ServerScriptService"]["AsurasPath"]["Services"]
    for name in MODULES:
        file = ROOT / f"src/server/Services/{name}.luau"
        if file.exists():
            services[name] = {"$path": f"src/server/Services/{name}.luau"}
    path.write_text(json.dumps(project, indent=2) + "\n")
    print("registered kit library,", len(VARIANTS), "material variants,",
          sum((ROOT / f"src/server/Services/{n}.luau").exists() for n in MODULES), "lobby modules")


if __name__ == "__main__":
    main()
