"""python3 tools/assets/build_skill_audio.py
Original sound effects for the showcase sorceries (Celestial Supernova, Blazing Sun Awakening),
synthesized from scratch: filtered noise, oscillators, pitch sweeps, saturation and a generated
reverb. No recordings or third-party samples, so every cue is ours to upload. Seeded and
reproducible; mono 48 kHz PCM16, peak-normalised to -3 dBFS, DC-removed, 5 ms / 50 ms fades.
Writes assets/build/skill_audio/<Key>.wav and manifest.json (duration, peak, rms per cue).
"""
from __future__ import annotations

import json
import wave
from pathlib import Path

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/build/skill_audio'
SR = 48000
rng = np.random.default_rng(20261024)


def t_axis(d: float) -> np.ndarray:
    return np.arange(int(d * SR)) / SR


def noise(d: float) -> np.ndarray:
    return rng.normal(0, 1, int(d * SR))


def band(x: np.ndarray, low: float | None, high: float | None, order: int = 4) -> np.ndarray:
    if low and high:
        sos = signal.butter(order, [low, high], 'bandpass', fs=SR, output='sos')
    elif low:
        sos = signal.butter(order, low, 'highpass', fs=SR, output='sos')
    else:
        sos = signal.butter(order, high, 'lowpass', fs=SR, output='sos')
    return signal.sosfilt(sos, x)


def sweep(x: np.ndarray, cutoffs: np.ndarray, kind: str = 'lowpass', chunk: int = 512) -> np.ndarray:
    """Time-varying filter: `cutoffs` (Hz) per sample, applied block-wise with carried state."""
    out = np.zeros_like(x)
    zi = None
    for start in range(0, len(x), chunk):
        fc = float(np.clip(cutoffs[min(start, len(cutoffs) - 1)], 40, SR * 0.45))
        sos = signal.butter(2, fc, kind, fs=SR, output='sos')
        if zi is None or zi.shape[0] != sos.shape[0]:
            zi = signal.sosfilt_zi(sos) * 0
        out[start:start + chunk], zi = signal.sosfilt(sos, x[start:start + chunk], zi=zi)
    return out


def env(d: float, attack: float, decay: float, hold: float = 0) -> np.ndarray:
    t = t_axis(d)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    tail = np.where(t > attack + hold, np.exp(-(t - attack - hold) / max(decay, 1e-4)), 1)
    return a * tail


def tone(freqs: np.ndarray, d: float, shape: str = 'sine') -> np.ndarray:
    phase = np.cumsum(freqs[: int(d * SR)]) / SR * 2 * np.pi
    if shape == 'saw':
        return 2 * ((phase / (2 * np.pi)) % 1) - 1
    return np.sin(phase)


def glide(f0: float, f1: float, d: float, curve: float = 1.0) -> np.ndarray:
    k = t_axis(d) / d
    return f0 * (f1 / f0) ** (k ** curve)


def crackle(d: float, rate: float, bright: float = 3000) -> np.ndarray:
    x = np.zeros(int(d * SR))
    hits = rng.random(len(x)) < rate / SR
    x[hits] = rng.normal(0, 1, hits.sum()) * rng.random(hits.sum()) ** 2
    return band(x, bright, None, 2)


def reverb(x: np.ndarray, seconds: float, wet: float) -> np.ndarray:
    ir = noise(seconds) * np.exp(-t_axis(seconds) / (seconds / 5))
    ir = band(ir, 200, 9000, 2)
    tail = signal.fftconvolve(x, ir)[: len(x)]
    tail /= np.max(np.abs(tail)) + 1e-9
    return x + tail * wet * np.max(np.abs(x))


def pad(x: np.ndarray, d: float) -> np.ndarray:
    out = np.zeros(int(d * SR))
    out[: min(len(x), len(out))] = x[: len(out)]
    return out


def mix(d: float, *layers: tuple[np.ndarray, float, float]) -> np.ndarray:
    out = np.zeros(int(d * SR))
    for data, at, gain in layers:
        start = int(at * SR)
        n = min(len(data), len(out) - start)
        if n > 0:
            out[start:start + n] += data[:n] * gain
    return out


