extends CharacterBody2D

## Sentinel — The Predator. Sharp diamond shape.
## Ignores Time Stop (moves at 20%), appears ultra-fast in Time Slow.
## Attacks: Kinetic Stutter (dash-strike) and Linear Deletion (laser beam).

# --- Stats ---
@export var health: float = 50.0
@export var speed: float = 55.0
var is_dead: bool = false
var crit_resist: bool = false  # Set by Dampener's Data Shield
var damage_reduction: float = 0.0  # Set by Dampener's Data Shield

# --- Attack ---
enum SentinelState { CHASE, DASH_TELEGRAPH, DASHING, LASER_TELEGRAPH, LASER_FIRING, STUNNED }
var current_state: SentinelState = SentinelState.CHASE

const DASH_DAMAGE: float = 18.0
const DASH_SPEED: float = 300.0
const DASH_TELEGRAPH_TIME: float = 0.4
const DASH_DURATION: float = 0.3
const LASER_TELEGRAPH_TIME: float = 1.0
const LASER_DAMAGE_PER_TICK: float = 2.0
const LASER_TICK_RATE: float = 0.1
const LASER_DURATION: float = 1.5
const ATTACK_COOLDOWN: float = 2.5
const DASH_RANGE: float = 80.0

var _attack_timer: float = 0.0
var _state_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _laser_target_pos: Vector2 = Vector2.ZERO
var _laser_direction: Vector2 = Vector2.ZERO  # Locked direction when firing
var _laser_tick_timer: float = 0.0  # Cooldown between damage ticks

# --- Laser Visual ---
var _laser_line: Line2D = null

# --- Signals ---
signal enemy_died(enemy: Node2D)

func _ready() -> void:
	add_to_group("enemies")
	
	# Create laser line
	_laser_line = Line2D.new()
	_laser_line.width = 2.0
	_laser_line.default_color = Color(1, 0, 0, 0.3)
	_laser_line.z_index = 5
	_laser_line.visible = false
	add_child(_laser_line)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player or not is_instance_valid(player):
		return
	
	# --- Time Modifier: THE KEY MECHANIC ---
	var time_modifier: float = 1.0
	match TimeManager.current_state:
		TimeManager.TimeState.STOPPED:
			time_modifier = 0.2  # Still moves at 20%!
			modulate = Color(0.8, 0.15, 0.5)
		TimeManager.TimeState.SLOWED:
			time_modifier = 1.0 / Engine.time_scale  # Appears ultra-fast
			modulate = Color(1, 0.1, 0.4)
		TimeManager.TimeState.ERASED:
			time_modifier = 0.3
			modulate = Color(1, 0.2, 0.6, 0.5)
		_:
			modulate = Color(1, 0.2, 0.6)  # Neon magenta
	
	# --- State Machine ---
	match current_state:
		SentinelState.CHASE:
			_handle_chase(delta, player, time_modifier)
		SentinelState.DASH_TELEGRAPH:
			_handle_dash_telegraph(delta)
		SentinelState.DASHING:
			_handle_dashing(delta, player)
		SentinelState.LASER_TELEGRAPH:
			_handle_laser_telegraph(delta, player)
		SentinelState.LASER_FIRING:
			_handle_laser_firing(delta, player)
		SentinelState.STUNNED:
			_handle_stunned(delta)

func _handle_chase(delta: float, player: Node2D, modifier: float) -> void:
	var direction: Vector2 = (player.global_position - global_position).normalized()
	var distance: float = global_position.distance_to(player.global_position)
	
	velocity = direction * speed * modifier
	move_and_slide()
	
	_attack_timer += delta
	if _attack_timer >= ATTACK_COOLDOWN:
		_attack_timer = 0.0
		if distance < DASH_RANGE:
			_start_dash_telegraph(direction)
		else:
			_start_laser_telegraph(player)

# --- KINETIC STUTTER (Dash Attack) ---
func _start_dash_telegraph(direction: Vector2) -> void:
	current_state = SentinelState.DASH_TELEGRAPH
	_dash_direction = direction
	_state_timer = DASH_TELEGRAPH_TIME
	
	# Flash edges neon white as telegraph
	modulate = Color(1, 1, 1)

func _handle_dash_telegraph(delta: float) -> void:
	_state_timer -= delta
	velocity = Vector2.ZERO
	
	# Flicker between white and magenta
	modulate = Color(1, 1, 1) if fmod(_state_timer * 20.0, 2.0) > 1.0 else Color(1, 0, 0.5)
	
	if _state_timer <= 0.0:
		current_state = SentinelState.DASHING
		_state_timer = DASH_DURATION
		modulate = Color(1, 0, 0)
		GameJuice.screen_shake(3.0, 1.5)

