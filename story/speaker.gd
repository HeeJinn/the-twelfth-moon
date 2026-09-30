class_name Speaker
extends Resource
## Someone who talks in the dialogue box: the name used in the dialogue
## script files, a small face portrait and the colour of their name.

## Must match the name before the colon in the dialogue script ("Tomas: Hi").
@export var display_name: String = ""
## Shown in the name box instead of display_name when set, e.g. "???" for a
## voice the player doesn't know yet.
@export var shown_as: String = ""
## About 20x20 px; the dialogue box draws it at 2x.
@export var portrait: Texture2D
@export var name_color: Color = Color(1.0, 0.84, 0.9)
## Whose voice they have (a bank in assets/audio/voice/: karen, alex, sean, ian,
## mariane), matched to the speaker's sex. Empty means no voice.
@export var voice_bank: StringName = &""
## Says a short hello when a conversation opens with them (and sometimes a
## goodbye when it closes): villagers do, bosses and memories don't.
@export var greets: bool = false