# ---------------------------------------------------------------- Celestial Supernova
def nova_void() -> np.ndarray:  # 0.0 s: the void opens, wind and a low drone swell
    d = 2.8
    t = t_axis(d)
    wind = band(noise(d), 180, 1900) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.7 * t)) * env(d, 0.9, 0.9, 0.8)
    drone = (np.sin(2 * np.pi * 55 * t) + 0.6 * np.sin(2 * np.pi * 82.4 * t + 1) + 0.3 * np.sin(2 * np.pi * 110.3 * t)) * env(d, 1.2, 1.0, 0.4)
    return reverb(wind * 0.9 + drone * 0.5, 1.6, 0.4)


def nova_ring() -> np.ndarray:  # 1.3 s: the glowing ring snaps open, crystalline
    d = 1.8
    t = t_axis(d)
    bell = sum(np.sin(2 * np.pi * 1240 * r * t) * np.exp(-t * k) * g for r, k, g in ((1, 2.2, 1), (2.76, 3.5, 0.6), (5.4, 5, 0.35), (8.93, 7, 0.2)))
    shimmer = band(noise(d), 6000, 14000) * env(d, 0.005, 0.25) * 0.5
    swell = band(noise(d), 800, 4000) * env(d, 0.08, 0.12) * 0.3
    return reverb(bell * 0.6 + shimmer + swell, 1.8, 0.55)


def nova_swoop() -> np.ndarray:  # 1.6 s: the camera swoop
    d = 1.0
    k = t_axis(d) / d
    cut = 300 + 4200 * np.sin(np.pi * k) ** 2
    return sweep(noise(d), cut) * np.sin(np.pi * k) ** 1.5


def nova_planet() -> np.ndarray:  # 2.2 s: the planet hums and rises
    d = 2.6
    t = t_axis(d)
    rise = glide(1, 1.18, d, 1.4)
    hum = sum(tone(f * rise * (1 + 0.004 * np.sin(2 * np.pi * 0.3 * t + i)), d) * g for i, (f, g) in enumerate(((65.4, 1), (98, 0.7), (130.8, 0.5), (196, 0.25))))
    hum *= (1 + 0.25 * np.sin(2 * np.pi * 6 * t)) * env(d, 0.5, 0.6, 1.4)
    air = band(noise(d), 1500, 6000) * env(d, 0.8, 0.5, 1.0) * 0.25
    return reverb(hum * 0.6 + air, 1.4, 0.35)


def nova_charge() -> np.ndarray:  # 4.0 s: the riser into the detonation (cuts dead at the hit)
    d = 0.75
    k = t_axis(d) / d
    saw = tone(glide(110, 880, d, 2), d, 'saw') * k ** 2
    hiss = sweep(noise(d), 400 + 9000 * k ** 2, 'highpass') * k ** 1.5
    return band(saw, None, 5000) * 0.5 + hiss * 0.6


def blast(d: float, sub: tuple[float, float], body_cut: float, crack_rate: float, tail: float) -> np.ndarray:
    t = t_axis(d)
    thump = tone(glide(sub[0], sub[1], 0.5, 0.5), 0.5) * env(0.5, 0.002, 0.18)
    body = band(noise(d), None, body_cut) * env(d, 0.004, tail)
    snap = band(noise(0.08), 2500, None) * env(0.08, 0.001, 0.02)
    crk = crackle(d, crack_rate) * np.exp(-t / (tail * 1.5))
    x = mix(d, (thump, 0, 1.2), (body, 0, 0.9), (snap, 0, 0.7), (crk, 0.05, 0.6))
    return np.tanh(x * 1.6)


def nova_blast() -> np.ndarray:  # 4.66 s: detonation
    d = 3.0
    return reverb(blast(d, (70, 32), 1400, 120, 0.7), 2.2, 0.5)


