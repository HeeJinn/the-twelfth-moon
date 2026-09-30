class_name Damageable
extends CharacterBody2D
## Anything Mariane's sword can hit: monsters and bosses. They sit on the
## "enemies" physics layer and override take_hit().


## Called by the player's sword. `source_position` is where the blow came from.
func take_hit(_amount: int, _source_position: Vector2) -> void:
	pass


## Called by moonlight (the Moon Slash, its wave, the Moon Spark). Shields
## can't stop it; by default it is just a hit.
func take_moon_hit(amount: int, source_position: Vector2) -> void:
	take_hit(amount, source_position)


## True when a sword blow from `source_position` would land on a raised
## shield (so the sword shows a guard spark instead of a hit spark).
func is_guarding_against(_source_position: Vector2) -> bool:
	return false
