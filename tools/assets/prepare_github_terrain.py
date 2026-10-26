"""Unpack the pinned GitHub terrain textures (assets/GITHUB_TERRAIN.json) into Roblox MaterialVariant maps.

Terrain3D packs albedo+height and normal+roughness into RGBA; BabylonJS ships glTF metal/rough
(roughness in G). The Godot breccia has only albedo, so its normal is derived from luminance and its
roughness is a soft inverse of brightness. Normals stay OpenGL (+Y), which Roblox expects.
Writes assets/github/terrain_ready/<Variant>_{Color,Normal,Roughness}.png at 1024x1024.
Requires Pillow and NumPy.
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/github"
OUT = SRC / "terrain_ready"
SIZE = (1024, 1024)


def load(path, mode="RGBA"):
    return Image.open(SRC / path).convert(mode).resize(SIZE, Image.LANCZOS)


def save(variant, kind, image):
    OUT.mkdir(parents=True, exist_ok=True)
    image.save(OUT / f"{variant}_{kind}.png", optimize=True)


def packed(variant, stem):
    alb = load(f"terrain3d/{stem}_alb_ht.png")
    nrm = load(f"terrain3d/{stem}_nrm_rgh.png")
    save(variant, "Color", alb.convert("RGB"))
    save(variant, "Normal", nrm.convert("RGB"))
    save(variant, "Roughness", nrm.getchannel("A"))


def derived(variant, path, strength=2.5):
    color = load(path, "RGB")
    lum = np.asarray(color.convert("L"), dtype=np.float32) / 255.0
    # Tileable central differences (np.roll wraps), so the derived normal still tiles.
    dx = (np.roll(lum, -1, 1) - np.roll(lum, 1, 1)) * strength
    dy = (np.roll(lum, -1, 0) - np.roll(lum, 1, 0)) * strength
    n = np.stack([-dx, dy, np.ones_like(lum)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    save(variant, "Color", color)
    save(variant, "Normal", Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB"))
    save(variant, "Roughness", Image.fromarray((np.clip(0.95 - lum * 0.45, 0, 1) * 255).astype(np.uint8), "L"))


def gltf(variant, color, normal, metal_rough):
    save(variant, "Color", load(color, "RGB"))
    save(variant, "Normal", load(normal, "RGB"))
    save(variant, "Roughness", load(metal_rough, "RGB").getchannel("G"))


def main():
    packed("AsuraGrass", "ground037")
    packed("AsuraCliff", "rock023")
    derived("AsuraBasalt", "godot/material_testers/marble_albedo.png")
    gltf("AsuraGravel", "babylon/rockyGround_basecolor.png", "babylon/rockyGround_normal.png", "babylon/rockyGround_metalRough.png")
    print("\n".join(sorted(p.name for p in OUT.glob("*.png"))))


if __name__ == "__main__":
    main()