def nova_ink() -> np.ndarray:  # 5.02 s: the ink frames slap in
    d = 0.4
    slap = band(noise(d), 1800, None) * env(d, 0.001, 0.035)
    click = np.sin(2 * np.pi * 3200 * t_axis(d)) * env(d, 0.0005, 0.01)
    rev = band(noise(0.25), 3000, None) * np.linspace(0, 1, int(0.25 * SR)) ** 3
    return mix(d, (rev, 0, 0.35), (slap, 0.25, 1), (click, 0.25, 0.5))


def nova_column() -> np.ndarray:  # 5.3 s: the light column roars
    d = 2.8
    t = t_axis(d)
    roar = band(noise(d), 120, 900) * (1 + 0.3 * np.sin(2 * np.pi * 3.3 * t))
    hum = (np.sin(2 * np.pi * 110 * t) + 0.5 * np.sin(2 * np.pi * 165 * t) + 0.3 * np.sin(2 * np.pi * 330 * t)) * (1 + 0.35 * np.sin(2 * np.pi * 9 * t))
    sizzle = band(noise(d), 5000, 12000) * 0.15
    return (roar * 0.8 + hum * 0.35 + sizzle) * env(d, 0.08, 0.5, 2.0)


def nova_white() -> np.ndarray:  # 7.7 s: the slow whiteout swells to silence
    d = 2.0
    k = t_axis(d) / d
    swell = sweep(noise(d), 600 + 8000 * k, 'highpass') * np.where(k < 0.65, (k / 0.65) ** 2, np.exp(-(k - 0.65) * 14))
    chord = sum(np.sin(2 * np.pi * f * t_axis(d)) for f in (880, 1108.7, 1318.5)) * np.where(k < 0.65, k / 0.65, np.exp(-(k - 0.65) * 10)) * 0.12
    return reverb(swell * 0.7 + chord, 1.5, 0.4)


# ---------------------------------------------------------------- Blazing Sun Awakening
def sun_tension() -> np.ndarray:  # 0.0 s: the world turns orange, a heartbeat under a rumble
    d = 2.4
    t = t_axis(d)
    rumble = band(noise(d), 30, 140) * env(d, 0.6, 0.6, 1.2)
    beats = mix(d, *((tone(glide(70, 45, 0.25), 0.25) * env(0.25, 0.003, 0.07), at, 1) for at in (0.1, 0.36, 1.1, 1.36)))
    crk = crackle(d, 25, 2500) * env(d, 0.4, 1.0, 1.0)
    return rumble * 0.9 + beats * 0.9 + crk * 0.5 + 0 * t


def sun_boom() -> np.ndarray:  # 1.7 s: the comic BOOM
    d = 0.8
    kick = tone(glide(140, 48, 0.35, 0.6), 0.35) * env(0.35, 0.002, 0.12)
    tom = tone(glide(220, 160, 0.3), 0.3) * env(0.3, 0.002, 0.08)
    snap = band(noise(0.1), 1500, 7000) * env(0.1, 0.001, 0.03)
    return np.tanh(mix(d, (kick, 0, 1.3), (tom, 0, 0.5), (snap, 0, 0.6)) * 1.8)


def sun_ember() -> np.ndarray:  # 2.1 s: the chest ember kindles
    d = 1.4
    whoomp = sweep(noise(d), 200 + 1800 * env(d, 0.15, 0.3), 'lowpass') * env(d, 0.12, 0.35)
    return whoomp * 0.9 + crackle(d, 60, 2200) * env(d, 0.05, 0.6) * 0.8


def sun_thorn() -> np.ndarray:  # 4.1 s: the thorn ring clamps shut
    d = 0.7
    t = t_axis(d)
    metal = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in ((431, 9), (1103, 12), (1731, 15), (2914, 20)))
    metal *= 1 + 0.5 * np.sin(2 * np.pi * 57 * t)
    click = band(noise(0.03), 2000, None) * env(0.03, 0.0005, 0.008)
    return np.tanh(mix(d, (metal * 0.5, 0, 1), (click, 0, 0.8)) * 1.5)


