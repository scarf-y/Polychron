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
enum BossState { IDLE, CHASE, CHARGING, SPREAD_SHOT, STUNNED, CONE_SHOCKWAVE }
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
const SPREAD_COUNT: int = 12

# --- Visual ---
var _flash_timer: float = 0.0
var _is_telegraph: bool = false

# --- Minions ---
var stalker_scene: PackedScene = preload("res://scenes/enemies/stalker.tscn")
var _minion_spawn_timer: float = 15.0

# --- Bombs ---
var bomb_scene: PackedScene = preload("res://scenes/enemies/time_bomb.tscn")
var _bomb_spawn_timer: float = 5.0

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
		
	# --- Minion Spawning ---
	_minion_spawn_timer -= delta * Engine.time_scale
	if _minion_spawn_timer <= 0.0:
		_minion_spawn_timer = 15.0
		if randf() <= 0.75:
			_spawn_minions()
			
	# --- Bomb Spawning ---
	_bomb_spawn_timer -= delta * Engine.time_scale
	if _bomb_spawn_timer <= 0.0:
		_bomb_spawn_timer = 5.0
		_spawn_bombs(player)
	
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
		BossState.CONE_SHOCKWAVE:
			_handle_cone_shockwave(delta, player)

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
			if randf() < 0.4:
				_start_cone_shockwave(player)
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
	_fire_spread()
	
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

func _fire_spread() -> void:
	if not is_instance_valid(bullet_scene): return
	
	GameJuice.screen_shake(4.0, 0.2)
	
	var angle_step = TAU / SPREAD_COUNT
	for i in SPREAD_COUNT:
		var b: Node2D = bullet_scene.instantiate()
		b.global_position = global_position
		b.setup(Vector2.RIGHT.rotated(i * angle_step), true)
		if "base_color" in b:
			b.base_color = Color(1.0, 0.2, 1.0)
		get_tree().current_scene.add_child(b)

func _spawn_minions() -> void:
	if not is_instance_valid(stalker_scene): return
	
	var count = randi_range(3, 5)
	for i in range(count):
		var stalker: Node2D = stalker_scene.instantiate()
		var angle = randf() * TAU
		var dist = randf_range(80.0, 200.0)
		stalker.global_position = global_position + Vector2(cos(angle), sin(angle)) * dist
		
		if "is_active_in_room" in stalker:
			stalker.is_active_in_room = true
			
		get_tree().current_scene.add_child(stalker)
		GameJuice.spawn_death_particles(stalker.global_position, Color(0.8, 0.2, 0.2), 15)

func _spawn_bombs(player: Node2D) -> void:
	if not is_instance_valid(bomb_scene): return
	
	var count = randi_range(1, 3)
	var spawned_positions: Array[Vector2] = []
	for i in range(count):
		var bomb: Node2D = bomb_scene.instantiate()
		
		# Prevent stacking
		var spawn_pos := Vector2.ZERO
		var valid_pos := false
		var attempts := 0
		while not valid_pos and attempts < 10:
			var angle = randf() * TAU
			var dist = randf_range(0.0, 150.0)
			spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * dist
			
			valid_pos = true
			for p in spawned_positions:
				if p.distance_to(spawn_pos) < 160.0:
					valid_pos = false
					break
			attempts += 1
			
		spawned_positions.append(spawn_pos)
		bomb.global_position = spawn_pos
		get_tree().current_scene.add_child(bomb)

var _cone_direction: Vector2 = Vector2.ZERO

func _start_cone_shockwave(player: Node2D) -> void:
	current_boss_state = BossState.CONE_SHOCKWAVE
	var target_pos: Vector2 = TimeManager.get_enemy_target_position(player)
	_cone_direction = (target_pos - global_position).normalized()
	_state_timer = 0.6  # Telegraph duration
	_is_telegraph = true
	modulate = Color(1.0, 0.5, 0.0)  # Orange telegraph
	velocity = Vector2.ZERO

func _handle_cone_shockwave(delta: float, player: Node2D) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		if _is_telegraph:
			_fire_cone(_cone_direction)
			_is_telegraph = false
			_state_timer = STUN_DURATION * 0.5
			modulate = Color.WHITE
		else:
			current_boss_state = BossState.CHASE

func _fire_cone(dir: Vector2) -> void:
	if not is_instance_valid(bullet_scene): return
	
	GameJuice.screen_shake(8.0, 0.3)
	
	var bullet_count = 15
	var spread_angle = deg_to_rad(45.0)
	var start_angle = dir.angle() - (spread_angle / 2.0)
	var angle_step = spread_angle / float(bullet_count - 1)
	
	for i in bullet_count:
		var b: Node2D = bullet_scene.instantiate()
		b.global_position = global_position
		b.setup(Vector2.RIGHT.rotated(start_angle + i * angle_step), true)
		if "speed" in b:
			b.speed = 450.0  # Very fast!
		if "base_color" in b:
			b.base_color = Color(1.0, 0.5, 0.0)
		get_tree().current_scene.add_child(b)

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
	# 0.4 game time = 4.0 seconds real time at 0.1x time scale
	tween.tween_property(self, "scale", Vector2(2.2, 2.2), 0.4) 
	
	# Chain of erratic explosions while time is slowed
	for i in range(15):
		# 0.03 game time = 0.3 seconds real time per explosion (4.5 seconds total)
		await get_tree().create_timer(0.03).timeout
		GameJuice.screen_shake(12.0, 1.5)
		modulate = Color(randf_range(0.5, 1.0), randf_range(0, 0.5), randf_range(0.5, 1.0))
		var offset := Vector2(randf_range(-40, 40), randf_range(-40, 40))
		GameJuice.spawn_death_particles(global_position + offset, modulate, 20)
	
	# Final massive burst and restore time
	Engine.time_scale = 1.0
	GameJuice.screen_shake(30.0, 3.0)
	GameJuice.spawn_death_particles(global_position, Color.WHITE, 80)
	
	# Transition to Win Screen
	GameJuice.transition_to_scene("res://scenes/ui/win_screen.tscn")
	
	queue_free()
