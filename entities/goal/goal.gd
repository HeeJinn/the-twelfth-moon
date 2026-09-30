class_name Goal
extends Area2D
## Ends the chapter when the player touches it. GameManager decides what
## comes next (next chapter or the end screen).
##
## Scene: Goal (Area2D, origin at cell bottom; layer 64, mask 4)
##   Sprite2D (the shrine)
##   CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var player: Player = body as Player
	if player == null or player.is_dead():
		return
	set_deferred("monitoring", false)
	EventBus.level_completed.emit()
