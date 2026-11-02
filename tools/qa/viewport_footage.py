#!/usr/bin/env python3
"""Record Studio Play viewport footage as an MP4 from repeated MCP screen captures (local QA evidence only).

    python tools/qa/viewport_footage.py STUDIO_ID SECONDS OUT.mp4 [--fps-cap 8]

Grabs viewport frames over the local StudioMCP proxy as fast as it answers, stamps each with its wall time,
then writes them at the measured capture rate, so the clip plays back in real time (at a low frame rate).
Nothing in the place or session is changed. Frames are kept next to the video in OUT_frames/.
"""
import argparse
import base64
import sys
import time
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import studio_mcp  # noqa: E402


def grab(client, studio, index):
    reply = client.request("tools/call", {"name": "screen_capture", "arguments": {"studio_id": studio, "capture_id": f"footage_{index}"}})
    for c in (reply.get("result") or {}).get("content", []):
        if c.get("type") == "image":
            buf = np.frombuffer(base64.b64decode(c["data"]), np.uint8)
            return cv2.imdecode(buf, cv2.IMREAD_COLOR)
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("studio")
    ap.add_argument("seconds", type=float)
    ap.add_argument("out", type=Path)
    ap.add_argument("--fps-cap", type=float, default=8.0)
    a = ap.parse_args()
    frames_dir = a.out.with_name(a.out.stem + "_frames")
    frames_dir.mkdir(parents=True, exist_ok=True)
    client = studio_mcp.Client()
    stamps, t0 = [], time.time()
    while time.time() - t0 < a.seconds:
        t = time.time()
        img = grab(client, a.studio, len(stamps))
        if img is None:
            continue
        cv2.imwrite(str(frames_dir / f"{len(stamps):04d}.jpg"), img, [cv2.IMWRITE_JPEG_QUALITY, 88])
        stamps.append(t - t0)
        wait = 1.0 / a.fps_cap - (time.time() - t)
        if wait > 0:
            time.sleep(wait)
    client.close()
    if len(stamps) < 2:
        sys.exit("no frames captured")
    fps = (len(stamps) - 1) / (stamps[-1] - stamps[0])
    first = cv2.imread(str(frames_dir / "0000.jpg"))
    h, w = first.shape[:2]
    writer = cv2.VideoWriter(str(a.out), cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    for i in range(len(stamps)):
        frame = cv2.imread(str(frames_dir / f"{i:04d}.jpg"))
        writer.write(cv2.resize(frame, (w, h)) if frame.shape[:2] != (h, w) else frame)
    writer.release()
    print(f"wrote {a.out}: {len(stamps)} frames over {stamps[-1]:.1f}s ({fps:.2f} fps)")


if __name__ == "__main__":
    main()
