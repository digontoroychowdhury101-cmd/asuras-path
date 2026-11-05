"""python3 tools/assets/build_shen_audio.py
Grandmaster Shen's original sound layers, synthesized from scratch with numpy (no recordings, no third-party samples), so every cue is ours to upload.
Palette: dry cloth, old wood beads, sharp air, restrained jade chime, dark bronze and steel; phase 2 adds rough breath and low bowed metal.
Seeded and reproducible; mono 48 kHz PCM16, peak-normalised to -3 dBFS, DC-removed. Writes assets/build/shen_audio/<Key>.wav and manifest.json.
Upload each as an Audio asset under the creator account and add `<Key> = "rbxassetid://..."` to PresentationAssets.Audio; ShenPresentation then prefers it over its stand-in.
"""
import json
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/build/shen_audio"
SR = 48000
rng = np.random.default_rng(20261105)


def axis(d):
    return np.arange(int(d * SR)) / SR


def noise(d):
    return rng.normal(0, 1, int(d * SR))


def band(x, low, high):
    """FFT brick with soft shoulders: all this palette needs, no scipy here."""
    f = np.fft.rfftfreq(len(x), 1 / SR)
    gain = np.clip((f - low * 0.8) / max(low * 0.2, 1), 0, 1) * np.clip((high * 1.2 - f) / max(high * 0.2, 1), 0, 1)
    return np.fft.irfft(np.fft.rfft(x) * gain, len(x))


def env(t, attack, decay):
    return np.clip(t / max(attack, 1e-4), 0, 1) * np.exp(-np.maximum(t - attack, 0) / decay)


def sweep_band(d, lows, highs, blocks=24):
    """Noise whose band moves over time: overlapping filtered blocks."""
    n = int(d * SR)
    out = np.zeros(n)
    size = n // blocks * 2
    for i in range(blocks * 2 - 1):
        a = i * size // 2
        piece = rng.normal(0, 1, size)
        w = i / max(blocks * 2 - 2, 1)
        piece = band(piece, float(np.interp(w, [0, 1], lows)), float(np.interp(w, [0, 1], highs))) * np.hanning(size)
        end = min(a + size, n)
        if end > a:
            out[a:end] += piece[:end - a]
    return out


def partials(t, freqs, decays, amps):
    return sum(a * np.sin(2 * np.pi * f * t + i) * np.exp(-t / k) for i, (f, k, a) in enumerate(zip(freqs, decays, amps)))


def reverb(x, tail=0.5, wet=0.2):
    ir = rng.normal(0, 1, int(tail * SR)) * np.exp(-np.arange(int(tail * SR)) / (tail * SR * 0.25))
    n = len(x) + len(ir)
    y = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)
    return np.concatenate([x, np.zeros(len(ir))]) * (1 - wet) + y / np.max(np.abs(y) + 1e-9) * wet * np.max(np.abs(x))


def steel_air():
    t = axis(0.34)
    x = sweep_band(0.34, [1800, 5200], [4200, 11000])
    return x * np.sin(np.pi * np.clip(t / 0.34, 0, 1)) ** 2.5


def bronze_contact():
    t = axis(0.5)
    tone = partials(t, [612, 1490, 2410, 3770], [0.14, 0.09, 0.05, 0.03], [1, 0.6, 0.35, 0.2])
    click = band(noise(0.5), 2000, 9000) * env(t, 0.0005, 0.006)
    return reverb(tone * 0.7 + click, 0.35, 0.15)


def bead_click():
    t = axis(0.12)
    wood = partials(t, [1180, 2290, 3430], [0.012, 0.008, 0.005], [1, 0.6, 0.3])
    tick = band(noise(0.12), 1500, 7000) * env(t, 0.0003, 0.004)
    second = np.zeros_like(t)
    k = int(0.03 * SR)
    second[k:] = wood[:-k] * 0.5
    return wood + tick * 0.7 + second


def jade_chime():
    t = axis(0.9)
    return reverb(partials(t, [2120, 3392, 5088], [0.3, 0.16, 0.08], [1, 0.45, 0.2]) * env(t, 0.001, 1), 0.5, 0.25)


def tension_rise():
    t = axis(1.05)
    tone = np.sin(2 * np.pi * np.cumsum(np.linspace(180, 520, len(t))) / SR) * 0.5 + np.sin(2 * np.pi * np.cumsum(np.linspace(362, 1045, len(t))) / SR) * 0.25
    air = sweep_band(1.05, [400, 2600], [1200, 7000]) * 0.5
    return (tone + air) * (t / 1.05) ** 2.2


def bead_launch():
    t = axis(0.45)
    x = sweep_band(0.45, [3500, 600], [9000, 2600])
    return x * env(t, 0.006, 0.12) + partials(t, [1400, 2800], [0.03, 0.02], [0.4, 0.2])


def low_sweep():
    t = axis(0.55)
    x = sweep_band(0.55, [180, 700], [900, 3200])
    return x * np.sin(np.pi * t / 0.55) ** 2 + np.sin(2 * np.pi * 75 * t) * np.sin(np.pi * t / 0.55) ** 3 * 0.4


def cloth_rustle():
    t = axis(0.5)
    x = band(noise(0.5), 900, 6000)
    gate = np.convolve(np.abs(rng.normal(0, 1, len(t))) > 2.3, np.hanning(int(0.012 * SR)), "same")
    return x * np.clip(gate, 0, 1) * np.sin(np.pi * t / 0.5) ** 0.7


