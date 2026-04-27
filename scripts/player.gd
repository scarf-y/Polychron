extends CharacterBody2D

## Sequence-0 — The Player Controller
## Handles movement, shooting, time abilities, phase dash, crit system,
## and fracture-stage debuffs.

# --- Stats ---
var base_speed: float = 120.0
var speed: float = 120.0
var health: float = 100.0
var max_health: float = 100.0
var is_dead: bool = false

# --- Crit System ---
var base_crit_chance: float = 0.2
var crit_chance: float = 0.2
const CRIT_MULTIPLIER: float = 2.5
const BASE_DAMAGE_MIN: float = 10.0
const BASE_DAMAGE_MAX: float = 15.0

# --- Shooting ---
const SHOOT_COOLDOWN: float = 0.25
var can_shoot: bool = true
var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet.tscn")

# --- Phase Dash ---
const DASH_SPEED: float = 300.0
const DASH_DURATION: float = 0.2
var base_dash_cooldown: float = 0.6
var dash_cooldown: float = 0.6
const DASH_TIMESTOP_MULTIPLIER: float = 1.5
const GHOST_SPAWN_INTERVAL: float = 0.025
var is_dashing: bool = false
var can_dash: bool = true

# --- Time Ability State ---
var _active_ability: TimeManager.TimeState = TimeManager.TimeState.NORMAL
var _erase_decoy: Node2D = null

# --- I-Frames ---
var _invincibility_timer: float = 0.0
const INVINCIBILITY_DURATION: float = 0.8

# --- Fracture Debuffs ---
var _fracture_stage: int = 1
var _damage_multiplier: float = 1.0

# --- Signals ---
signal player_damaged(new_health: float)
signal player_died()
signal player_low_hp(is_low: bool)  # For chromatic warning below 25%

func _ready() -> void:
	add_to_group("player")
	_setup_crosshair_cursor()
	
	# Load persistent health
	health = TimeManager.player_health
	
	# Reset fracture state on spawn (handles respawn after death)
	TimeManager.reset_fracture()
	GameJuice.stop_lockdown_flicker()
	
	# Connect fracture signals
	TimeManager.fracture_changed.connect(_on_fracture_changed)
	TimeManager.lockdown_changed.connect(_on_lockdown_changed)
	
	# Sync debuffs to current fracture level
	_on_fracture_changed(TimeManager.fracture_level)

func _process(delta: float) -> void:
	if is_dead:
		return
	
	if _invincibility_timer > 0.0:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0.0:
			_update_modulate()
		else:
			if fmod(_invincibility_timer * 15.0, 1.0) > 0.5:
				modulate.a = 0.2
			else:
				modulate.a = 0.8
	
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
	var current_speed: float = speed
	if TimeManager.current_state == TimeManager.TimeState.SLOWED:
		current_speed = speed / 0.2
	
	if input_dir != Vector2.ZERO:
		velocity = input_dir.normalized() * current_speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, current_speed)
	
	move_and_slide()

# =========================
# FRACTURE STAGE SYSTEM
# =========================
func _on_fracture_changed(value: float) -> void:
	var new_stage: int = 1
	if value >= 100.0:
		new_stage = 5
	elif value > 75.0:
		new_stage = 4
	elif value > 50.0:
		new_stage = 3
	elif value > 25.0:
		new_stage = 2
	else:
		new_stage = 1
	
	if new_stage != _fracture_stage:
		_fracture_stage = new_stage
		_apply_fracture_debuffs()

func _apply_fracture_debuffs() -> void:
	# Reset to base stats first
	speed = base_speed
	crit_chance = base_crit_chance
	dash_cooldown = base_dash_cooldown
	_damage_multiplier = 1.0
	
	match _fracture_stage:
		1:
			# Stage I — Base stats, no debuffs
			pass
		2:
			# Stage II — Crit chance halved
			crit_chance = base_crit_chance / 2.0
		3:
			# Stage III — Speed -20%, dash cooldown doubled
			speed = base_speed * 0.8
			dash_cooldown = base_dash_cooldown * 2.0
			# Also keep stage II debuff
			crit_chance = base_crit_chance / 2.0
		4:
			# Stage IV — Damage taken +50%, plus all previous
			_damage_multiplier = 1.5
			speed = base_speed * 0.8
			dash_cooldown = base_dash_cooldown * 2.0
			crit_chance = base_crit_chance / 2.0
		5:
			# Stage V — Lockdown (handled by TimeManager)
			_damage_multiplier = 1.5
			speed = base_speed * 0.8
			dash_cooldown = base_dash_cooldown * 2.0
			crit_chance = base_crit_chance / 2.0

