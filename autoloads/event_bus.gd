extends Node
## Global signal hub (autoload "EventBus"). Holds no state and no logic.
##
## Use it only when the emitter and the listener live in different scenes and
## neither owns the other (a coin and the HUD, a goal and GameManager).
## Parent/child communication uses the child's own signals instead.
## Signal names are past tense: they report something that already happened.

@warning_ignore_start("unused_signal")

## Emitted by LevelLoader once the map is built and every entity is spawned.
signal level_started(level_data: LevelData, collectibles_total: int)
## Emitted by a Collectible when the player picks it up.
signal collectible_collected(value: int)
## Emitted by GameManager whenever the level's collectible count changes.
signal collectibles_changed(collected: int, total: int)
## Emitted by Player when its health changes (including once on spawn).
signal player_health_changed(current: int, maximum: int)
## Emitted by Player when her moonlight (Moon Spark charges) changes.
signal player_moonlight_changed(current: int, maximum: int)
## Emitted by Player when it dies (health reached 0 or it fell out of the map).
signal player_died
## Emitted by Goal when the player reaches it.
signal level_completed
## Emitted by GameManager when the game is paused or resumed.
signal pause_toggled(is_paused: bool)
## Emitted by an NPC or cutscene to play a conversation from the chapter's
## dialogue script. The DialogueBox plays it.
signal dialogue_requested(dialogue_id: String)
## Emitted by the DialogueBox when a conversation opens and when it closes.
signal dialogue_started(dialogue_id: String)
signal dialogue_finished(dialogue_id: String)
## Emitted by a boss: when the fight starts, when its health changes, and
## when the fight ends (won or reset). The HUD shows a health bar meanwhile.
signal boss_started(boss_name: String, maximum: int)
signal boss_health_changed(current: int, maximum: int)
signal boss_finished

@warning_ignore_restore("unused_signal")
