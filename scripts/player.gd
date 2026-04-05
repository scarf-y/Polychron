extends CharacterBody2D

## Agent 0-Zero — The Player Controller
## Handles movement, shooting, and time ability activation.

# --- Stats ---
const SPEED: float = 120.0
var health: int = 5
var max_health: int = 5
var is_dead: bool = false

# --- Shooting ---
const SHOOT_COOLDOWN: float = 0.3
var can_shoot: bool = true
var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet.tscn")

# --- Time Ability State ---
var _active_ability: TimeManager.TimeState = TimeManager.TimeState.NORMAL

# --- Signals ---
signal player_damaged(new_health: int)
signal player_died()

func _ready() -> void:
	add_to_group("player")

func _process(delta: float) -> void:
	if is_dead:
		return
	
	_handle_time_abilities()
	_handle_shooting()

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	
	# --- Movement ---
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Compensate speed when time is slowed so player moves at normal speed
	var current_speed: float = SPEED
	if Engine.time_scale > 0.0 and Engine.time_scale < 1.0:
		current_speed = SPEED / Engine.time_scale
	
	if input_dir != Vector2.ZERO:
		velocity = input_dir.normalized() * current_speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, current_speed)
	
	move_and_slide()

func _handle_time_abilities() -> void:
	# TIME STOP — Hold Space
	if Input.is_action_just_pressed("time_stop") and TimeManager.can_use_ability():
		_active_ability = TimeManager.TimeState.STOPPED
		TimeManager.change_time_state(TimeManager.TimeState.STOPPED)
		GameJuice.time_stop_impact()  # Screen shake on activation
		modulate = Color.CYAN
	elif Input.is_action_just_released("time_stop") and _active_ability == TimeManager.TimeState.STOPPED:
		_return_to_normal()
	
	# TIME SLOW — Hold Shift
	if Input.is_action_just_pressed("time_slow") and TimeManager.can_use_ability():
		_active_ability = TimeManager.TimeState.SLOWED
		TimeManager.change_time_state(TimeManager.TimeState.SLOWED)
		modulate = Color.YELLOW
	elif Input.is_action_just_released("time_slow") and _active_ability == TimeManager.TimeState.SLOWED:
		_return_to_normal()
	
	# TIME ERASE — Hold E
	if Input.is_action_just_pressed("time_erase") and TimeManager.can_use_ability():
		_active_ability = TimeManager.TimeState.ERASED
		TimeManager.change_time_state(TimeManager.TimeState.ERASED)
		# Ghost mode — phase through enemies (layer 3)
		set_collision_mask_value(3, false)
		set_collision_layer_value(2, false)  # Hide from enemies too
		modulate = Color(0.5, 0.5, 1.0, 0.3)
	elif Input.is_action_just_released("time_erase") and _active_ability == TimeManager.TimeState.ERASED:
		set_collision_mask_value(3, true)
		set_collision_layer_value(2, true)  # Become visible again
		_return_to_normal()
	
	# Auto-return when gauge depletes
	if TimeManager.time_gauge <= 0.0 and _active_ability != TimeManager.TimeState.NORMAL:
		if _active_ability == TimeManager.TimeState.ERASED:
			set_collision_mask_value(3, true)
			set_collision_layer_value(2, true)
		_active_ability = TimeManager.TimeState.NORMAL
		modulate = Color.WHITE

func _return_to_normal() -> void:
	_active_ability = TimeManager.TimeState.NORMAL
	TimeManager.change_time_state(TimeManager.TimeState.NORMAL)
	modulate = Color.WHITE

func _handle_shooting() -> void:
	if Input.is_action_just_pressed("shoot") and can_shoot:
		_shoot()

func _shoot() -> void:
	can_shoot = false
	
	var bullet := bullet_scene.instantiate()
	bullet.global_position = global_position
	
	# Direction toward mouse
	var direction := (get_global_mouse_position() - global_position).normalized()
	bullet.setup(direction, false)  # false = player bullet
	
	# Add bullet to the Projectiles container if it exists, else to parent
	var projectile_container: Node = get_tree().get_first_node_in_group("projectiles_container")
	if projectile_container:
		projectile_container.add_child(bullet)
	else:
		get_parent().add_child(bullet)
	
	# Cooldown
	await get_tree().create_timer(SHOOT_COOLDOWN).timeout
	can_shoot = true

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	health -= amount
	player_damaged.emit(health)
	
	# Flash red
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if _active_ability == TimeManager.TimeState.NORMAL:
		modulate = Color.WHITE
	
	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	player_died.emit()
	# For now, just hide. Later: death screen
	visible = false
	set_physics_process(false)
	set_process(false)