def sun_charge() -> np.ndarray:  # 4.5 s: fire builds into the blast
    d = 0.75
    k = t_axis(d) / d
    roar = sweep(noise(d), 200 + 3200 * k ** 1.5, 'lowpass') * k ** 1.6
    rumble = band(noise(d), 30, 120) * k
    return roar * 0.9 + rumble * 0.6


def sun_blast() -> np.ndarray:  # release: the blast and a roaring fire tail
    d = 3.4
    t = t_axis(d)
    hit = blast(d, (90, 38), 1800, 200, 0.9)
    flicker = band(noise(d), None, 12, 1)
    flicker /= np.max(np.abs(flicker)) + 1e-9
    fire = band(noise(d), 150, 1500) * (0.7 + 0.3 * flicker) * env(d, 0.15, 1.2, 0.8)
    return reverb(np.tanh(hit * 0.9 + fire * 0.5 + 0 * t), 1.6, 0.35)


def sun_eyes() -> np.ndarray:  # +3.55 s: the eyes ignite
    d = 1.6
    fwoosh = sweep(noise(d), 300 + 5000 * env(d, 0.1, 0.25), 'lowpass') * env(d, 0.06, 0.3)
    sizzle = band(noise(d), 4000, 11000) * env(d, 0.05, 0.6, 0.2) * 0.35
    return fwoosh + sizzle + crackle(d, 90, 3500) * env(d, 0.05, 0.8) * 0.6


def sun_gauntlet() -> np.ndarray:  # +5.45 s: the fists burn
    d = 2.2
    t = t_axis(d)
    flutter = 0.65 + 0.35 * np.abs(np.sin(2 * np.pi * 7 * t + np.sin(2 * np.pi * 1.3 * t)))
    roar = band(noise(d), 250, 2200) * flutter * env(d, 0.12, 0.6, 1.2)
    return roar * 0.8 + crackle(d, 70, 2800) * env(d, 0.1, 0.8, 1.0) * 0.6


def sun_pulse() -> np.ndarray:  # pulses: a heat ring thumps out
    d = 0.9
    thump = tone(glide(80, 40, 0.3), 0.3) * env(0.3, 0.002, 0.1)
    whump = band(noise(d), None, 700) * env(d, 0.01, 0.2)
    return np.tanh(mix(d, (thump, 0, 1), (whump, 0, 0.8)) * 1.4)


CUES = {
    'NovaVoid': nova_void, 'NovaRing': nova_ring, 'NovaSwoop': nova_swoop, 'NovaPlanet': nova_planet,
    'NovaCharge': nova_charge, 'NovaBlast': nova_blast, 'NovaInk': nova_ink, 'NovaColumn': nova_column, 'NovaWhite': nova_white,
    'SunTension': sun_tension, 'SunBoom': sun_boom, 'SunEmber': sun_ember, 'SunThorn': sun_thorn, 'SunCharge': sun_charge,
    'SunBlast': sun_blast, 'SunEyes': sun_eyes, 'SunGauntlet': sun_gauntlet, 'SunPulse': sun_pulse,
}


def save(key: str, a: np.ndarray) -> dict:
    a = np.asarray(a, dtype=np.float64)
    a -= a.mean()
    fade_in, fade_out = min(int(0.005 * SR), len(a) // 3), min(int(0.05 * SR), len(a) // 3)
    a[:fade_in] *= np.linspace(0, 1, fade_in)
    a[-fade_out:] *= np.linspace(1, 0, fade_out)
    a *= 0.707 / max(np.max(np.abs(a)), 1e-9)
    with wave.open(str(OUT / f'{key}.wav'), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((a * 32767).astype('<i2').tobytes())
    return {'seconds': round(len(a) / SR, 3), 'peak': round(float(np.max(np.abs(a))), 3),
            'rms': round(float(np.sqrt(np.mean(a ** 2))), 4), 'source': 'original synthesis (noise, oscillators, filters, generated reverb)'}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {key: save(key, build()) for key, build in CUES.items()}
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2))
    for key, info in manifest.items():
        print(f"{key:12} {info['seconds']:5.2f}s peak {info['peak']} rms {info['rms']}")


if __name__ == '__main__':
    main()
