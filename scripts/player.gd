extends CharacterBody2D

## Sequence-0 — The Player Controller
## Handles movement, shooting, time abilities, phase dash, and crit system.

# --- Stats ---
const SPEED: float = 120.0
var health: float = 100.0
var max_health: float = 100.0
var is_dead: bool = false

# --- Crit System ---
const CRIT_CHANCE: float = 0.2
const CRIT_MULTIPLIER: float = 2.5
const BASE_DAMAGE_MIN: float = 10.0
const BASE_DAMAGE_MAX: float = 15.0

# --- Shooting ---
const SHOOT_COOLDOWN: float = 0.25
var can_shoot: bool = true
var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet.tscn")

# --- Phase Dash ---
const DASH_SPEED: float = 600.0
const DASH_DURATION: float = 0.2
const DASH_COOLDOWN: float = 0.6
const DASH_TIMESTOP_MULTIPLIER: float = 3.0
const GHOST_SPAWN_INTERVAL: float = 0.025
var is_dashing: bool = false
var can_dash: bool = true

# --- Time Ability State ---
var _active_ability: TimeManager.TimeState = TimeManager.TimeState.NORMAL

# --- Signals ---
signal player_damaged(new_health: float)
signal player_died()
signal player_low_hp(is_low: bool)  # For chromatic warning below 25%

func _ready() -> void:
	add_to_group("player")
	_setup_crosshair_cursor()

func _process(delta: float) -> void:
	if is_dead:
		return
	
	_handle_time_abilities()
	_handle_shooting()
	_handle_dash()

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	
	# During dash: just move with dash velocity, skip input
	if is_dashing:
		move_and_slide()
		return
	
	# --- Normal Movement ---
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Compensate speed when time is slowed so player moves at normal speed
	var current_speed: float = SPEED
	if TimeManager.current_state == TimeManager.TimeState.SLOWED:
		current_speed = SPEED / 0.2
	
	if input_dir != Vector2.ZERO:
		velocity = input_dir.normalized() * current_speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, current_speed)
	
	move_and_slide()

# =========================
# PHASE DASH
# =========================
func _handle_dash() -> void:
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		_perform_dash()

func _perform_dash() -> void:
	var move_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_dir == Vector2.ZERO:
		# Dash toward mouse if not moving
		move_dir = (get_global_mouse_position() - global_position).normalized()
	else:
		move_dir = move_dir.normalized()
	
	is_dashing = true
	can_dash = false
	
	# I-frames: become invincible
	set_collision_layer_value(2, false)
	set_collision_mask_value(3, false)
	modulate = Color(0.3, 0.6, 1.0, 0.5)
	
	# Time Stop synergy: dash is 3x faster/longer
	var dash_speed: float = DASH_SPEED
	var dash_time: float = DASH_DURATION
	if TimeManager.current_state == TimeManager.TimeState.STOPPED:
		dash_speed *= DASH_TIMESTOP_MULTIPLIER
		dash_time *= DASH_TIMESTOP_MULTIPLIER
	
	velocity = move_dir * dash_speed
	
	GameJuice.screen_shake(2.5, 1.3)
	
	# Ghost trail
	_spawn_ghost_trail(dash_time)
	
	# Dash duration
	await get_tree().create_timer(dash_time).timeout
	
	# End dash
	is_dashing = false
	velocity = move_dir * SPEED * 0.5  # Slight momentum after dash
	
	# Restore collision
	if _active_ability != TimeManager.TimeState.ERASED:
		set_collision_layer_value(2, true)
		set_collision_mask_value(3, true)
	
	# Restore color based on current ability
	_update_modulate()
	
	# Dash cooldown
	await get_tree().create_timer(DASH_COOLDOWN).timeout
	can_dash = true

func _spawn_ghost_trail(duration: float) -> void:
	var elapsed: float = 0.0
	while elapsed < duration and is_dashing:
		# Create a ghost polygon at current position
		var ghost := ColorRect.new()
		ghost.size = Vector2(16, 16)
		ghost.position = global_position - Vector2(8, 8)
		ghost.color = Color(0.3, 0.5, 1.0, 0.6)
		ghost.z_index = -1
		get_parent().add_child(ghost)
		
		# Fade and shrink the ghost
		var tween := ghost.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
		tween.tween_property(ghost, "scale", Vector2(0.3, 0.3), 0.3)
		tween.chain().tween_callback(ghost.queue_free)
		
		await get_tree().create_timer(GHOST_SPAWN_INTERVAL).timeout
		elapsed += GHOST_SPAWN_INTERVAL

# =========================
# CRIT SYSTEM
# =========================
func deal_damage() -> Array:
	var base_damage: float = randf_range(BASE_DAMAGE_MIN, BASE_DAMAGE_MAX)
	var is_crit: bool = randf() < CRIT_CHANCE
	var final_damage: float = base_damage * (CRIT_MULTIPLIER if is_crit else 1.0)
	return [final_damage, is_crit]

