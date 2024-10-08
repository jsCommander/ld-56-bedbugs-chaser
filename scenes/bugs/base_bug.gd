extends CharacterBody2D

class_name BaseBug

const footsteps_texture := preload("res://assets/images/trails.png")

const trail_scene := preload("res://scenes/trail/trail.tscn")
const fire_scene := preload("res://scenes/fire/fire.tscn")
const death_sound := preload("res://assets/sfx/explosion.wav")
const burn_texture := preload("res://assets/images/burn_enemy.png")

@export var speed := 400
@export var walk_speed := 300
@export var run_away_distance := 450
@export var run_away_safe_distance := 1000
@export var super_power_cooldown := 3
@export var trails_cooldown := 0.2
@export var trails_life_time := 120
@export var max_distance_from_player := 2000
@export var random_direction_change_time := 2

@onready var sprite := %Sprite

var death_sound_player: AudioStreamPlayer

enum State {
	IDLE,
	WALK,
	RUN_AWAY,
	DEAD
}
var current_state: State = State.WALK
var run_away_time: float = 0.0
var is_first_super_power: bool = true
var target_direction: Vector2 = Vector2.ZERO

var super_power_timer: Timer
var trails_timer: Timer
var random_direction_change_timer: Timer

func _ready():
	death_sound_player = AudioStreamPlayer.new()
	death_sound_player.stream = death_sound
	add_child(death_sound_player)

	super_power_timer = Timer.new()
	add_child(super_power_timer)
	super_power_timer.wait_time = super_power_cooldown
	super_power_timer.timeout.connect(_on_super_power_timer_timeout)

	trails_timer = Timer.new()
	add_child(trails_timer)
	trails_timer.wait_time = trails_cooldown
	trails_timer.timeout.connect(_on_trails_timer_timeout)

	random_direction_change_timer = Timer.new()
	add_child(random_direction_change_timer)
	random_direction_change_timer.wait_time = random_direction_change_time
	random_direction_change_timer.timeout.connect(_on_random_direction_change_timer_timeout)

	_set_walk_state()

func _physics_process(delta: float) -> void:
	_update_common_state(delta)
	_process_common_logic(delta)

func use_super_power():
	pass

func process_additional_logic(_delta: float):
	pass

func update_additional_state(_delta: float):
	pass

func die():
	current_state = State.DEAD
	sprite.texture = burn_texture
	death_sound_player.play()
	await death_sound_player.finished

	var fire: Fire = fire_scene.instantiate()
	fire.position = global_position
	GameManager.spawn_scene(fire)

	queue_free()

func is_dead() -> bool:
	return current_state == State.DEAD

func is_running_away() -> bool:
	return current_state == State.RUN_AWAY

func _update_common_state(_delta: float):
	if current_state == State.DEAD:
		return

	if current_state == State.RUN_AWAY and _is_safe_distance_from_player():
		_set_walk_state()

	if current_state == State.WALK and _is_near_player():
		_set_run_away_state()
		
	if current_state == State.RUN_AWAY:
		run_away_time += _delta

	update_additional_state(_delta)

func _process_common_logic(delta: float):
	if current_state == State.DEAD:
		return

	if current_state == State.IDLE:
		velocity = Vector2.ZERO

	if current_state == State.WALK:
		velocity = target_direction * walk_speed
		
	if current_state == State.RUN_AWAY:
		run_away_time += delta
		velocity = _get_direction_away_from_player() * speed

	process_additional_logic(delta)
	
	_update_sprite_direction()
	move_and_slide()

func _set_walk_state():
	current_state = State.WALK
	target_direction = Globals.get_random_direction()
	trails_timer.start()
	super_power_timer.stop()
	random_direction_change_timer.start()

func _set_run_away_state():
	current_state = State.RUN_AWAY
	trails_timer.start()
	super_power_timer.start()
	random_direction_change_timer.stop()

func _is_safe_distance_from_player() -> bool:
	var player_position := GameManager.get_player_position()
	return global_position.distance_to(player_position) > run_away_safe_distance

func _is_near_player() -> bool:
	var player_position := GameManager.get_player_position()
	return global_position.distance_to(player_position) < run_away_distance

func _get_direction_away_from_player() -> Vector2:
	var player_position := GameManager.get_player_position()
	return (global_position - player_position).normalized()

func _get_direction_to_player() -> Vector2:
	var player_position := GameManager.get_player_position()
	return (player_position - global_position).normalized()

func _spawn_trail():
	var trail = trail_scene.instantiate()
	trail.texture = footsteps_texture
	trail.max_life_time = trails_life_time
	trail.opacity_multiplier = 1
	trail.global_position = global_position
	trail.rotation = velocity.angle()
	GameManager.spawn_scene(trail)

func _on_trails_timer_timeout() -> void:
	if current_state == State.RUN_AWAY or current_state == State.WALK:
		_spawn_trail()

func _update_sprite_direction():
	if velocity.x > 0:
		sprite.flip_h = true
	elif velocity.x < 0:
		sprite.flip_h = false

func _on_super_power_timer_timeout():
	if is_dead() or !is_running_away():
		return

	use_super_power()

func is_far_from_player() -> bool:
	var player_position := GameManager.get_player_position()
	return global_position.distance_to(player_position) > max_distance_from_player

func _on_random_direction_change_timer_timeout():
	if is_far_from_player():
		target_direction = _get_direction_to_player()
	else:
		target_direction = Globals.get_random_direction()
