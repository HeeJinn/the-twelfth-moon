"""Shrinks the music for the web and phone builds.

The tracks came at 190-330 kbps; game music at about 112 kbps (Ogg Vorbis,
quality 3) sounds the same through phone speakers and laptop speakers and
halves the download. The reveal piece plays once and only about its first
two minutes are ever heard, so it keeps three minutes and fades out.

The untouched files live outside the game, in
GameDevAsset/Music sources/_game_originals/ (the first run moves them there);
every run re-encodes from those, so running it twice never compresses twice.
Tracks already at 128 kbps or less, and the WAVs (Godot compresses those
itself, and loops them from their import settings), are left as they are.

Needs ffmpeg: set FFMPEG to its path, or it uses the copy unpacked in
Downloads/twelfth-moon-build-tools. Run from the project folder:
  python tools/shrink_music.py
Then open Godot once (--import) so it imports the new .ogg files.
"""
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MUSIC = ROOT / "assets" / "music"
ORIGINALS = ROOT.parent / "Music sources" / "_game_originals"
FFMPEG = os.environ.get("FFMPEG", str(Path.home() / "Downloads" / "twelfth-moon-build-tools"
        / "ffmpeg" / "ffmpeg-master-latest-win64-gpl" / "bin" / "ffmpeg.exe"))
QUALITY = "3"
LOW_ENOUGH_KBPS = 128
# Plays once: keep this many seconds, fading out over the last few.
TRIMS = {"reveal": (180.0, 8.0)}


def bitrate_kbps(path: Path) -> float:
    probe = Path(FFMPEG).with_name("ffprobe.exe")
    out = subprocess.run([str(probe), "-v", "error", "-show_entries", "format=bit_rate",
                          "-of", "csv=p=0", str(path)], capture_output=True, text=True)
    return float(out.stdout.strip() or 0) / 1000.0


def main() -> None:
    ORIGINALS.mkdir(parents=True, exist_ok=True)
    # First run: move the tracks the game shipped with out of the game.
    for track in list(MUSIC.glob("*.mp3")) + list(MUSIC.glob("*.ogg")):
        kept = ORIGINALS / track.name
        if not kept.exists() and not any(ORIGINALS.glob(track.stem + ".*")):
            shutil.copy2(track, kept)
    for original in sorted(ORIGINALS.iterdir()):
        if original.suffix not in (".mp3", ".ogg"):
            continue
        name = original.stem
        target = MUSIC / f"{name}.ogg"
        if name not in TRIMS and bitrate_kbps(original) <= LOW_ENOUGH_KBPS:
            if original.suffix == ".ogg":
                shutil.copy2(original, target)
            print(f"{original.name}: kept as it is")
            continue
        command = [FFMPEG, "-v", "error", "-y", "-i", str(original), "-vn",
                   "-c:a", "libvorbis", "-q:a", QUALITY]
        if name in TRIMS:
            keep, fade = TRIMS[name]
            command += ["-t", str(keep), "-af", f"afade=t=out:st={keep - fade}:d={fade}"]
        subprocess.run(command + [str(target)], check=True)
        # The MP3 it replaces goes, with its import file.
        for old in (MUSIC / f"{name}.mp3", MUSIC / f"{name}.mp3.import"):
            if original.suffix == ".mp3" and old.exists():
                old.unlink()
        print(f"{original.name}: {original.stat().st_size // 1024} KB -> "
              f"{target.name} {target.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
