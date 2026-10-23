# TRELLIS.2 to Roblox Asset Pipeline

This pipeline enables ChatGPT / Codex and local developer workflows to automatically generate high-fidelity PBR 3D models using **TRELLIS.2** for free, optimize them for Roblox engine constraints, and load them into Roblox Studio.

---

## ⚡ Quick Start

### 1. Configure Your Free Hugging Face Token (One-time)
ZeroGPU on Hugging Face offers free A100/L40S GPU inference. Adding your free token prevents shared IP rate limits:
1. Generate a free token at [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens).
2. Create/edit `tools/trellis/.env`:
   ```env
   HF_TOKEN="hf_your_free_token_here"
   ```

### 2. Generate a 3D Model
Run the generator from the repo root with either a prompt or an existing reference image:

```bash
# Text-to-3D (Generates reference image -> TRELLIS.2 3D mesh -> Roblox optimization)
./tools/trellis/run_trellis.sh --prompt "grimdark wuxia weathered stone shrine" --name "AsuraShrine"

# Image-to-3D (From local file or web URL)
./tools/trellis/run_trellis.sh --image "/path/to/concept.png" --name "AsuraGreatsword"
```

The resulting file is automatically saved to:
`assets/models/<Name>.glb`

---

## 🎮 Loading into Roblox Studio

### Method A: Roblox Studio 3D Importer (No API key needed)
1. Open your place (`places/AsurasPath.rbxlx`) in **Roblox Studio**.
2. Go to the **Home** or **Avatar** tab -> click **3D Importer**.
3. Select `assets/models/<Name>.glb`.
4. Review preview and click **Import**.

### Method B: Fully Automated Open Cloud & Studio Insertion
To have ChatGPT / Codex upload and insert directly into your live Studio workspace:

1. Create a Roblox API Key at [create.roblox.com/credentials](https://create.roblox.com/credentials) with `Assets` permission (`read` and `write`).
2. Add your credentials to `tools/trellis/.env`:
   ```env
   ROBLOX_API_KEY="rbx_..."
   ROBLOX_USER_ID="123456789"
   # Or ROBLOX_GROUP_ID="987654321"
   ```
3. Run with `--upload` and `--insert`:
   ```bash
   ./tools/trellis/run_trellis.sh --prompt "weathered bronze bell" --name "AsuraTempleBell" --upload --insert
   ```
   * It uploads the `.glb` to Roblox Open Cloud as a Model asset.
   * Receives the numeric `assetId`.
   * Automatically invokes `tools/studio_mcp.py` to insert the model right into your active Studio workspace!

---

## 🛠️ How Optimization Works

Roblox imposes strict asset limits:
* Max **20,000 triangles** per MeshPart.
* Max **1024×1024** texture dimensions.

The pipeline automatically handles this:
1. Runs Blender headless (`/Applications/Blender.app` + `tools/blender/process_asset.py`) or Python `trimesh`.
2. Decimates geometry down to $\le 19,500$ triangles with manifold boundary protection.
3. Centers the origin at the bottom/base of the model.
4. Generates 1024 PBR texture maps (Color, Normal, Roughness, Metalness).
5. Automatically registers the model in `assets/PHASE5_IMPORT_QUEUE.json`.
