#!/usr/bin/env python3
"""TRELLIS to Roblox Asset Pipeline:
1. Generate image from prompt (or use existing image).
2. Generate 3D asset using TRELLIS.2 via Hugging Face.
3. Optimize & decimate mesh for Roblox (<20,000 tris, 1024x1024 textures) via Blender / trimesh.
4. Stage into assets/models/ and register in PHASE5_IMPORT_QUEUE.json.
5. (Optional) Upload to Roblox Open Cloud & insert directly into active Roblox Studio session.
"""

from __future__ import annotations
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

# Paths
ROOT = Path(__file__).resolve().parents[2]
ENV_FILE = ROOT / "tools/trellis/.env"
BLENDER_MAC = Path("/Applications/Blender.app/Contents/MacOS/Blender")
VENV_PYTHON = ROOT / "tools/trellis_env/bin/python3"
PROCESS_ASSET_SCRIPT = ROOT / "tools/blender/process_asset.py"
STUDIO_MCP_SCRIPT = ROOT / "tools/studio_mcp.py"


def load_env() -> dict[str, str]:
    env = dict(os.environ)
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env.setdefault(k.strip(), v.strip().strip('"').strip("'"))
    return env


def sanitize_name(name: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_]", "", name.title().replace(" ", "").replace("-", "_"))
    return cleaned or "AsuraAsset"


def generate_image_from_prompt(prompt: str, output_path: Path) -> Path:
    """Generate reference image with isolated background for TRELLIS."""
    import requests

    print(f"[1/4] Generating reference image from prompt: '{prompt}'...")
    enhanced_prompt = (
        f"{prompt}, high quality 3d asset, grimdark fantasy realism, "
        f"isolated on solid plain white background, centered, full view, no background clutter"
    )
    encoded = urllib.parse.quote(enhanced_prompt)
    url = f"https://image.pollinations.ai/prompt/{encoded}?width=1024&height=1024&nologo=true&seed=42"
    
    resp = requests.get(url, timeout=45)
    resp.raise_for_status()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(resp.content)
    print(f"      Reference image saved: {output_path}")
    return output_path


def generate_trellis_glb(image_path: Path, hf_token: str | None = None, resolution: str = "1024") -> Path:
    """Generate raw GLB using microsoft/TRELLIS.2 Gradio API."""
    from gradio_client import Client, handle_file

    print(f"[2/4] Generating 3D asset via TRELLIS.2...")
    client_kwargs = {}
    if hf_token:
        client_kwargs["token"] = hf_token
        client_kwargs["headers"] = {"Authorization": f"Bearer {hf_token}"}
    
    try:
        client = Client("microsoft/TRELLIS.2", **client_kwargs)
        print("      Connected to microsoft/TRELLIS.2")
        
        # 1. Preprocess
        print("      Preprocessing image (segmentation/background removal)...")
        prep_img = client.predict(
            input=handle_file(str(image_path)),
            api_name="/preprocess_image"
        )
        
        # 2. Image to 3D
        print(f"      Running 3D neural generation (resolution: {resolution})...")
        client.predict(
            image=handle_file(prep_img),
            seed=42,
            resolution=resolution,
            ss_guidance_strength=7.5,
            ss_guidance_rescale=0.7,
            ss_sampling_steps=12,
            ss_rescale_t=5.0,
            shape_slat_guidance_strength=7.5,
            shape_slat_guidance_rescale=0.5,
            shape_slat_sampling_steps=12,
            shape_slat_rescale_t=3.0,
            tex_slat_guidance_strength=1.0,
            tex_slat_guidance_rescale=0.0,
            tex_slat_sampling_steps=12,
            tex_slat_rescale_t=3.0,
            api_name="/image_to_3d"
        )
        
        # 3. Extract GLB
        print("      Extracting GLB (decimation: 100,000, texture: 1024)...")
        glb_res = client.predict(
            decimation_target=100000,
            texture_size=1024,
            api_name="/extract_glb"
        )
        download_path = glb_res[1] if isinstance(glb_res, (list, tuple)) else glb_res
        return Path(download_path)

    except Exception as exc:
        print(f"      microsoft/TRELLIS.2 notice: {exc}")
        print("      Falling back to community TRELLIS space...")
        try:
            client = Client("trellis-community/TRELLIS", **client_kwargs)
            res = client.predict(
                image=handle_file(str(image_path)),
                multiimages=[],
                seed=42,
                ss_guidance_strength=7.5,
                ss_sampling_steps=12,
                slat_guidance_strength=3.0,
                slat_sampling_steps=12,
                multiimage_algo="stochastic",
                mesh_simplify=0.95,
                texture_size=1024,
                api_name="/generate_and_extract_glb"
            )
            download_path = res[2] if isinstance(res, (list, tuple)) else res
            return Path(download_path)
        except Exception as fallback_exc:
            raise RuntimeError(
                f"TRELLIS generation failed: {exc}\nFallback failed: {fallback_exc}\n"
                "Tip: Obtain a free Hugging Face token at https://huggingface.co/settings/tokens "
                "and set HF_TOKEN in tools/trellis/.env or via --token."
            ) from fallback_exc


