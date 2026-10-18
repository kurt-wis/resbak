"""Synthesises the Home-diorama audio into assets/audio/home/ (numpy only, no network).

Everything here is generated in code, so it is original to this repo (CC0, see
assets/audio/CREDITS.md). Run from the repo root:

    python tools/make_home_audio.py

Outputs 16-bit mono 44.1 kHz WAV (the project already ships .wav next to .ogg):
    home_music.wav        32 s seamless ukulele-style loop (Karplus-Strong), C-Am-F-G
    ui_hover.wav          soft cardboard tick
    ui_click.wav          paper/cardboard tap
    jeep_horn.wav         two-note beep-beep
    jeep_pass.wav         5 s engine rumble with a Doppler-style pitch glide
    chatter_a..d.wav      short voiced "babble" grains; the game pitches them per hero
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join("assets", "audio", "home")
RNG = np.random.default_rng(1025)


def write_wav(name, x, peak=0.89):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m * peak
    pcm = (x * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", name, "%.2fs" % (len(x) / SR))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    s = 0.0
    for i in range(len(x)):
        s = (1 - a) * x[i] + a * s
        y[i] = s
    return y


def onepole_fast(x, cutoff):
    """FFT brick-wall-ish lowpass; fast for long buffers."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= 1.0 / (1.0 + (f / cutoff) ** 4)
    return np.fft.irfft(spec, len(x))


def highpass_fast(x, cutoff):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= 1.0 - 1.0 / (1.0 + (f / cutoff) ** 4)
    return np.fft.irfft(spec, len(x))


def env_ad(n, attack, decay_tau):
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / max(attack, 1e-4))
    return a * np.exp(-t / decay_tau)


# ---------------------------------------------------------------- music
def pluck(freq, dur, bright=0.5, decay=0.996):
    """Karplus-Strong string, block-vectorised."""
    n = int(dur * SR)
    period = max(2, int(round(SR / freq)))
    buf = (RNG.random(period) * 2 - 1) * bright + (RNG.random(period) * 2 - 1) * 0.0
    buf -= buf.mean()
    out = np.empty(n)
    pos = 0
    cur = buf.copy()
    while pos < n:
        take = min(period, n - pos)
        out[pos:pos + take] = cur[:take]
        cur = decay * 0.5 * (cur + np.roll(cur, 1))
        pos += take
    # soften the pick click
    return out * np.minimum(1.0, np.arange(n) / (0.002 * SR))


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def build_music():
    bpm = 90.0
    beat = 60.0 / bpm
    bars = 12
    total = bars * 4 * beat
    n = int(total * SR)
    tail = int(2.5 * SR)  # let the last notes ring, then fold onto the start for a seamless loop
    mix = np.zeros(n + tail)
    # ukulele re-entrant voicings (G C E A) as MIDI, per chord
    chords = {
        "C": [67, 72, 76, 79],
        "Am": [67, 72, 76, 81],
        "F": [65, 72, 76, 81],
        "G": [62, 71, 74, 79],
    }
    bass = {"C": 36, "Am": 33, "F": 41, "G": 43}
    prog = ["C", "Am", "F", "G"] * 3
    # melody (scale degrees as MIDI) per bar, 4 beats, 0 = rest; simple OPM-ish lullaby line
    mel = [
        [76, 0, 79, 76], [76, 74, 72, 0], [77, 0, 81, 77], [74, 72, 71, 0],
        [79, 0, 76, 72], [72, 76, 81, 0], [77, 76, 72, 0], [74, 0, 71, 74],
        [76, 79, 84, 79], [81, 0, 79, 76], [77, 81, 77, 72], [74, 0, 0, 0],
    ]
    for b in range(bars):
        c = prog[b]
        t0 = b * 4 * beat
        # strum: down on 1, down-up pattern D . D U . U D U in eighths
        pattern = [(0, 1), (2, 1), (3, 0.6), (5, 0.6), (6, 1), (7, 0.6)]
        for eighth, vel in pattern:
            st = t0 + eighth * beat / 2
            for k, m in enumerate(chords[c] if eighth not in (3, 5, 7) else chords[c][::-1]):
                s = pluck(mtof(m), 1.6, bright=0.5, decay=0.9955)
                i = int((st + k * 0.011) * SR)
                mix[i:i + len(s)] += s[:len(mix) - i] * 0.16 * vel
        # soft bass on 1 and 3
        for beat_i in (0, 2):
            s = pluck(mtof(bass[c]), 1.4, bright=0.35, decay=0.9985)
            s = onepole_fast(s, 500)
            i = int((t0 + beat_i * beat) * SR)
            mix[i:i + len(s)] += s[:len(mix) - i] * 0.5
        # melody
        for k, m in enumerate(mel[b]):
            if m == 0:
                continue
            s = pluck(mtof(m + 0), 1.2, bright=0.45, decay=0.9965)
            i = int((t0 + k * beat) * SR)
            mix[i:i + len(s)] += s[:len(mix) - i] * 0.42
    # fold the ring-out tail onto the loop start so the seam is continuous
    loop = mix[:n].copy()
    loop[:tail] += mix[n:n + tail]
    loop = onepole_fast(loop, 7500)
    # remove DC and gentle normalisation happens in write_wav
    loop -= loop.mean()
    return loop


