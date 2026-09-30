extends Node
## Loads every GDScript and every scene in the project, so a script that no
## test happens to reach (a rarely-used state, a tool) still gets compiled
## under the project's strict warnings (untyped declarations are errors) and
## every scene's references still resolve. Runs as a scene, not with
## --script, so the autoloads (EventBus, GameManager...) exist.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/scripts_test.tscn

const SKIP_FOLDERS: Array[String] = ["res://.godot", "res://addons"]

var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_check_folder("res://")
	print("checked %d scripts and scenes" % _checked)
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


func _check_folder(path: String) -> void:
	if path.trim_suffix("/") in SKIP_FOLDERS:
		return
	for file: String in DirAccess.get_files_at(path):
		var full: String = path.path_join(file)
		if file.ends_with(".gd") or file.ends_with(".tscn") or file.ends_with(".tres"):
			_check_file(full)
	for folder: String in DirAccess.get_directories_at(path):
		_check_folder(path.path_join(folder))


func _check_file(path: String) -> void:
	_checked += 1
	var resource: Resource = load(path)
	if resource == null:
		_failures += 1
		print("FAIL could not load ", path)
		return
	if resource is GDScript:
		var script: GDScript = resource
		if not script.can_instantiate():
			_failures += 1
			print("FAIL script does not compile: ", path)
