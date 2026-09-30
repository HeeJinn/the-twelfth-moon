extends PlayerState
## Moon Spark: she gathers moonlight in her hand and throws it (spends one
## moon). The spark flies straight ahead (moon_spark.gd).

## The spark leaves her hand on this frame of "cast", from here (feet,
## facing right).
const RELEASE_FRAME: int = 8
const SPARK_OFFSET: Vector2 = Vector2(18.0, -19.0)

var _released: bool = false


func enter(_previous: StringName) -> void:
	player.consume_spell()
	_released = false
	player.play_animation(&"cast")


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(0.0, 0.0, player.stats.friction, delta)
	if not _released and player.sprite.frame >= RELEASE_FRAME:
		_released = true
		if player.spend_moonlight() and player.spark_scene:
			player.launch(player.spark_scene, SPARK_OFFSET)


func get_transition() -> StringName:
	if not player.is_on_floor():
		return &"Fall"
	if player.finished_animation == &"cast":
		return settle()
	return &""
