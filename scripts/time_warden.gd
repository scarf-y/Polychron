extends CharacterBody2D

## The Kernel — THE BOSS of the Vector Void.
## Can move SLOWLY even during TIME_STOP. The ultimate test.
## Polygon2D hexagon shape. Glows ominous purple.

# --- Stats ---
@export var health: float = 800.0
@export var max_health: float = 800.0
@export var normal_speed: float = 40.0
@export var timestop_speed: float = 15.0
@export var charge_speed: float = 140.0
var is_dead: bool = false
var is_active_in_room: bool = true

# --- Attack Patterns ---
enum BossState { IDLE, CHASE, CHARGING, SPREAD_SHOT, STUNNED }
var current_boss_state: BossState = BossState.IDLE

# --- Timers ---
var _attack_timer: float = 0.0
const ATTACK_INTERVAL: float = 1.2
const CHARGE_DURATION: float = 0.8
const STUN_DURATION: float = 1.0
var _state_timer: float = 0.0

# --- Charging ---
var _charge_direction: Vector2 = Vector2.ZERO
const CHARGE_DAMAGE: float = 25.0

# --- Shooting ---
var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet.tscn")
const SPREAD_COUNT: int = 24

# --- Visual ---
var _flash_timer: float = 0.0
var _is_telegraph: bool = false

# --- Signals ---
signal enemy_died(enemy: Node2D)
signal boss_health_changed(current: float, maximum: float)

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	boss_health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	if is_dead or not is_active_in_room:
		return
	
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player or not is_instance_valid(player):
		return
	
	# --- Speed based on time state ---
	var effective_speed := normal_speed
	var is_time_stopped := TimeManager.current_state == TimeManager.TimeState.STOPPED
	
	if is_time_stopped:
		effective_speed = timestop_speed
		modulate = Color(0.5, 0.1, 0.9)  # Deep purple
	elif TimeManager.current_state == TimeManager.TimeState.ERASED:
		effective_speed = normal_speed * 0.5
		modulate = Color(0.4, 0.1, 0.6, 0.7)
	else:
		modulate = Color(0.6, 0.0, 1.0)  # Neon purple
	
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
	var target_pos: Vector2 = TimeManager.get_enemy_target_position(player)
	var distance: float = global_position.distance_to(target_pos)
	if distance < 300.0:
		current_boss_state = BossState.CHASE

func _handle_chase(delta: float, player: Node2D, speed: float) -> void:
	var target_pos: Vector2 = TimeManager.get_enemy_target_position(player)
	var direction: Vector2 = (target_pos - global_position).normalized()
	var distance: float = global_position.distance_to(target_pos)
	
	velocity = direction * speed
	move_and_slide()
	
	_attack_timer += delta
	if _attack_timer >= ATTACK_INTERVAL:
		_attack_timer = 0.0
		if distance < 80.0:
			_start_charge(direction)
		else:
			_start_spread_shot()

func _start_charge(direction: Vector2) -> void:
	current_boss_state = BossState.CHARGING
	_charge_direction = direction
	_state_timer = CHARGE_DURATION
	_is_telegraph = true
	modulate = Color(1, 0, 0)  # Red telegraph

func _handle_charge(delta: float) -> void:
	if _is_telegraph:
		_is_telegraph = false
		await get_tree().create_timer(0.3).timeout
	
	_state_timer -= delta
	velocity = _charge_direction * charge_speed
	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(CHARGE_DAMAGE)
				GameJuice.screen_shake(6.0, 2.0)
	
	if _state_timer <= 0.0:
		current_boss_state = BossState.STUNNED
		_state_timer = STUN_DURATION

func _start_spread_shot() -> void:
	current_boss_state = BossState.SPREAD_SHOT
	modulate = Color(1, 1, 0)  # Yellow telegraph

func _handle_spread_shot(player: Node2D) -> void:
	var target_pos: Vector2 = TimeManager.get_enemy_target_position(player)
	var base_angle: float = (target_pos - global_position).angle()
	
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
	
	GameJuice.screen_shake(4.0, 1.5)
	current_boss_state = BossState.STUNNED
	_state_timer = STUN_DURATION * 0.5

func _handle_stunned(delta: float) -> void:
	_state_timer -= delta
	velocity = Vector2.ZERO
	
	_flash_timer += delta
	modulate.a = 0.5 + sin(_flash_timer * 10.0) * 0.3
	
	if _state_timer <= 0.0:
		_flash_timer = 0.0
		modulate.a = 1.0
		current_boss_state = BossState.CHASE

func take_damage(amount: float = 10.0) -> void:
	if is_dead:
		return
	health -= amount
	boss_health_changed.emit(health, max_health)
	
	modulate = Color.WHITE
	await get_tree().create_timer(0.08).timeout
	if not is_dead:
		modulate = Color(0.6, 0.0, 1.0)
	
	if health <= 0.0:
		_die()

var _health_core_scene: PackedScene = preload("res://scenes/effects/health_core.tscn")

func _die() -> void:
	is_dead = true
	GameJuice.death_impact()
	
	# Massive death particle explosion
	GameJuice.spawn_death_particles(global_position, Color(0.6, 0.0, 1.0), 25)
	GameJuice.spawn_death_particles(global_position + Vector2(10, 0), Color(1, 0, 0.5), 15)
	GameJuice.spawn_death_particles(global_position + Vector2(-10, 0), Color(0, 0.5, 1), 15)
	
	# Fracture reduction / lockdown exit
	TimeManager.on_enemy_killed()
	
	# Boss always drops a Health Core
	var core := _health_core_scene.instantiate()
	core.global_position = global_position
	get_tree().current_scene.add_child(core)
	
	enemy_died.emit(self)
	
	# Dramatic slow-mo death animation
	Engine.time_scale = 0.1
	
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.2) # ~2 seconds real time
	
	# Chain of erratic explosions while time is slowed
	for i in range(8):
		await get_tree().create_timer(0.02).timeout
		GameJuice.screen_shake(8.0, 1.0)
		modulate = Color(randf_range(0.5, 1.0), randf_range(0, 0.5), randf_range(0.5, 1.0))
		var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
		GameJuice.spawn_death_particles(global_position + offset, modulate, 15)
	
	# Final massive burst and restore time
	Engine.time_scale = 1.0
	GameJuice.screen_shake(25.0, 3.0)
	GameJuice.spawn_death_particles(global_position, Color.WHITE, 60)
	
	# Transition to Win Screen
	GameJuice.transition_to_scene("res://scenes/ui/win_screen.tscn")
	
	queue_free()
