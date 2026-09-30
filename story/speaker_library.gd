class_name SpeakerLibrary
extends Resource
## Every Speaker the dialogue box knows, looked up by name.
## Names not listed here still work: they show without a portrait.

@export var speakers: Array[Speaker] = []


func find(speaker_name: String) -> Speaker:
	for speaker: Speaker in speakers:
		if speaker.display_name.to_lower() == speaker_name.to_lower():
			return speaker
	return null
