#!/usr/bin/env python3
"""Builds assets/audio/ for The Twelfth Moon from the two audio packs.

  Super Dialogue Audio Pack v1.zip  (Dillon Becker, CC BY 4.0)  -> voice barks
  FootSteps/FreeSteps/*/*.ogg       (author unknown)            -> footsteps

The dialogue pack ships 32-bit FLOAT mono WAVs (44.1 or 48 kHz) that also carry
~50 KB of ID3 tags each, so one 0.5 s clip weighs ~200 KB. Python's `wave`
module cannot read float WAVs, hence the small RIFF parser below. For every
chosen clip this script: reads it straight from the zip, trims the silence,
fades the edges, evens the loudness (RMS), optionally halves the sample rate
(22.05 / 24 kHz is plenty for barks), and writes a 16-bit mono WAV.
Footsteps are copied byte for byte (already small, stereo OGG).
Only the clips listed in VOICE_BANKS / STEP_SURFACES ship, about 3 MB at half rate.

Usage (from the project folder):
    python tools/import_audio.py                 # writes assets/audio/
    python tools/import_audio.py --out SOME_DIR  # somewhere else (tests)
    python tools/import_audio.py --full-rate     # keep 44.1 / 48 kHz

Pure standard library. Re-running overwrites; it never deletes other files.
"""
import argparse
import array
import io
import math
import struct
import wave
import zipfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
PACK_ZIP = PROJECT.parent / "Super Dialogue Audio Pack v1.zip"
STEPS_DIR = PROJECT.parent / "FootSteps" / "FreeSteps"

ZIP_ROOT = "Super Dialogue Audio Pack v1/Step 2 - Audio Files/"
CATEGORY_FOLDERS = {
    "completion": "1 - Completion", "confirmation": "2 - Confirmation",
    "greeting": "3 - Greeting", "farewell": "4 - Farewell",
    "refusal": "5 - Refusal", "miscellaneous": "6 - Miscellaneous",
    "damage": "7 - Damage", "death": "8 - Death",
    "grunting": "9 - Grunting", "shouting": "10 - Shouting",
}
# actor -> (gender folder, short name used in the file names)
ACTORS = {
    "Meghan Christian": ("Female", "meghan"),
    "Karen Cenon": ("Female", "karen"),
    "Alex Brodie": ("Male", "alex"),
    "Sean Lenhart": ("Male", "sean"),
    "Ian Lampert": ("Male", "ian"),
}

# Take numbers are the pack's own (see its Reference Sheet.pdf). Miscellaneous:
# 17 [Sighing], 19 [Gasping]. Greeting: 1 Hello, 2 Hi, 3 Hey, 6 Welcome,
# 7 Greetings. Farewell: 1 Goodbye, 2 Bye, 6 Take care, 8 Farewell, 9 Good luck.
#
# Bank -> actor -> {output group: (pack category, [take numbers])}.
# Output: assets/audio/voice/<bank>/<group>_<NN>.wav (NN counts from 01).
# Only the groups the game plays are listed; add one here and re-run to ship it.
VOICE_BANKS = {
    # Mariane herself. Meghan's takes are the short, gentle ones. The "land"
    # takes are her softest grunts (lowest level before the evening out).
    "mariane": ("Meghan Christian", {
        "grunt": ("grunting", [1, 2, 7, 8, 9, 10]),      # sword effort
        "land": ("grunting", [6, 3]),                    # a real drop
        "hurt": ("damage", [1, 2, 4, 5, 6, 7, 8, 9]),
        "death": ("death", [6, 9, 4]),
        "shout": ("shouting", [1, 2, 6, 3]),             # Moon Slash / Spark
        "sigh": ("miscellaneous", [17]),                 # campfire warmth
        "gasp": ("miscellaneous", [19]),                 # waking; Kael appears
    }),
    # Female villagers (Rosa, Lina, Mara, Wren, Hild) and the Moon Witch.
    "karen": ("Karen Cenon", {
        "greet": ("greeting", [1, 2, 3, 6, 7]),
        "farewell": ("farewell", [1, 2, 6, 8, 9]),
        "hurt": ("damage", [1, 3, 6, 9, 2]),
        "shout": ("shouting", [8, 6, 7, 5, 1]),
        "death": ("death", [1]),                         # 2.6 s, witch dissolves
    }),
    # Male villagers (Joss, Bram, Theo), and the goblin and mushroom, pitched.
    "alex": ("Alex Brodie", {
        "greet": ("greeting", [1, 2, 3, 6, 7]),
        "farewell": ("farewell", [1, 2, 6, 8, 9]),
        "hurt": ("damage", [1, 2, 3, 6, 9, 10]),
        "death": ("death", [2, 3, 5]),                   # short ones
    }),
    # Tomas and Pell.
    "sean": ("Sean Lenhart", {
        "greet": ("greeting", [1, 2, 3, 6, 7]),
        "farewell": ("farewell", [1, 2, 6, 8, 9]),
    }),
    # Kael (played low) and the Shield Knight.
    "ian": ("Ian Lampert", {
        "shout": ("shouting", [1, 2, 3, 4, 5]),
        "hurt": ("damage", [1, 2, 3, 4]),
        "grunt": ("grunting", [1, 2, 3]),
        "death": ("death", [8, 6]),                      # 2.5 s groans, the knight yields
    }),
}

