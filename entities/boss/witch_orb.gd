class_name WitchOrb
extends Area2D
## The Moon Witch's floating magic orb. Drifts toward Mariane at head
## height; crouching, sliding, dashing or jumping gets her past it.
##
## Scene: WitchOrb (Area2D, layer 32 hazards, mask 4 player)
##   Glow (Sprite2D, additive), Sprite2D, CollisionShape2D

const LIFETIME: float = 5.0
const WOBBLE_HEIGHT: float = 3.0

var direction: float = 1.0
var speed: float = 80.0

var _age: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	position.x += direction * speed * delta
	position.y = _base_y + sin(_age * 6.0) * WOBBLE_HEIGHT
	if _age >= LIFETIME:
		_vanish()


func _on_body_entered(body: Node2D) -> void:
	var player: Player = body as Player
	if player == null or player.is_invulnerable():
		return
	player.take_damage(1, global_position)
	_vanish()


func _vanish() -> void:
	set_physics_process(false)
	set_deferred("monitoring", false)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
