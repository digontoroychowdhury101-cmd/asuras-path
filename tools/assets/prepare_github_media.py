"""Prepare the pinned CC0 media for Roblox. Requires Pillow and NumPy.

Run with the bundled workspace Python, or a Python with those two packages.
Raw sources remain untouched. RGB additive textures become white alpha masks;
existing alpha is retained. WAVs become mono 48 kHz PCM16, with a -6 dBFS peak.
"""
from pathlib import Path
import hashlib
import json
import argparse
import wave

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]


def prepare():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", default="assets/GITHUB_REUSE.json")
    parser.add_argument("--output", default="assets/github/ready")
    args = parser.parse_args()
    manifest_path = ROOT / args.manifest
    manifest = json.loads(manifest_path.read_text())
    ready = ROOT / args.output
    ready.mkdir(parents=True, exist_ok=True)
    previews = []
    for entry in manifest["files"]:
        if entry.get("kind") == "animation-source":
            continue
        source = ROOT / entry["file"]
        if entry["section"] == "Textures":
            image = Image.open(source).convert("RGBA")
            rgba = np.asarray(image).copy()
            alpha = rgba[:, :, 3]
            if np.min(alpha) == 255:  # additive RGB/opaque sources need black made transparent
                alpha = np.max(rgba[:, :, :3], axis=2)
            mask = Image.new("RGBA", image.size, "white")
            mask.putalpha(Image.fromarray(alpha))
            if entry["slot"] == "GithubThunder":
                mask = mask.transpose(Image.Transpose.ROTATE_90)  # Beam U follows its length
                entry["prepared_rotation_degrees"] = 90
            mask.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
            target = ready / f"{entry['slot']}.png"
            mask.save(target)
            entry["prepared_size"] = list(mask.size)
            tile = Image.new("RGB", (240, 264), (22, 25, 30))
            thumb = mask.copy()
            thumb.thumbnail((220, 220))
            colored = Image.new("RGBA", thumb.size, (255, 179, 79, 255))
            colored.putalpha(thumb.getchannel("A"))
            tile.paste(colored, ((240 - thumb.width) // 2, (230 - thumb.height) // 2), colored)
            ImageDraw.Draw(tile).text((12, 242), entry["slot"], fill="white")
            previews.append(tile)
        else:
            with wave.open(str(source)) as wav:
                channels, rate, width = wav.getnchannels(), wav.getframerate(), wav.getsampwidth()
                if width != 2:
                    raise ValueError("Expected pinned PCM16 source")
                samples = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").astype(float)
            samples = samples.reshape(-1, channels).mean(axis=1) / 32768
            count = round(len(samples) * 48000 / rate)
            samples = np.interp(np.arange(count) * rate / 48000, np.arange(len(samples)), samples)
            samples -= samples.mean()
            fade = min(240, len(samples) // 2)
            samples[:fade] *= np.linspace(0, 1, fade)
            samples[-fade:] *= np.linspace(1, 0, fade)
            peak = np.max(np.abs(samples))
            if not np.isfinite(peak) or peak <= 0:
                raise ValueError("Invalid/silent source audio")
            samples *= 10 ** (-6 / 20) / peak
            target = ready / f"{entry['slot']}.wav"
            with wave.open(str(target), "wb") as wav:
                wav.setparams((1, 2, 48000, 0, "NONE", "not compressed"))
                wav.writeframes(np.round(samples * 32767).astype("<i2").tobytes())
            entry["prepared_seconds"] = count / 48000
        entry["prepared_file"] = target.relative_to(ROOT).as_posix()
        entry["prepared_sha256"] = hashlib.sha256(target.read_bytes()).hexdigest()
        print("Prepared", entry["prepared_file"])
    if previews:
        sheet = Image.new("RGB", (720, 528))
        for index, tile in enumerate(previews):
            sheet.paste(tile, ((index % 3) * 240, (index // 3) * 264))
        sheet.save(ready / "preview.jpg")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    prepare()