func _on_lockdown_changed(lockdown: bool) -> void:
	if lockdown:
		# Force cancel any active time ability
		force_cancel_ability()
		# Start lockdown flicker + impact
		GameJuice.lockdown_impact()
		GameJuice.start_lockdown_flicker(self)
	else:
		# Stop flicker and restore visuals
		GameJuice.stop_lockdown_flicker()
		modulate.a = 1.0
		# Re-apply debuffs for current fracture level (75% after exit)
		_on_fracture_changed(TimeManager.fracture_level)
		_update_modulate()

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
	var dash_speed_val: float = DASH_SPEED
	var dash_time: float = DASH_DURATION
	if TimeManager.current_state == TimeManager.TimeState.STOPPED:
		dash_speed_val *= DASH_TIMESTOP_MULTIPLIER
		dash_time *= DASH_TIMESTOP_MULTIPLIER
	
	velocity = move_dir * dash_speed_val
	
	GameJuice.screen_shake(2.5, 1.3)
	
	# Ghost trail
	_spawn_ghost_trail(dash_time)
	
	# Dash duration
	await get_tree().create_timer(dash_time).timeout
	
	# End dash
	is_dashing = false
	velocity = move_dir * speed * 0.5  # Slight momentum after dash
	
	# Restore collision
	if _active_ability != TimeManager.TimeState.ERASED:
		set_collision_layer_value(2, true)
		set_collision_mask_value(3, true)
	
	# Restore color based on current ability
	_update_modulate()
	
	# Dash cooldown (uses the potentially modified dash_cooldown)
	await get_tree().create_timer(dash_cooldown).timeout
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
	var is_crit: bool = randf() < crit_chance
	var final_damage: float = base_damage * (CRIT_MULTIPLIER if is_crit else 1.0)
	return [final_damage, is_crit]

# =========================
# TIME ABILITIES
# =========================
func _handle_time_abilities() -> void:
	# TIME STOP — Hold Space
	if Input.is_action_just_pressed("time_stop") and TimeManager.can_use_ability() and _active_ability == TimeManager.TimeState.NORMAL:
		_active_ability = TimeManager.TimeState.STOPPED
		TimeManager.change_time_state(TimeManager.TimeState.STOPPED)
		GameJuice.time_stop_impact()
		_update_modulate()
	elif Input.is_action_just_released("time_stop") and _active_ability == TimeManager.TimeState.STOPPED:
		_return_to_normal()
	
	# TIME SLOW — Hold Shift
	if Input.is_action_just_pressed("time_slow") and TimeManager.can_use_ability() and _active_ability == TimeManager.TimeState.NORMAL:
		_active_ability = TimeManager.TimeState.SLOWED
		TimeManager.change_time_state(TimeManager.TimeState.SLOWED)
		_update_modulate()
	elif Input.is_action_just_released("time_slow") and _active_ability == TimeManager.TimeState.SLOWED:
		_return_to_normal()
	
	# TIME ERASE — Hold E
	if Input.is_action_just_pressed("time_erase") and TimeManager.can_use_ability() and _active_ability == TimeManager.TimeState.NORMAL:
		_active_ability = TimeManager.TimeState.ERASED
		TimeManager.change_time_state(TimeManager.TimeState.ERASED)
		set_collision_mask_value(3, false)
		set_collision_layer_value(2, false)
		
		TimeManager.erased_target_position = global_position
		var decoy_shape = ColorRect.new()
		decoy_shape.size = Vector2(16, 16)
		decoy_shape.position = Vector2(-8, -8)
		decoy_shape.color = Color(0.5, 0.5, 1.0, 0.6)
		_erase_decoy = Node2D.new()
		_erase_decoy.global_position = global_position
		_erase_decoy.add_child(decoy_shape)
		get_tree().current_scene.add_child(_erase_decoy)
		
		_update_modulate()
	elif Input.is_action_just_released("time_erase") and _active_ability == TimeManager.TimeState.ERASED:
		set_collision_mask_value(3, true)
		set_collision_layer_value(2, true)
		if is_instance_valid(_erase_decoy):
			_erase_decoy.queue_free()
		_return_to_normal()
	
	# Visual feedback when ability use is blocked
	if _active_ability == TimeManager.TimeState.NORMAL:
		if Input.is_action_just_pressed("time_stop") or Input.is_action_just_pressed("time_slow") or Input.is_action_just_pressed("time_erase"):
			if not TimeManager.can_use_ability():
				_show_ability_blocked_feedback()
	
	# Auto-return when gauge depletes
	if TimeManager.time_gauge <= 0.0 and _active_ability != TimeManager.TimeState.NORMAL:
		if _active_ability == TimeManager.TimeState.ERASED:
			set_collision_mask_value(3, true)
			set_collision_layer_value(2, true)
			if is_instance_valid(_erase_decoy):
				_erase_decoy.queue_free()
		_active_ability = TimeManager.TimeState.NORMAL
		_update_modulate()

