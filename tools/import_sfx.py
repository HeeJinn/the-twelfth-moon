"""Sound effects from leohpaz's RPG Essentials SFX (free; credit "leohpaz").

Run from the project folder:
    python tools/import_sfx.py

Where it comes from: RPG_Essentials_Free/ next to the project (48 WAVs, 24-bit
stereo at 44.1 kHz). The effects the game plays are listed in EFFECTS below,
each under the short name the game asks for (`Audio.effect(&"swing")`).

Made here: assets/audio/sfx/<name>.wav, mono, 16-bit, 22.05 kHz, trimmed,
faded at the edges and levelled like the voices (tools/import_audio.py), so
the effects are about equally loud before Audio.EFFECT_DB shapes them.
The pack is never edited; this only reads it.
"""
import array
import struct
from pathlib import Path

from import_audio import PROJECT, fade_and_level, halve, trim, write_wav16

PACK = PROJECT.parent / "RPG_Essentials_Free"
OUT = PROJECT / "assets" / "audio" / "sfx"

# name -> file in the pack
EFFECTS = {
    # Mariane
    "swing": "12_Player_Movement_SFX/56_Attack_03.wav",
    "hit": "10_Battle_SFX/15_Impact_flesh_02.wav",
    "block": "10_Battle_SFX/39_Block_03.wav",
    "jump": "12_Player_Movement_SFX/30_Jump_03.wav",
    "land": "12_Player_Movement_SFX/45_Landing_01.wav",
    "climb": "12_Player_Movement_SFX/42_Cling_climb_03.wav",
    "dash": "8_Atk_Magic_SFX/25_Wind_01.wav",
    "hurt": "12_Player_Movement_SFX/61_Hit_03.wav",
    "charge": "8_Atk_Magic_SFX/45_Charge_05.wav",
    "moon_slash": "8_Buffs_Heals_SFX/16_Atk_buff_04.wav",
    "spark": "8_Atk_Magic_SFX/22_Water_02.wav",
    "heal": "8_Buffs_Heals_SFX/02_Heal_02.wav",
    "absorb": "8_Buffs_Heals_SFX/39_Absorb_04.wav",
    "revive": "8_Buffs_Heals_SFX/30_Revive_03.wav",
    "petal": "10_UI_Menu_SFX/070_Equip_10.wav",
    # Monsters and bosses
    "slash": "10_Battle_SFX/22_Slash_04.wav",
    "enemy_death": "10_Battle_SFX/69_Enemy_death_01.wav",
    "encounter": "10_Battle_SFX/55_Encounter_02.wav",
    "teleport": "12_Player_Movement_SFX/88_Teleport_02.wav",
    # Warned hazards (FrostSpikes.burst_sound)
    "fire": "8_Atk_Magic_SFX/04_Fire_explosion_04_medium.wav",
    "thunder": "8_Atk_Magic_SFX/18_Thunder_02.wav",
    "ice": "8_Atk_Magic_SFX/13_Ice_explosion_01.wav",
    "earth": "8_Atk_Magic_SFX/30_Earth_02.wav",
    "poison": "8_Atk_Magic_SFX/46_Poison_01.wav",
    "bite": "10_Battle_SFX/08_Bite_04.wav",
    "claw": "10_Battle_SFX/03_Claw_03.wav",
    # Menus
    "ui_hover": "10_UI_Menu_SFX/001_Hover_01.wav",
    "ui_confirm": "10_UI_Menu_SFX/013_Confirm_03.wav",
    "pause": "10_UI_Menu_SFX/092_Pause_04.wav",
    "unpause": "10_UI_Menu_SFX/098_Unpause_04.wav",
}


def read_wav_any(data: bytes) -> tuple[list[float], int]:
    """Mono float samples of a PCM WAV, 16 or 24 bit (the pack is 24-bit)."""
    pos, fmt, pcm = 12, None, b""
    while pos + 8 <= len(data):
        chunk_id = data[pos:pos + 4]
        size = struct.unpack("<I", data[pos + 4:pos + 8])[0]
        if chunk_id == b"fmt ":
            fmt = struct.unpack("<HHIIHH", data[pos + 8:pos + 24])
        elif chunk_id == b"data":
            pcm = data[pos + 8:pos + 8 + size]
        pos += 8 + size + (size & 1)
    tag, channels, rate, _, _, bits = fmt
    if bits == 24:
        count = len(pcm) // 3
        samples = []
        for i in range(count):
            value = int.from_bytes(pcm[i * 3:i * 3 + 3], "little", signed=True)
            samples.append(value / 8388608.0)
    elif bits == 16:
        raw = array.array("h")
        raw.frombytes(pcm[:len(pcm) // 2 * 2])
        samples = [v / 32768.0 for v in raw]
    else:
        raise ValueError(f"unsupported WAV: tag={tag} bits={bits}")
    if channels > 1:
        samples = [sum(samples[i:i + channels]) / channels
                   for i in range(0, len(samples) - channels + 1, channels)]
    return samples, rate


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for name, source in EFFECTS.items():
        samples, rate = read_wav_any((PACK / source).read_bytes())
        samples = trim(samples, rate)
        if rate >= 44100:
            samples, rate = halve(samples), rate // 2
        samples = fade_and_level(samples, rate)
        target = OUT / f"{name}.wav"
        write_wav16(target, samples, rate)
        total += target.stat().st_size
    print(f"assets/audio/sfx: {len(EFFECTS)} effects, {total / 1024:.0f} KB")


if __name__ == "__main__":
    main()
