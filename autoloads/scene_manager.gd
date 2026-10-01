extends CanvasLayer
## Changes scenes behind a fade to black (autoload "SceneManager").
##
## Usage: SceneManager.change_scene("res://levels/level.tscn")
## It builds its own ColorRect, so no .tscn is needed. It sits on layer 100
## so it covers the HUD, and keeps running while the tree is paused.
## fade_out() / fade_in() are also public so a level can hide a respawn.

const FADE_DURATION: float = 0.3

var _is_transitioning: bool = false
var _fade_rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade_rect)


func is_transitioning() -> bool:
	return _is_transitioning


## Fades out, swaps the current scene, then fades back in. `color` is the
## colour faded through (black unless a scene needs, say, white).
## Calls made while a transition is running are ignored.
func change_scene(path: String, color: Color = Color.BLACK) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_fade_rect.color = color
	# Swallow clicks while the screen is black.
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)

	var error: Error = get_tree().change_scene_to_file(path)
	if error == OK:
		await get_tree().scene_changed
	else:
		push_error("SceneManager: cannot load '%s' (%s)." % [path, error_string(error)])

	await _fade_to(0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false


## Fades the screen to black without changing scene.
func fade_out() -> void:
	_fade_rect.color = Color.BLACK
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)


## Fades back in after fade_out().
func fade_in() -> void:
	await _fade_to(0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _fade_to(alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", alpha, FADE_DURATION)
	await tween.finished