# ---------------------------------------------------------------- sfx
def build_ui():
    n = int(0.09 * SR)
    noise = RNG.standard_normal(n)
    tick = highpass_fast(onepole_fast(noise, 5200), 1800) * env_ad(n, 0.0008, 0.012)
    thump = np.sin(2 * np.pi * 180 * np.arange(n) / SR) * env_ad(n, 0.001, 0.02) * 0.25
    hover = (tick * 0.5 + thump * 0.4)
    n2 = int(0.16 * SR)
    noise2 = RNG.standard_normal(n2)
    t2 = np.arange(n2) / SR
    tap = onepole_fast(noise2, 3200) * env_ad(n2, 0.0006, 0.03)
    body = np.sin(2 * np.pi * (140 - 40 * t2 / 0.16) * t2) * env_ad(n2, 0.001, 0.05) * 0.7
    click = tap + body
    return hover, click


def horn_note(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for h, a in ((1, 1.0), (2, 0.5), (3, 0.38), (4, 0.2), (5, 0.12)):
        sig += a * np.sign(np.sin(2 * np.pi * freq * h * t)) * 0.4 + a * np.sin(2 * np.pi * freq * h * t)
    sig = onepole_fast(sig, 2600)
    env = np.minimum(1.0, t / 0.012) * np.minimum(1.0, (dur - t) / 0.03)
    return sig * env


def build_horn():
    gap = np.zeros(int(0.12 * SR))
    note = horn_note(392.0, 0.26) + horn_note(494.0, 0.26) * 0.8
    return np.concatenate([note, gap, note, np.zeros(int(0.25 * SR))])


def build_jeep_pass():
    dur = 5.0 # matches the jeep's on-road pass (31 m at 6.2 m/s)
    n = int(dur * SR)
    t = np.arange(n) / SR
    # Doppler-ish glide: pitch drops as the vehicle passes the centre
    pitch = 1.12 - 0.24 / (1 + np.exp(-(t - dur / 2) * 2.4))
    base = 46.0
    phase = 2 * np.pi * np.cumsum(base * pitch) / SR
    eng = np.zeros(n)
    for h, a in ((1, 1.0), (2, 0.8), (3, 0.55), (4, 0.4), (6, 0.25), (8, 0.12)):
        eng += a * np.sin(h * phase + h * 0.6 * np.sin(phase * 0.5))
    # diesel-ish rattle: amplitude flutter at firing rate
    eng *= 0.75 + 0.25 * np.sign(np.sin(phase * 2)) * 0.6
    road = onepole_fast(RNG.standard_normal(n), 900) * 0.12
    sig = onepole_fast(eng, 520) + road
    amp = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.6
    return sig * amp


def build_chatter():
    out = []
    forms = [(730, 1090), (570, 1500), (300, 2300), (660, 1700), (450, 1000), (350, 800)]
    for v in range(4):
        syl = []
        for s in range(3 + v % 2):
            dur = RNG.uniform(0.07, 0.11)
            n = int(dur * SR)
            t = np.arange(n) / SR
            f0 = 190 * RNG.uniform(0.92, 1.18)
            glottal = np.zeros(n)
            for h in range(1, 28):
                glottal += np.sin(2 * np.pi * f0 * h * t) / h
            f1, f2 = forms[RNG.integers(len(forms))]
            sig = np.zeros(n)
            for fc, g in ((f1, 1.0), (f2, 0.6)):
                band = np.fft.rfft(glottal)
                fr = np.fft.rfftfreq(n, 1 / SR)
                band *= np.exp(-0.5 * ((fr - fc) / (fc * 0.18)) ** 2)
                sig += g * np.fft.irfft(band, n)
            sig *= np.minimum(1.0, t / 0.01) * np.minimum(1.0, (dur - t) / 0.025)
            syl.append(sig / (np.max(np.abs(sig)) + 1e-9))
            syl.append(np.zeros(int(0.015 * SR)))
        out.append(np.concatenate(syl))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    write_wav("home_music.wav", build_music(), peak=0.8)
    hover, click = build_ui()
    write_wav("ui_hover.wav", hover, peak=0.6)
    write_wav("ui_click.wav", click, peak=0.8)
    write_wav("jeep_horn.wav", build_horn(), peak=0.7)
    write_wav("jeep_pass.wav", build_jeep_pass(), peak=0.8)
    for i, g in enumerate(build_chatter()):
        write_wav("chatter_%s.wav" % "abcd"[i], g, peak=0.7)


if __name__ == "__main__":
    main()