# Footsteps: surface folder -> takes to ship (1-based). 8 takes per surface is
# enough to never hear the same step twice in a row. Floor is very short and
# clicky (0.03-0.09 s), Carpet is soft; both are left out for now. Dirt, Snow
# and Wood are played today; Gravel, Tiles and Water wait for later chapters.
STEP_SURFACES = {
    "Dirt": 8,     # village grass, autumn ground
    "Snow": 8,     # Chapter Three winter half
    "Wood": 8,     # planks, footbridge, hay loft
    "Gravel": 8,   # road, cave floor
    "Tiles": 8,    # castle floors, Chapter Four / Five
    "Water": 8,    # shallow water, river edge
}
STEP_SLUGS = {"Dirt": "dirt", "Snow": "snow", "Wood": "wood", "Gravel": "gravel",
              "Tiles": "tiles", "Water": "water"}

# --- signal processing ------------------------------------------------------
SILENCE_DB = -46.0     # below this counts as silence at a clip's edges
HEAD_PAD_MS = 8.0
TAIL_PAD_MS = 30.0
FADE_IN_MS = 3.0
FADE_OUT_MS = 25.0
TARGET_RMS_DB = -21.0  # loudness every clip is brought to...
PEAK_CEILING_DB = -1.0  # ...unless that would clip


