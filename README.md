# The Twelfth Moon

A 2D pixel-art side-scrolling action platformer made with Godot 4.7.2, built as a birthday gift.
All five chapters are playable: the village, the Lantern Forest, the Long Road, Ember Keep (with the undercroft beneath it) and the Twelfth Night on its roof, with story scenes, four past-life memories, three mini-bosses, Kael's fight and the reveal, then the ending, the rolling credits and the after-credits scene. Voices, footsteps, sound effects and music throughout.

**This repository is private on purpose.** It holds third-party art and audio, and several of those packs forbid redistributing their files outside a game. Do not make it public as is. Credits are at the bottom.

## Run it
Open this folder in **Godot 4.7.2** (Compatibility renderer) and press Play. The main scene is `res://ui/title_screen/title_screen.tscn`.

| | |
|---|---|
| Move | A/D or arrow keys |
| Jump | Space / W / Up / Z / K (hold to jump higher) |
| Attack | J / X / left click (keep pressing for a combo; hold after a swing for a Moon Slash) |
| Block | hold I / C / right click |
| Moon Spark | U / V |
| Interact | E / Enter |
| Pause | Esc / P |
| Mute | M |

On a phone or tablet, on-screen buttons appear (a direction pad, and jump, sword, shield, moon spark, dash, talk and pause).

## Tests
Headless, one at a time (run from this folder; use the `_console` build of Godot on Windows):

```
godot --headless --path . res://tools/tests/<name>.tscn
```

`flow_test`, `chapter_test`, `moves_test`, `enemies_test`, `chapter2_test`, `chapter3_test`, `chapter4_test`, `chapter5_test`, `scripts_test`, `story_flow_test`, `critter_test`, `audio_test`, `touch_test`, `music_test`, `sfx_test`, `ending_test`, `journal_test`. Each prints PASS/FAIL lines and a `RESULT` line, and exits non-zero on failure. Don't run two Godot processes on the project at once.

## Layout
- `levels/` ASCII-map chapters built into tile maps at runtime, backgrounds, tilesets
- `entities/` the player (a node state machine), enemies, bosses, NPCs, critters, effects, props
- `story/` dialogue scripts (plain text), cutscenes, memory scenes, the ending and after-credits scene
- `ui/` HUD, dialogue box, title screen, credits (`ui/credits/credits.txt`) and end screen
- `autoloads/` `EventBus`, `GameManager`, `SceneManager`, `Audio`, `Music`
- `tools/` the importers that copy and recolour art from the asset packs (`import_*.py`, Python with Pillow), the resource builder (`build_resources.gd`) and the tests

The importers expect the asset packs next to this folder, as in the original workspace.

## Credits
The game's own credits screen is `ui/credits/credits.txt`; this is a summary.
- Mariane: Characters Pack by Dreamir. Kael: Fire Knight (Elementals) by chierit. Monsters Creatures Fantasy by Luiz Melo (CC0).
- Magic Pack 9 by Ansimuz; Pixel Valley (Forest and Cave, Revamped) by kauzz; Crawling Depths by pingupollas; Pixel2DCastle by Szadi art; the 16x16 Fantasy Platformer Pack, the Knight, the Necromancer and the Skeleton Sprite Pack (authors to be confirmed).
- Village tiles, props and characters by GandalfHardcore. Skies and backgrounds by CraftPix.net.
- Super Pixel Effects Gigapack by Will Tice / unTied Games. Heal sparkles from Pixel art effects by Sentient Dream Studio.
- Sky art: Free DEMO Pixel Skies by Digital Moons (https://digitalmoons.itch.io/pixel-skies); Starry Night package (author to be confirmed).
- Voices: Super Dialogue Audio Pack v1 by Dillon Becker (https://dillonbecker.com), CC BY 4.0. Voice actors: Alex Brodie, Karen Cenon, Ian Lampert, Meghan Christian, Sean Lenhart. Changes made: clips trimmed, level-matched, resampled and made mono. Footsteps: FreeSteps (author and licence to be confirmed).
- Pixelmax font. Health & Stamina bar art (author to be confirmed).
- Phone buttons: Complete UI Essential Pack by Crusenho (CC BY 4.0, https://creativecommons.org/licenses/by/4.0/); buttons recomposed with drawn icons.
- Sound effects: RPG Essentials SFX by leohpaz.
- Music: seventeen tracks from OpenGameArt.org, each credited in `assets/music/CREDITS.txt` and on the credits screen.