def optimize_mesh_for_roblox(raw_glb: Path, output_dir: Path, asset_name: str, max_tris: int = 18000) -> Path:
    """Optimize mesh to meet Roblox MeshPart requirements (< 20,000 triangles, 1024 PBR textures)."""
    print(f"[3/4] Optimizing mesh for Roblox (cap: {max_tris} tris, 1024 PBR maps)...")
    output_dir.mkdir(parents=True, exist_ok=True)
    target_glb = output_dir / f"{asset_name}.glb"

    # Try project's Blender pipeline first
    blender_bin = None
    if BLENDER_MAC.exists():
        blender_bin = str(BLENDER_MAC)
    elif shutil.which("blender"):
        blender_bin = shutil.which("blender")

    source_dir = output_dir / "source"
    source_dir.mkdir(parents=True, exist_ok=True)
    input_staging = source_dir / f"{asset_name}_raw.glb"
    shutil.copy2(raw_glb, input_staging)

    if blender_bin and PROCESS_ASSET_SCRIPT.exists():
        print(f"      Running Blender processing: {blender_bin}...")
        cmd = [
            blender_bin,
            "-b",
            "--python-exit-code", "1",
            "-P", str(PROCESS_ASSET_SCRIPT),
            "--",
            str(input_staging),
            str(output_dir),
            "--max-tris", str(min(max_tris, 19500)),
            "--tex", "1024",
            "--join"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        blender_out = output_dir / f"{asset_name}_raw.glb"
        if result.returncode == 0 and blender_out.exists():
            if blender_out != target_glb:
                blender_out.replace(target_glb)
            print(f"      Blender optimization successful: {target_glb}")
            return target_glb
        else:
            print("      Blender script note (falling back to trimesh):", result.stderr[-300:] if result.stderr else result.stdout[-300:])

    # Fallback: Trimesh decimation & cleanup
    print("      Optimizing with trimesh...")
    import trimesh

    scene_or_mesh = trimesh.load(str(raw_glb))
    if isinstance(scene_or_mesh, trimesh.Scene):
        mesh = scene_or_mesh.dump(concatenate=True)
    else:
        mesh = scene_or_mesh

    # Remove unreferenced vertices & clean
    mesh.remove_unreferenced_vertices()
    mesh.remove_degenerate_faces()

    current_tris = len(mesh.faces)
    print(f"      Mesh loaded: {current_tris} triangles.")
    if current_tris > max_tris:
        print(f"      Decimating from {current_tris} to ~{max_tris} triangles...")
        try:
            mesh = mesh.simplify_quadric_decimation(face_count=max_tris)
        except Exception as e:
            print(f"      Decimation note: {e}")

    # Center origin to base for easy placement in Roblox
    bounds = mesh.bounds
    mesh.apply_translation(-[(bounds[0][0] + bounds[1][0]) / 2, bounds[0][1], (bounds[0][2] + bounds[1][2]) / 2])
    
    mesh.export(str(target_glb))
    print(f"      Saved optimized model: {target_glb} ({len(mesh.faces)} triangles)")
    return target_glb


def register_in_import_queue(glb_path: Path, asset_name: str, tris: int) -> None:
    queue_file = ROOT / "assets/PHASE5_IMPORT_QUEUE.json"
    data = {"status": "import_pending", "models": []}
    if queue_file.exists():
        try:
            data = json.loads(queue_file.read_text())
        except Exception:
            pass

    rel_file = str(glb_path.relative_to(ROOT)) if glb_path.is_relative_to(ROOT) else str(glb_path)
    entry = {
        "name": asset_name,
        "file": rel_file,
        "mesh_objects": 1,
        "materials": 1,
        "triangles": tris,
        "source": "trellis_ai",
        "sha256": hashlib.sha256(glb_path.read_bytes()).hexdigest(),
        "uploaded": False,
        "parts": []
    }
    
    # Update or append
    existing = [m for m in data.get("models", []) if m.get("name") != asset_name]
    existing.append(entry)
    data["models"] = existing
    queue_file.write_text(json.dumps(data, indent=2) + "\n")
    print(f"      Registered in {queue_file.relative_to(ROOT)}")


def upload_to_roblox_open_cloud(glb_path: Path, asset_name: str, api_key: str, user_id: str | None = None, group_id: str | None = None) -> str:
    """Upload Model GLB to Roblox Open Cloud Assets API."""
    import requests

    print(f"[4/4] Uploading {asset_name} to Roblox Open Cloud Assets API...")
    url = "https://apis.roblox.com/assets/v1/assets"
    headers = {"x-api-key": api_key}

    creator = {}
    if group_id:
        creator["groupId"] = str(group_id)
    elif user_id:
        creator["userId"] = str(user_id)
    else:
        raise ValueError("Either ROBLOX_USER_ID or ROBLOX_GROUP_ID must be set.")

    metadata = {
        "assetType": "Model",
        "displayName": asset_name,
        "description": f"Generated via TRELLIS 3D Pipeline for Asura's Path ({asset_name})",
        "creationContext": {
            "creator": creator
        }
    }

    with open(glb_path, "rb") as f:
        files = {
            "request": (None, json.dumps(metadata), "application/json"),
            "fileContent": (asset_name + ".glb", f, "model/gltf-binary")
        }
        res = requests.post(url, headers=headers, files=files)
        res.raise_for_status()
        op_data = res.json()

    op_path = op_data.get("path")
    print(f"      Operation initiated: {op_path}")
    status_url = f"https://apis.roblox.com/assets/v1/{op_path}"

    for i in range(30):
        time.sleep(2)
        status_res = requests.get(status_url, headers=headers).json()
        if status_res.get("done"):
            if "response" in status_res and "assetId" in status_res["response"]:
                asset_id = status_res["response"]["assetId"]
                print(f"      Upload complete! Owned Asset ID: rbxassetid://{asset_id}")
                return str(asset_id)
            elif "error" in status_res:
                raise RuntimeError(f"Roblox Asset Processing error: {status_res['error']}")

    raise TimeoutError("Roblox Asset processing timed out.")


def insert_into_studio_mcp(asset_id: str, asset_name: str) -> bool:
    """Insert asset into active Roblox Studio place via StudioMCP."""
    if not STUDIO_MCP_SCRIPT.exists():
        return False

    print("      Inserting asset into Roblox Studio via StudioMCP...")
    call_spec = [
        ["insert_asset", {
            "assetId": asset_id,
            "assetName": asset_name,
            "assetType": "Model",
            "parentPath": "game.Workspace",
            "studio_id": "active"
        }]
    ]
    temp_calls = Path("/tmp/studio_insert.json")
    temp_calls.write_text(json.dumps(call_spec))

    res = subprocess.run([sys.executable, str(STUDIO_MCP_SCRIPT), str(temp_calls)], capture_output=True, text=True)
    temp_calls.unlink(missing_ok=True)
    if res.returncode == 0:
        print("      Asset inserted into Studio Workspace!")
        return True
    else:
        print(f"      StudioMCP note: {res.stdout.strip() or res.stderr.strip()}")
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prompt", "-p", help="Text prompt to generate 3D model (e.g. 'dark fantasy stone pagoda')")
    parser.add_argument("--image", "-i", help="Local path or URL to an image file")
    parser.add_argument("--name", "-n", help="Asset name (defaults to sanitized prompt/image name)")
    parser.add_argument("--token", help="Hugging Face User Access Token (for free dedicated ZeroGPU quota)")
    parser.add_argument("--triangles", type=int, default=18000, help="Max triangles (default 18000, max 19500 for Roblox)")
    parser.add_argument("--resolution", default="1024", choices=["512", "1024", "1536"], help="TRELLIS generation resolution")
    parser.add_argument("--out-dir", help="Directory to save final GLB (default: assets/models/)")
    parser.add_argument("--upload", action="store_true", help="Upload to Roblox Open Cloud Assets API")
    parser.add_argument("--insert", action="store_true", help="Insert directly into active Studio session after upload")
    args = parser.parse_args()

    if not args.prompt and not args.image:
        parser.error("Must specify either --prompt or --image.")

    env = load_env()
    hf_token = args.token or env.get("HF_TOKEN")
    roblox_key = env.get("ROBLOX_API_KEY")
    roblox_user = env.get("ROBLOX_USER_ID")
    roblox_group = env.get("ROBLOX_GROUP_ID")

    # Determine asset name
    base_name = args.name or (args.prompt.split(",")[0] if args.prompt else Path(args.image).stem)
    asset_name = sanitize_name(base_name)
    print(f"\n=======================================================")
    print(f" TRELLIS -> ROBLOX ASSET PIPELINE: {asset_name}")
    print(f"=======================================================")

    # Step 1: Image preparation
    work_dir = ROOT / "work/trellis" / asset_name
    work_dir.mkdir(parents=True, exist_ok=True)

    if args.image:
        image_src = Path(args.image)
        if not image_src.exists():
            import requests
            img_resp = requests.get(args.image, timeout=30)
            img_resp.raise_for_status()
            image_path = work_dir / f"{asset_name}_ref.png"
            image_path.write_bytes(img_resp.content)
        else:
            image_path = image_src
    else:
        image_path = work_dir / f"{asset_name}_prompt.png"
        generate_image_from_prompt(args.prompt, image_path)

    # Step 2: TRELLIS.2 3D Generation
    raw_glb = generate_trellis_glb(image_path, hf_token=hf_token, resolution=args.resolution)
    print(f"      Raw TRELLIS GLB generated: {raw_glb} ({round(raw_glb.stat().st_size/1e6, 2)} MB)")

    # Step 3: Mesh Optimization for Roblox
    # Keep generic report/map names isolated; multiple TRELLIS assets must never overwrite sidecars.
    out_dir = Path(args.out_dir) if args.out_dir else (ROOT / "assets/build/trellis" / asset_name)
    optimized_glb = optimize_mesh_for_roblox(raw_glb, out_dir, asset_name, max_tris=args.triangles)

    # Copy to standardized assets/models/
    standard_glb = ROOT / "assets/models" / f"{asset_name}.glb"
    if optimized_glb != standard_glb:
        shutil.copy2(optimized_glb, standard_glb)

    # Register in Phase 5 queue
    import trimesh
    try:
        loaded = trimesh.load(str(standard_glb))
        tris = len(loaded.faces) if hasattr(loaded, "faces") else args.triangles
    except Exception:
        tris = args.triangles
    register_in_import_queue(standard_glb, asset_name, tris)

    print(f"\n[DONE] Optimized Roblox GLB ready at: {standard_glb.relative_to(ROOT)}")

    # Step 4: Optional Upload & Insert
    if (args.upload or args.insert) and roblox_key and (roblox_user or roblox_group):
        try:
            asset_id = upload_to_roblox_open_cloud(standard_glb, asset_name, roblox_key, user_id=roblox_user, group_id=roblox_group)
            if args.insert:
                insert_into_studio_mcp(asset_id, asset_name)
        except Exception as e:
            print(f"[WARN] Roblox upload error: {e}")
    else:
        print("\nImport into Roblox Studio:")
        print(f"  1. Studio: Home/Avatar -> 3D Importer -> Select 'assets/models/{asset_name}.glb'")
        print(f"  2. Or configure ROBLOX_API_KEY in tools/trellis/.env to auto-upload and insert via Open Cloud.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