# =========================
# TIME ABILITIES
# =========================
func _handle_time_abilities() -> void:
	# TIME STOP — Hold Space
	if Input.is_action_just_pressed("time_stop") and TimeManager.can_use_ability():
		_active_ability = TimeManager.TimeState.STOPPED
		TimeManager.change_time_state(TimeManager.TimeState.STOPPED)
		GameJuice.time_stop_impact()
		_update_modulate()
	elif Input.is_action_just_released("time_stop") and _active_ability == TimeManager.TimeState.STOPPED:
		_return_to_normal()
	
	# TIME SLOW — Hold Shift
	if Input.is_action_just_pressed("time_slow") and TimeManager.can_use_ability():
		_active_ability = TimeManager.TimeState.SLOWED
		TimeManager.change_time_state(TimeManager.TimeState.SLOWED)
		_update_modulate()
	elif Input.is_action_just_released("time_slow") and _active_ability == TimeManager.TimeState.SLOWED:
		_return_to_normal()
	
	# TIME ERASE — Hold E
	if Input.is_action_just_pressed("time_erase") and TimeManager.can_use_ability():
		_active_ability = TimeManager.TimeState.ERASED
		TimeManager.change_time_state(TimeManager.TimeState.ERASED)
		set_collision_mask_value(3, false)
		set_collision_layer_value(2, false)
		_update_modulate()
	elif Input.is_action_just_released("time_erase") and _active_ability == TimeManager.TimeState.ERASED:
		set_collision_mask_value(3, true)
		set_collision_layer_value(2, true)
		_return_to_normal()
	
	# Auto-return when gauge depletes
	if TimeManager.time_gauge <= 0.0 and _active_ability != TimeManager.TimeState.NORMAL:
		if _active_ability == TimeManager.TimeState.ERASED:
			set_collision_mask_value(3, true)
			set_collision_layer_value(2, true)
		_active_ability = TimeManager.TimeState.NORMAL
		_update_modulate()

func _return_to_normal() -> void:
	_active_ability = TimeManager.TimeState.NORMAL
	TimeManager.change_time_state(TimeManager.TimeState.NORMAL)
	_update_modulate()

func _update_modulate() -> void:
	if is_dashing:
		modulate = Color(0.3, 0.6, 1.0, 0.5)
		return
	match _active_ability:
		TimeManager.TimeState.NORMAL:
			modulate = Color(0.3, 0.5, 1.0)  # Neon blue
		TimeManager.TimeState.STOPPED:
			modulate = Color(0, 1, 1)  # Cyan
		TimeManager.TimeState.SLOWED:
			modulate = Color(1, 0.85, 0.3)  # Gold
		TimeManager.TimeState.ERASED:
			modulate = Color(0.5, 0.5, 1.0, 0.3)  # Ghost blue

# =========================
# SHOOTING
# =========================
func _handle_shooting() -> void:
	if Input.is_action_just_pressed("shoot") and can_shoot:
		_shoot()

func _shoot() -> void:
	can_shoot = false
	
	var bullet := bullet_scene.instantiate()
	bullet.global_position = global_position
	
	var direction := (get_global_mouse_position() - global_position).normalized()
	bullet.setup(direction, false)
	
	var projectile_container: Node = get_tree().get_first_node_in_group("projectiles_container")
	if projectile_container:
		projectile_container.add_child(bullet)
	else:
		get_parent().add_child(bullet)
	
	await get_tree().create_timer(SHOOT_COOLDOWN).timeout
	can_shoot = true

# =========================
# DAMAGE
# =========================
func take_damage(amount: float = 10.0) -> void:
	if is_dead or is_dashing:  # I-frames during dash
		return
	health -= amount
	health = maxf(health, 0.0)
	player_damaged.emit(health)
	
	# Low HP warning
	player_low_hp.emit(health < max_health * 0.25)
	
	# Flash red
	modulate = Color.RED
	GameJuice.screen_shake(2.0, 1.0)
	await get_tree().create_timer(0.1).timeout
	_update_modulate()
	
	if health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	GameJuice.death_impact()
	player_died.emit()
	visible = false
	set_physics_process(false)
	set_process(false)

# =========================
# CROSSHAIR CURSOR
# =========================
func _setup_crosshair_cursor() -> void:
	# Create a 16x16 crosshair texture programmatically
	var size: int = 16
	var center: int = size / 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # Transparent background
	
	var crosshair_color := Color(0.3, 1.0, 0.8, 1.0)  # Neon cyan
	var outline_color := Color(0, 0, 0, 0.8)
	
	# Horizontal line
	for x in range(1, size - 1):
		if abs(x - center) > 1:  # Gap in center
			img.set_pixel(x, center, crosshair_color)
			# Outline
			if center - 1 >= 0:
				img.set_pixel(x, center - 1, outline_color)
			if center + 1 < size:
				img.set_pixel(x, center + 1, outline_color)
	
	# Vertical line
	for y in range(1, size - 1):
		if abs(y - center) > 1:  # Gap in center
			img.set_pixel(center, y, crosshair_color)
			# Outline
			if center - 1 >= 0:
				img.set_pixel(center - 1, y, outline_color)
			if center + 1 < size:
				img.set_pixel(center + 1, y, outline_color)
	
	# Center dot
	img.set_pixel(center, center, Color(1, 0.3, 0.3, 1.0))  # Red center dot
	
	var tex := ImageTexture.create_from_image(img)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(center, center))

