class_name DialogueScript
extends RefCounted
## Reads a chapter's dialogue file into conversations.
##
## File format (plain text, easy to edit):
##   # A line starting with "#" is a note and is ignored.
##   [wake_up]                      <- starts the conversation "wake_up"
##   Tomas: Mariane, wake up!       <- "Name: text" is a spoken line
##   The wind carries petals.       <- a line with no name is narration
## A conversation named "<id>_again" (e.g. "rosa_again") is used when the
## player talks to the same person a second time.


## One spoken or narrated line.
class Line:
	var speaker_name: String = ""
	var text: String = ""

	func _init(line_speaker: String, line_text: String) -> void:
		speaker_name = line_speaker
		text = line_text


var _conversations: Dictionary[String, Array] = {}


static func load_file(path: String) -> DialogueScript:
	var script: DialogueScript = DialogueScript.new()
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read dialogue '%s'. In an exported build, add *.txt to the "
				% path + "export preset's non-resource filter.")
		return script
	script._parse(text)
	return script


func has(dialogue_id: String) -> bool:
	return _conversations.has(dialogue_id)


func get_lines(dialogue_id: String) -> Array[Line]:
	var lines: Array[Line] = []
	if _conversations.has(dialogue_id):
		for line: Line in _conversations[dialogue_id]:
			lines.append(line)
	return lines


func _parse(text: String) -> void:
	var current: String = ""
	for raw_line: String in text.replace("\r", "").split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			current = line.substr(1, line.length() - 2).strip_edges()
			_conversations[current] = []
			continue
		if current.is_empty():
			push_warning("Dialogue line outside any [section]: %s" % line)
			continue
		var speaker_name: String = ""
		var colon: int = line.find(":")
		# A short word before the colon is a speaker name; otherwise the colon
		# is part of the narration.
		if colon > 0 and colon <= 16 and not line.substr(0, colon).contains(" "):
			speaker_name = line.substr(0, colon).strip_edges()
			line = line.substr(colon + 1).strip_edges()
		_conversations[current].append(Line.new(speaker_name, line))