func _handle_dashing(delta: float, player: Node2D) -> void:
	_state_timer -= delta
	velocity = _dash_direction * DASH_SPEED
	move_and_slide()
	
	# Check player collision during dash
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(DASH_DAMAGE)
				GameJuice.spawn_damage_number(DASH_DAMAGE, collider.global_position, false)
				GameJuice.screen_shake(5.0, 2.0)
	
	if _state_timer <= 0.0:
		current_state = SentinelState.STUNNED
		_state_timer = 0.5

# --- LINEAR DELETION (Laser) ---
func _start_laser_telegraph(player: Node2D) -> void:
	current_state = SentinelState.LASER_TELEGRAPH
	_state_timer = LASER_TELEGRAPH_TIME
	_laser_target_pos = player.global_position
	
	# Show targeting line
	_laser_line.visible = true
	_laser_line.default_color = Color(1, 0, 0, 0.3)
	_laser_line.width = 1.0

func _handle_laser_telegraph(delta: float, player: Node2D) -> void:
	_state_timer -= delta
	velocity = Vector2.ZERO
	
	# Targeting line tracks player during telegraph (gives warning)
	_laser_direction = (player.global_position - global_position).normalized()
	_laser_line.clear_points()
	_laser_line.add_point(Vector2.ZERO)
	_laser_line.add_point(_laser_direction * 200.0)  # Fixed length beam
	
	# Line gets brighter as it charges
	var charge: float = 1.0 - (_state_timer / LASER_TELEGRAPH_TIME)
	_laser_line.default_color = Color(1, 0, 0, 0.3 + charge * 0.5)
	_laser_line.width = 1.0 + charge * 2.0
	
	if _state_timer <= 0.0:
		# LOCK the direction — beam fires in this fixed direction
		_laser_direction = (player.global_position - global_position).normalized()
		_laser_tick_timer = 0.0
		current_state = SentinelState.LASER_FIRING
		_state_timer = LASER_DURATION
		_laser_line.default_color = Color(1, 0.3, 0.3, 1.0)
		_laser_line.width = 4.0

func _handle_laser_firing(delta: float, player: Node2D) -> void:
	_state_timer -= delta
	_laser_tick_timer -= delta
	velocity = Vector2.ZERO
	
	# Beam fires in LOCKED direction (doesn't track anymore — dodgeable!)
	var beam_end: Vector2 = _laser_direction * 200.0
	_laser_line.clear_points()
	_laser_line.add_point(Vector2.ZERO)
	_laser_line.add_point(beam_end)
	
	# Flicker the beam
	_laser_line.modulate.a = 0.7 + sin(_state_timer * 30.0) * 0.3
	
	# Damage with tick cooldown (not every frame!)
	if player and is_instance_valid(player) and _laser_tick_timer <= 0.0:
		var beam_end_world: Vector2 = global_position + beam_end
		var dist_to_beam: float = _point_to_line_distance(
			player.global_position, global_position, beam_end_world
		)
		if dist_to_beam < 6.0:  # Tighter hitbox — dodgeable
			if player.has_method("take_damage"):
				player.take_damage(LASER_DAMAGE_PER_TICK)
				GameJuice.spawn_damage_number(LASER_DAMAGE_PER_TICK, player.global_position, false)
				_laser_tick_timer = LASER_TICK_RATE  # Reset cooldown
	
	if _state_timer <= 0.0:
		_laser_line.visible = false
		current_state = SentinelState.STUNNED
		_state_timer = 0.8

func _handle_stunned(delta: float) -> void:
	_state_timer -= delta
	velocity = Vector2.ZERO
	modulate.a = 0.5 + sin(_state_timer * 12.0) * 0.3
	
	if _state_timer <= 0.0:
		modulate.a = 1.0
		current_state = SentinelState.CHASE

# --- Utility ---
func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_dir: Vector2 = line_end - line_start
	var line_len: float = line_dir.length()
	if line_len < 0.001:
		return point.distance_to(line_start)
	var t: float = clampf((point - line_start).dot(line_dir) / (line_len * line_len), 0.0, 1.0)
	var closest: Vector2 = line_start + line_dir * t
	return point.distance_to(closest)

func get_damage_reduction() -> float:
	return damage_reduction

func take_damage(amount: float = 10.0) -> void:
	if is_dead:
		return
	health -= amount
	
	modulate = Color.WHITE
	await get_tree().create_timer(0.05).timeout
	if not is_dead:
		modulate = Color(1, 0.2, 0.6)
	
	if health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	_laser_line.visible = false
	GameJuice.death_impact()
	GameJuice.spawn_death_particles(global_position, Color(1, 0.2, 0.6), 15)
	enemy_died.emit(self)
	queue_free()
