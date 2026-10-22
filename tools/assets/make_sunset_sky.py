#!/usr/bin/env python3
"""Golden-hour skybox for the Shrine of the Ascendant: six 1024 PNG cube faces (numpy, deterministic).

    python3 tools/assets/make_sunset_sky.py [OUT_DIR]   (default assets/build/lobby_sky)

Faces are named by the Roblox world direction they show (px = +X east ... nz = -Z north) and are
upright with +Y at the top for the four sides; up/down are kept nearly radially symmetric so their
in-plane rotation cannot show a seam. The warm glow sits at the Sanctuary sun (Lighting at ClockTime
17.5, latitude 24 -> almost due west, ~7 degrees up); Roblox draws the sun disc itself. Above the
horizon: lavender zenith, peach horizon, a band of sunlit cumulus. Below it: the sea of clouds.
Which face feeds which Sky property is verified in Studio (see assets/LOBBY_SKY.md); nothing here uploads.
"""
from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
N = 1024
SUN = np.array([-0.99, 0.13, 0.009])
SUN /= np.linalg.norm(SUN)
FACES = {  # name: (forward, right, up) in Roblox world axes
    'px': ((1, 0, 0), (0, 0, 1), (0, 1, 0)),
    'nx': ((-1, 0, 0), (0, 0, -1), (0, 1, 0)),
    'pz': ((0, 0, 1), (-1, 0, 0), (0, 1, 0)),
    'nz': ((0, 0, -1), (1, 0, 0), (0, 1, 0)),
    'py': ((0, 1, 0), (1, 0, 0), (0, 0, -1)),
    'ny': ((0, -1, 0), (1, 0, 0), (0, 0, 1)),
}


def periodic_noise(n: int, beta: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    spectrum = np.fft.fft2(rng.standard_normal((n, n)))
    f = np.sqrt(np.fft.fftfreq(n)[:, None] ** 2 + np.fft.fftfreq(n)[None, :] ** 2)
    f[0, 0] = 1
    spectrum *= f ** (-beta)
    spectrum[0, 0] = 0
    field = np.real(np.fft.ifft2(spectrum))
    return (field - field.min()) / (field.max() - field.min())


def sample(tex: np.ndarray, x: np.ndarray, y: np.ndarray) -> np.ndarray:
    n = tex.shape[0]
    x, y = (x % 1) * n, (y % 1) * n
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    a, b = tex[y0 % n, x0 % n], tex[y0 % n, (x0 + 1) % n]
    c, d = tex[(y0 + 1) % n, x0 % n], tex[(y0 + 1) % n, (x0 + 1) % n]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def smooth(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def rgb(*c: float) -> np.ndarray:
    return np.array(c, dtype=np.float64) / 255


def mix(a, b, t):
    return a * (1 - t[..., None]) + b * t[..., None]


BIG, SMALL, SEA = periodic_noise(1024, 1.7, 3), periodic_noise(1024, 1.2, 5), periodic_noise(1024, 1.5, 9)


def shade(d: np.ndarray) -> np.ndarray:
    e = d[..., 1]
    sun = np.clip(d @ SUN, -1, 1)
    flat = d[..., [0, 2]] / np.maximum(np.linalg.norm(d[..., [0, 2]], axis=-1, keepdims=True), 1e-6)
    side = (flat @ (SUN[[0, 2]] / np.linalg.norm(SUN[[0, 2]])) + 1) / 2  # 1 toward the sun's azimuth
    # Toward the zenith and nadir everything becomes azimuth-independent, so the up/down faces match
    # the side faces along every edge whatever in-plane rotation Roblox gives them.
    sym = smooth(0.48, 0.64, np.abs(e))
    side = side * (1 - sym) + 0.5 * sym
    up = smooth(0.0, 0.75, e) ** 0.6
    horizon = mix(rgb(238, 178, 160), rgb(255, 206, 140), side ** 1.5)
    sky = mix(horizon, mix(rgb(150, 160, 196), rgb(108, 132, 178), smooth(0.3, 1.0, e)), up)
    glow = np.clip(sun, 0, 1) * (1 - sym)
    sky += rgb(255, 214, 150) * (0.32 * glow ** 6 + 0.45 * glow ** 48)[..., None]
    # Cumulus band: projected onto a cloud ceiling, thinning with height, sunlit toward the west.
    hz = np.maximum(e, 0) + 0.06
    px, pz = d[..., 0] / hz * 0.09, d[..., 2] / hz * 0.09
    n = sample(BIG, px, pz) * 0.75 + sample(SMALL, px * 3.1, pz * 3.1) * 0.25
    band = smooth(0.012, 0.05, e) * (1 - smooth(0.26, 0.46, e))
    cover = smooth(0.44, 0.64, n) * band
    lit = np.clip(0.35 + 0.65 * side + 0.25 * (n - 0.6), 0, 1)
    cloud = mix(rgb(170, 140, 160), mix(rgb(248, 182, 158), rgb(255, 228, 180), side), lit)
    sky = mix(sky, cloud, cover * 0.92)
    # Sea of clouds below the horizon, brightest near it, shadowed blue-grey further down.
    dz = np.maximum(-e, 0) + 0.04
    qx, qz = d[..., 0] / dz * 0.05, d[..., 2] / dz * 0.05
    m = sample(SEA, qx, qz) * 0.7 + sample(SMALL, qx * 2.3, qz * 2.3) * 0.3
    tops = mix(rgb(150, 150, 172), mix(rgb(244, 214, 196), rgb(255, 232, 196), side), smooth(0.35, 0.75, m))
    tops = mix(tops, mix(rgb(250, 222, 200), rgb(255, 232, 190), side), 1 - smooth(0.0, 0.14, -e))
    deep = mix(tops, rgb(196, 190, 200), smooth(0.2, 0.5, -e))
    below = smooth(0.0, 0.03, -e)
    sky = mix(sky, deep, below)
    sky += rgb(255, 210, 150) * (0.25 * glow ** 10 * (1 - up))[..., None]
    return np.clip(sky, 0, 1)


def face(name: str) -> np.ndarray:
    forward, right, up = (np.array(v, dtype=np.float64) for v in FACES[name])
    s = (np.arange(N) + 0.5) / N * 2 - 1
    u, v = np.meshgrid(s, -s)  # row 0 is the top of the image
    d = forward + u[..., None] * right + v[..., None] * up
    d /= np.linalg.norm(d, axis=-1, keepdims=True)
    img = shade(d)
    img += (np.random.default_rng(len(name) * 7 + ord(name[0])).random(img.shape) - 0.5) / 255  # breaks banding
    return (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)


def write_png(path: Path, img: np.ndarray) -> None:
    h, w, _ = img.shape
    raw = b''.join(b'\x00' + img[y].tobytes() for y in range(h))
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'assets' / 'build' / 'lobby_sky'
    out.mkdir(parents=True, exist_ok=True)
    for name in FACES:
        write_png(out / f'Sunset_{name}.png', face(name))
    print('wrote', ', '.join(f'Sunset_{n}.png' for n in FACES), 'to', out)


if __name__ == '__main__':
    main()
