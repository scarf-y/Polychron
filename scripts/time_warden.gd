extends CharacterBody2D

## Time Warden — THE BOSS. Can move SLOWLY even during TIME_STOP.
## This is the ultimate challenge that tests all player abilities.

# --- Stats ---
@export var health: int = 20
@export var max_health: int = 20
@export var normal_speed: float = 40.0
@export var timestop_speed: float = 15.0  # Moves even in time stop!
@export var charge_speed: float = 120.0
var is_dead: bool = false

# --- Attack Patterns ---
enum BossState { IDLE, CHASE, CHARGING, SPREAD_SHOT, STUNNED }
var current_boss_state: BossState = BossState.IDLE

# --- Timers ---
var _attack_timer: float = 0.0
const ATTACK_INTERVAL: float = 3.0
const CHARGE_DURATION: float = 0.8
const STUN_DURATION: float = 1.0
var _state_timer: float = 0.0

# --- Charging ---
var _charge_direction: Vector2 = Vector2.ZERO

# --- Shooting ---
var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet.tscn")
const SPREAD_COUNT: int = 8  # Number of bullets in spread

# --- Visual ---
var _flash_timer: float = 0.0
var _is_telegraph: bool = false

# --- Signals ---
signal enemy_died(enemy: Node2D)
signal boss_health_changed(current: int, maximum: int)

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	boss_health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player or not is_instance_valid(player):
		return
	
	# --- Determine speed based on time state ---
	var effective_speed := normal_speed
	var is_time_stopped := TimeManager.current_state == TimeManager.TimeState.STOPPED
	
	if is_time_stopped:
		# THE KEY MECHANIC: Boss still moves during time stop, but slowly
		effective_speed = timestop_speed
		modulate = Color(0.6, 0.2, 0.8)  # Ominous purple even when frozen
	elif TimeManager.current_state == TimeManager.TimeState.ERASED:
		# Can still sense player faintly during erase
		effective_speed = normal_speed * 0.5
		modulate = Color(0.5, 0.2, 0.6, 0.7)
	else:
		modulate = Color(0.6, 0.1, 0.8)  # Purple
	
	# --- State Machine ---
	match current_boss_state:
		BossState.IDLE:
			_handle_idle(delta, player)
		BossState.CHASE:
			_handle_chase(delta, player, effective_speed)
		BossState.CHARGING:
			_handle_charge(delta)
		BossState.SPREAD_SHOT:
			_handle_spread_shot(player)
		BossState.STUNNED:
			_handle_stunned(delta)

func _handle_idle(delta: float, player: Node2D) -> void:
	var distance: float = global_position.distance_to(player.global_position)
	if distance < 300.0:
		current_boss_state = BossState.CHASE

func _handle_chase(delta: float, player: Node2D, speed: float) -> void:
	var direction: Vector2 = (player.global_position - global_position).normalized()
	var distance: float = global_position.distance_to(player.global_position)
	
	velocity = direction * speed
	move_and_slide()
	
	# Attack timer
	_attack_timer += delta
	if _attack_timer >= ATTACK_INTERVAL:
		_attack_timer = 0.0
		# Choose attack based on distance
		if distance < 80.0:
			_start_charge(direction)
		else:
			_start_spread_shot()

func _start_charge(direction: Vector2) -> void:
	current_boss_state = BossState.CHARGING
	_charge_direction = direction
	_state_timer = CHARGE_DURATION
	_is_telegraph = true
	
	# Telegraph: flash red before charging
	modulate = Color.RED

func _handle_charge(delta: float) -> void:
	if _is_telegraph:
		# Brief telegraph pause
		_is_telegraph = false
		await get_tree().create_timer(0.3).timeout
	
	_state_timer -= delta
	velocity = _charge_direction * charge_speed
	move_and_slide()
	
	# Check for player collision during charge
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(2)  # Heavy hit
	
	if _state_timer <= 0.0:
		current_boss_state = BossState.STUNNED
		_state_timer = STUN_DURATION

func _start_spread_shot() -> void:
	current_boss_state = BossState.SPREAD_SHOT
	# Telegraph
	modulate = Color.YELLOW

func _handle_spread_shot(player: Node2D) -> void:
	# Fire bullets in a spread pattern
	var base_angle: float = (player.global_position - global_position).angle()
	
	for i in SPREAD_COUNT:
		var angle: float = base_angle + (TAU / SPREAD_COUNT) * i
		var direction: Vector2 = Vector2.from_angle(angle)
		
		var bullet := bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.setup(direction, true)
		
		var container: Node = get_tree().get_first_node_in_group("projectiles_container")
		if container:
			container.add_child(bullet)
		else:
			get_parent().add_child(bullet)
	
	current_boss_state = BossState.STUNNED
	_state_timer = STUN_DURATION * 0.5

func _handle_stunned(delta: float) -> void:
	_state_timer -= delta
	velocity = Vector2.ZERO
	
	# Flicker effect while stunned
	_flash_timer += delta
	modulate.a = 0.5 + sin(_flash_timer * 10.0) * 0.3
	
	if _state_timer <= 0.0:
		_flash_timer = 0.0
		modulate.a = 1.0
		current_boss_state = BossState.CHASE

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	health -= amount
	boss_health_changed.emit(health, max_health)
	
	# Flash white
	modulate = Color.WHITE
	await get_tree().create_timer(0.08).timeout
	if not is_dead:
		modulate = Color(0.6, 0.1, 0.8)
	
	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	GameJuice.death_impact()
	enemy_died.emit(self)
	# Boss death is dramatic — pause briefly
	Engine.time_scale = 0.1
	await get_tree().create_timer(0.05).timeout  # 0.5s real time at 0.1x
	Engine.time_scale = 1.0
	queue_free()