def read_wav(data: bytes) -> tuple[list[float], int]:
    """Mono float samples and the sample rate of a RIFF WAV (PCM16/24 or float32)."""
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("not a RIFF WAVE file")
    pos, fmt, pcm = 12, None, b""
    while pos + 8 <= len(data):
        chunk_id = data[pos:pos + 4]
        size = struct.unpack("<I", data[pos + 4:pos + 8])[0]
        body = data[pos + 8:pos + 8 + size]
        if chunk_id == b"fmt ":
            fmt = struct.unpack("<HHIIHH", body[:16])
        elif chunk_id == b"data":
            pcm = body
        pos += 8 + size + (size & 1)  # chunks are word aligned
    if fmt is None or not pcm:
        raise ValueError("missing fmt/data chunk")
    tag, channels, rate, _, _, bits = fmt
    if tag == 3 and bits == 32:
        raw = array.array("f")
        raw.frombytes(pcm[:len(pcm) // 4 * 4])
        samples = list(raw)
    elif tag == 1 and bits == 16:
        raw = array.array("h")
        raw.frombytes(pcm[:len(pcm) // 2 * 2])
        samples = [v / 32768.0 for v in raw]
    else:
        raise ValueError(f"unsupported WAV format tag={tag} bits={bits}")
    if channels > 1:  # downmix
        samples = [sum(samples[i:i + channels]) / channels
                   for i in range(0, len(samples) - channels + 1, channels)]
    return samples, rate


def trim(samples: list[float], rate: int) -> list[float]:
    threshold = 10.0 ** (SILENCE_DB / 20.0)
    first = next((i for i, v in enumerate(samples) if abs(v) > threshold), 0)
    last = next((i for i in range(len(samples) - 1, -1, -1)
                 if abs(samples[i]) > threshold), len(samples) - 1)
    start = max(first - int(rate * HEAD_PAD_MS / 1000.0), 0)
    end = min(last + int(rate * TAIL_PAD_MS / 1000.0), len(samples))
    return samples[start:end]


def halve(samples: list[float]) -> list[float]:
    """Low-pass (windowed-sinc half-band FIR, 31 taps) and drop every 2nd sample."""
    taps = 31
    half = taps // 2
    kernel = []
    for n in range(-half, half + 1):
        sinc = 0.5 if n == 0 else math.sin(math.pi * n / 2.0) / (math.pi * n)
        window = 0.5 + 0.5 * math.cos(math.pi * n / (half + 1))
        kernel.append(sinc * window)
    total = sum(kernel)
    kernel = [k / total for k in kernel]
    padded = [0.0] * half + samples + [0.0] * half
    return [sum(k * padded[i + j] for j, k in enumerate(kernel))
            for i in range(0, len(samples), 2)]


def fade_and_level(samples: list[float], rate: int) -> list[float]:
    fade_in = max(int(rate * FADE_IN_MS / 1000.0), 1)
    fade_out = max(int(rate * FADE_OUT_MS / 1000.0), 1)
    n = len(samples)
    out = list(samples)
    for i in range(min(fade_in, n)):
        out[i] *= i / fade_in
    for i in range(min(fade_out, n)):
        out[n - 1 - i] *= i / fade_out
    rms = math.sqrt(sum(v * v for v in out) / max(n, 1))
    peak = max((abs(v) for v in out), default=0.0)
    if rms > 0.0 and peak > 0.0:
        gain = min(10.0 ** (TARGET_RMS_DB / 20.0) / rms,
                   10.0 ** (PEAK_CEILING_DB / 20.0) / peak)
        out = [v * gain for v in out]
    return out


def write_wav16(path: Path, samples: list[float], rate: int) -> None:
    pcm = array.array("h", (max(-32768, min(32767, round(v * 32767.0))) for v in samples))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(pcm.tobytes())


def build_voices(out_dir: Path, full_rate: bool, zip_path: Path) -> tuple[int, int]:
    count, total_bytes = 0, 0
    with zipfile.ZipFile(zip_path) as pack:
        for bank, (actor, groups) in VOICE_BANKS.items():
            gender, short = ACTORS[actor]
            for group, (category, takes) in groups.items():
                for index, take in enumerate(takes, start=1):
                    name = (f"{ZIP_ROOT}{CATEGORY_FOLDERS[category]}/{gender}/{actor}/"
                            f"{category}_{take}_{short}.wav")
                    samples, rate = read_wav(pack.read(name))
                    samples = trim(samples, rate)
                    if not full_rate:
                        samples = halve(samples)
                        rate //= 2
                    samples = fade_and_level(samples, rate)
                    target = out_dir / "voice" / bank / f"{group}_{index:02d}.wav"
                    write_wav16(target, samples, rate)
                    count += 1
                    total_bytes += target.stat().st_size
    return count, total_bytes


def build_steps(out_dir: Path, steps_dir: Path) -> tuple[int, int]:
    count, total_bytes = 0, 0
    for surface, takes in STEP_SURFACES.items():
        for take in range(1, takes + 1):
            source = steps_dir / surface / f"Steps_{surface.lower()}-{take:03d}.ogg"
            target = out_dir / "steps" / STEP_SLUGS[surface] / f"step_{take:02d}.ogg"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read_bytes())
            count += 1
            total_bytes += target.stat().st_size
    return count, total_bytes


CREDITS = """Audio credits (also shown on the credits screen)

Voices: "Super Dialogue Audio Pack v1" by Dillon Becker (dillonbecker.com),
licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).
Voice actors: Alex Brodie, Karen Cenon, Ian Lampert, Meghan Christian,
Sean Lenhart.
Changes made: clips trimmed, level-matched, resampled, mono (16-bit WAV).
The licensor does not endorse this game.

Footsteps: the "FreeSteps" pack (Dirt, Gravel, Snow, Tiles, Water, Wood),
copied unchanged. The folder it came in names no author and carries no licence
text: confirm both before the game is shared, then fix this line.

Regenerate everything with: python tools/import_audio.py
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--out", type=Path, default=PROJECT / "assets" / "audio")
    parser.add_argument("--zip", type=Path, default=PACK_ZIP, help="the dialogue pack")
    parser.add_argument("--steps", type=Path, default=STEPS_DIR, help="FootSteps/FreeSteps")
    parser.add_argument("--full-rate", action="store_true",
                        help="keep the pack's 44.1 / 48 kHz instead of halving")
    args = parser.parse_args()
    voices, voice_bytes = build_voices(args.out, args.full_rate, args.zip)
    steps, step_bytes = build_steps(args.out, args.steps)
    (args.out / "CREDITS.txt").write_text(CREDITS, encoding="utf-8")
    print(f"{voices} voice clips, {voice_bytes / 1e6:.2f} MB")
    print(f"{steps} footsteps, {step_bytes / 1e6:.2f} MB")
    print(f"total {(voice_bytes + step_bytes) / 1e6:.2f} MB -> {args.out}")


if __name__ == "__main__":
    main()