func _show_ability_blocked_feedback() -> void:
	# Flash the player red-grey and spawn a "BLOCKED" text
	var reason: String = "LOCKED OUT" if TimeManager.is_lockdown else "NULLIFIED"
	var flash_color: Color = Color(1.0, 0.1, 0.1) if TimeManager.is_lockdown else Color(0.5, 0.0, 0.0)
	
	GameJuice.spawn_blocked_text(global_position)
	GameJuice.screen_shake(1.5, 1.0)
	
	# Quick red flash
	modulate = flash_color
	await get_tree().create_timer(0.1).timeout
	_update_modulate()

func force_cancel_ability() -> void:
	if _active_ability != TimeManager.TimeState.NORMAL:
		if _active_ability == TimeManager.TimeState.ERASED:
			set_collision_mask_value(3, true)
			set_collision_layer_value(2, true)
			if is_instance_valid(_erase_decoy):
				_erase_decoy.queue_free()
		_return_to_normal()

func _return_to_normal() -> void:
	_active_ability = TimeManager.TimeState.NORMAL
	TimeManager.change_time_state(TimeManager.TimeState.NORMAL)
	_update_modulate()

func _update_modulate() -> void:
	if is_dashing:
		modulate = Color(0.3, 0.6, 1.0, 0.5)
		return
	if TimeManager.null_zone_active:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
		return
	if TimeManager.is_lockdown:
		# Lockdown tint — handled by flicker in GameJuice, but base color is grey-red
		modulate = Color(0.8, 0.3, 0.3, 1.0)
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
	if is_dead or is_dashing or _active_ability == TimeManager.TimeState.ERASED or _invincibility_timer > 0.0:
		return
		
	_invincibility_timer = INVINCIBILITY_DURATION
	
	# Apply fracture damage multiplier (Stage IV: +50%)
	var final_amount: float = amount * _damage_multiplier
	health -= final_amount
	health = maxf(health, 0.0)
	TimeManager.player_health = health
	
	# Screen shake and hitstop via GameJuice
	GameJuice.hit_impact()
	
	player_damaged.emit(health)
	
	# Spawn damage numbers — purple & 2x larger at Stage IV+
	var is_fracture_amplified: bool = _fracture_stage >= 4
	if is_fracture_amplified:
		if GameJuice.has_method("spawn_damage_number"):
			GameJuice.spawn_damage_number(final_amount, global_position, false, Color(0.7, 0.1, 1.0), 2.0)
	else:
		if GameJuice.has_method("spawn_damage_number"):
			GameJuice.spawn_damage_number(final_amount, global_position, false)
	
	# Low HP warning
	player_low_hp.emit(health < max_health * 0.25)
	
	# Flash red
	modulate = Color.RED
	GameJuice.screen_shake(2.0, 1.0)
	await get_tree().create_timer(0.1).timeout
	_update_modulate()
	
	if health <= 0.0:
		_die()

func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(health + amount, max_health)
	TimeManager.player_health = health
	player_damaged.emit(health)

func _die() -> void:
	is_dead = true
	GameJuice.death_impact()
	player_died.emit()
	visible = false
	set_physics_process(false)
	set_process(false)

func set_camera_limits(rect: Rect2) -> void:
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.limit_left = int(rect.position.x)
		cam.limit_top = int(rect.position.y)
		cam.limit_right = int(rect.position.x + rect.size.x)
		cam.limit_bottom = int(rect.position.y + rect.size.y)

# =========================
# CROSSHAIR CURSOR
# =========================
func _setup_crosshair_cursor() -> void:
	var size: int = 32
	var center: int = size / 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var col := Color(0.3, 1.0, 0.8, 1.0)  # Neon cyan
	var out := Color(0, 0, 0, 0.9)
	var gap: int = 3  # Bigger gap in center
	
	# Horizontal lines (2px thick)
	for x in range(2, size - 2):
		if abs(x - center) > gap:
			for w in range(-1, 1):  # 2px width
				img.set_pixel(x, center + w, col)
				if center + w - 1 >= 0:
					img.set_pixel(x, center + w - 1, out)
				if center + w + 1 < size:
					img.set_pixel(x, center + w + 1, out)
	
	# Vertical lines (2px thick)
	for y in range(2, size - 2):
		if abs(y - center) > gap:
			for w in range(-1, 1):
				img.set_pixel(center + w, y, col)
				if center + w - 1 >= 0:
					img.set_pixel(center + w - 1, y, out)
				if center + w + 1 < size:
					img.set_pixel(center + w + 1, y, out)
	
	# Center dot (3x3 red)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			img.set_pixel(center + dx, center + dy, Color(1, 0.2, 0.3, 1.0))
	
	var tex := ImageTexture.create_from_image(img)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(center, center))