def scrape():
    t = axis(0.85)
    x = band(noise(0.85), 500, 5200)
    chatter = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 38 * t + 3 * np.sin(2 * np.pi * 5 * t)))
    ring = np.sin(2 * np.pi * 930 * t) * 0.12 + np.sin(2 * np.pi * 2210 * t) * 0.06
    return (x * chatter + ring) * np.clip(t / 0.1, 0, 1) * np.clip((0.85 - t) / 0.12, 0, 1)


def rough(t, f0, depth=0.6):
    """A rough vocal source: a detuned saw with jitter, formants carved by band."""
    jitter = np.cumsum(rng.normal(0, 1, len(t))) / SR * 40
    phase = 2 * np.pi * (f0 * t + jitter)
    saw = 2 * (phase / (2 * np.pi) % 1) - 1
    grit = band(rng.normal(0, 1, len(t)), 200, 2400) * depth
    return saw * (0.7 + 0.3 * np.sin(2 * np.pi * 31 * t)) + grit


def growl_exhale():
    t = axis(0.75)
    x = rough(t, 62)
    x = band(x, 90, 1300) + band(noise(0.75), 800, 3400) * 0.4
    return x * np.clip(t / 0.06, 0, 1) * np.exp(-t / 0.42)


def bowed_metal():
    t = axis(1.5)
    bow = 1 + 0.004 * np.sin(2 * np.pi * 5.1 * t)
    tone = sum(a * np.sin(2 * np.pi * f * bow * t + i) for i, (f, a) in enumerate([(58, 1), (117.4, 0.6), (181, 0.42), (293, 0.3), (497, 0.14)]))
    hit = band(noise(1.5), 120, 2600) * env(t, 0.001, 0.05)
    return reverb(tone * np.clip(t / 0.02, 0, 1) * np.exp(-t / 0.62) + hit * 0.8, 0.8, 0.22)


def air_tear():
    t = axis(1.15)
    x = sweep_band(1.15, [300, 3200], [1400, 10000])
    return x * (t / 1.15) ** 1.8 * np.clip((1.15 - t) / 0.03, 0, 1)


def land_impact():
    t = axis(1.2)
    boom = np.sin(2 * np.pi * (34 * t + 30 * (1 - np.exp(-t / 0.05)) * 0.05)) * np.exp(-t / 0.34)
    crack = band(noise(1.2), 600, 7000) * env(t, 0.0006, 0.035)
    rubble = band(noise(1.2), 180, 1600) * env(t, 0.01, 0.3) * 0.4
    return reverb(boom * 1.2 + crack + rubble, 0.6, 0.15)


def breath_intake():
    t = axis(0.8)
    x = sweep_band(0.8, [500, 1700], [1800, 5600])
    return x * (t / 0.8) ** 1.4 * np.clip((0.8 - t) / 0.03, 0, 1)


def falter():
    t = axis(0.6)
    x = band(rough(t, 96, 0.5), 180, 1500)
    return x * np.sin(np.pi * t / 0.6) ** 2 * (1 - 0.5 * (t / 0.6))


def roar():
    t = axis(1.6)
    f = np.interp(t, [0, 0.25, 1.6], [68, 112, 74])
    jitter = np.cumsum(rng.normal(0, 1, len(t))) / SR * 40
    phase = 2 * np.pi * (np.cumsum(f) / SR + jitter)
    saw = 2 * (phase / (2 * np.pi) % 1) - 1
    body = band(saw, 90, 1700) + band(noise(1.6), 900, 4200) * 0.35
    sub = np.sin(2 * np.pi * 44 * t) * 0.4
    return reverb((body + sub) * np.clip(t / 0.18, 0, 1) * np.clip((1.6 - t) / 0.7, 0, 1), 0.7, 0.2)


CUES = {"ShenSteelAir": steel_air, "ShenBronzeContact": bronze_contact, "ShenBeadClick": bead_click, "ShenJadeChime": jade_chime, "ShenTensionRise": tension_rise, "ShenBeadLaunch": bead_launch,
        "ShenLowSweep": low_sweep, "ShenClothRustle": cloth_rustle, "ShenScrape": scrape, "ShenGrowlExhale": growl_exhale, "ShenBowedMetal": bowed_metal, "ShenAirTear": air_tear,
        "ShenLandImpact": land_impact, "ShenBreathIntake": breath_intake, "ShenFalter": falter, "ShenRoar": roar}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for key, make in CUES.items():
        x = make()
        x = x - np.mean(x)
        fade_in, fade_out = int(0.003 * SR), int(0.05 * SR)
        x[:fade_in] *= np.linspace(0, 1, fade_in)
        x[-fade_out:] *= np.linspace(1, 0, fade_out)
        x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (-3 / 20)
        with wave.open(str(OUT / (key + ".wav")), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((x * 32767).astype("<i2").tobytes())
        manifest[key] = {"seconds": round(len(x) / SR, 3), "peak": round(float(np.max(np.abs(x))), 3), "rms": round(float(np.sqrt(np.mean(x ** 2))), 3)}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(len(manifest), "cues", manifest)


if __name__ == "__main__":
    main()
