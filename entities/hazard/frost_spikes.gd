class_name FrostSpikes
extends Node2D
## Ice that bursts up out of the ground. It always warns first: a little
## frost gathers (the "warn" animation) before the pillar bursts up, hurts
## for a moment, and sinks again. In the ice cave they repeat on a rhythm;
## the Shield Knight's ground strike raises a row of single ones.
##
## Scene: FrostSpikes (Node2D, origin at the ground)
##   %Sprite   AnimatedSprite2D: warn, burst, sink (48x32 frames)
##   %Hitbox   ShapeCast2D over the pillar, mask 4 (player), enabled off

## Repeat forever (a cave hazard) or burst once and free itself.
@export var repeating: bool = true
## Seconds the ground stays calm between bursts.
@export var calm_time: float = 1.6
## Seconds before the first warning, to stagger a row of them.
@export var start_delay: float = 0.0
@export var damage: int = 1
## The effect heard as it strikes (a name in assets/audio/sfx/), if any.
@export var burst_sound: StringName = &""

var _hurting: bool = false

@onready var _sprite: AnimatedSprite2D = %Sprite
@onready var _hitbox: ShapeCast2D = %Hitbox


func _ready() -> void:
	_sprite.hide()
	_sprite.animation_finished.connect(_on_animation_finished)
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	_warn()


func _physics_process(_delta: float) -> void:
	if not _hurting:
		return
	_hitbox.force_shapecast_update()
	for i: int in _hitbox.get_collision_count():
		var player: Player = _hitbox.get_collider(i) as Player
		if player != null and not player.is_dead():
			player.take_damage(damage, global_position)


func _warn() -> void:
	_sprite.show()
	_sprite.play(&"warn")


func _on_animation_finished() -> void:
	match _sprite.animation:
		&"warn":
			_hurting = true
			_sprite.play(&"burst")
			if not burst_sound.is_empty():
				Audio.effect_at(burst_sound, global_position)
		&"burst":
			_hurting = false
			_sprite.play(&"sink")
		&"sink":
			_sprite.hide()
			if not repeating:
				queue_free()
				return
			await get_tree().create_timer(calm_time).timeout
			if is_inside_tree():
				_warn()
