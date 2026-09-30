class_name PlayerStats
extends Resource
## Movement, combat and health tuning for Mariane (save as player_stats.tres).
##
## Jumps are authored as a height and two durations; the velocity and the two
## gravities are derived from them (GDC 2016, "Building a Better Jump").
## Defaults suit 32 px tiles, a 480x270 viewport and a ~30 px tall hero, and
## lean forgiving because the player rarely plays games.

@export_group("Run")
## Top horizontal speed in px/s (about 3.4 tiles/s).
@export var max_speed: float = 110.0
## Ground acceleration in px/s^2.
@export var acceleration: float = 1000.0
## Ground deceleration when there is no input.
@export var friction: float = 1400.0
@export var air_acceleration: float = 700.0
@export var air_friction: float = 350.0
## Speed of a scripted walk in story scenes (plays the walk cycle).
@export var walk_speed: float = 48.0
## Seconds standing still before she relaxes into her calm stance.
@export var calm_delay: float = 3.0

@export_group("Jump")
## Peak height of a full (held) jump in px. 80 = 2.5 tiles, so she clears
## two-tile steps with room to spare.
@export var jump_height: float = 80.0
## Seconds from takeoff to the peak.
@export var time_to_peak: float = 0.38
## Seconds from the peak back down to takeoff height.
@export var time_to_land: float = 0.3
## When jump is released while rising, upward speed is capped to this
## fraction of jump_velocity.
@export_range(0.1, 1.0) var jump_cut: float = 0.55
@export var max_fall_speed: float = 420.0
## Grace period to still jump after walking off a ledge.
@export var coyote_time: float = 0.12
## A jump pressed this long before landing still fires on landing.
@export var jump_buffer_time: float = 0.15

@export_group("Attack")
@export var attack_damage: int = 1
## The third slash of the ground combo hits harder.
@export var finisher_damage: int = 2
## An attack pressed this long before it is allowed still fires.
@export var attack_buffer_time: float = 0.15
## Odds that a sword swing comes with a small effort grunt (she also waits a
## couple of seconds between grunts, so it's never every swing).
@export_range(0.0, 1.0) var swing_grunt_chance: float = 0.3
## The lunging slash out of a dash hits harder and reaches further.
@export var dash_attack_damage: int = 2
@export var dash_attack_speed: float = 200.0

@export_group("Moon Slash")
## Keep attack held after a swing to charge. Seconds until the sword is full
## of moonlight; letting go earlier just lowers it again.
@export var charge_time: float = 0.55
## The slash itself, up close.
@export var moon_slash_damage: int = 3
## The crescent of light that flies on from it.
@export var moon_wave_damage: int = 2
@export var moon_wave_speed: float = 220.0
@export var moon_wave_range: float = 150.0

@export_group("Moon Spark")
## Moonlight: the moons beside her hearts. Each Moon Spark spends one;
## campfires refill them all and they slowly come back on their own.
@export var max_moonlight: int = 3
## Seconds for one spent moon to come back.
@export var moonlight_regen_time: float = 6.0
@export var spark_damage: int = 2
@export var spark_speed: float = 190.0
@export var spark_range: float = 220.0

@export_group("Guard")
## Hold block to raise the sword. Blows from the front do no harm.
## She is pushed back this fast by a blocked blow.
@export var block_push: float = 90.0
## Seconds after a block before she can be pushed again by the same attack.
@export var block_cooldown: float = 0.25

@export_group("Slide")
## Hold down while running (or press a direction while crouched) to slide.
@export var slide_speed: float = 230.0
## A slide never slows below this, so she always clears a low tunnel.
@export var slide_min_speed: float = 80.0
@export var slide_friction: float = 380.0
@export var slide_time: float = 0.45
## She must be running at least this fast for down to start a slide.
@export var slide_trigger_speed: float = 60.0

@export_group("Dash")
## A quick burst forward, on the ground or once in the air. She can't be
## hurt while dashing or sliding.
@export var dash_speed: float = 290.0
@export var dash_time: float = 0.17
@export var dash_cooldown: float = 0.35
@export var dash_buffer_time: float = 0.1

@export_group("Walls and ledges")
## Top speed while sliding down a wall.
@export var wall_slide_speed: float = 70.0
## Sideways push of a jump off a wall.
@export var wall_jump_push: float = 170.0
## Seconds after a wall jump before steering works again, so she clears
## the wall.
@export var wall_jump_lock: float = 0.16
## Seconds after letting go of a ledge before she can grab one again.
@export var ledge_regrab_delay: float = 0.3

@export_group("Climbing")
@export var climb_speed: float = 75.0

@export_group("Health")
@export var max_health: int = 5
## Seconds the player has no control after being hit.
@export var hurt_duration: float = 0.3
@export var invulnerability_time: float = 1.2
## Knockback velocity; x is applied away from the damage source.
@export var knockback: Vector2 = Vector2(140.0, -180.0)

## Initial upward speed of a full jump (px/s, positive number).
var jump_velocity: float:
	get:
		return 2.0 * jump_height / time_to_peak

## Gravity while moving up.
var jump_gravity: float:
	get:
		return 2.0 * jump_height / (time_to_peak * time_to_peak)

## Gravity while moving down.
var fall_gravity: float:
	get:
		return 2.0 * jump_height / (time_to_land * time_to_land)
