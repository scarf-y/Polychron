extends CharacterBody2D

## Turret Enemy — static shooter with firing telegraph.
## Octagonal shape. Flashes before firing.

# --- Stats ---
@export var health: float = 120.0
@export var fire_interval: float = 0.6
@export var detection_range: float = 400.0
var is_dead: bool = false
var is_active_in_room: bool = true

# --- Shooting ---
var _fire_timer: float = 0.0
var _is_telegraphing: bool = false
var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet.tscn")

# --- Signals ---
signal enemy_died(enemy: Node2D)

func _ready() -> void:
	add_to_group("enemies")
	_fire_timer = fire_interval

func _physics_process(delta: float) -> void:
	if is_dead or not is_active_in_room:
		return
	
	# --- Time State Reactions ---
	match TimeManager.current_state:
		TimeManager.TimeState.STOPPED:
			modulate = Color(0.3, 0.3, 0.3)
			return
		TimeManager.TimeState.ERASED:
			modulate = Color(1.0, 0.5, 0.0, 0.4)
		_:
			if not _is_telegraphing:
				modulate = Color(1.0, 0.6, 0.0)  # Neon orange
	
	# --- Turret Logic ---
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player or not is_instance_valid(player):
		return
	
	var target_pos: Vector2 = TimeManager.get_enemy_target_position(player)
	var distance: float = global_position.distance_to(target_pos)
	if distance > detection_range:
		return
	
	_fire_timer += delta
	if _fire_timer >= fire_interval and not _is_telegraphing:
		_fire_timer = 0.0
		_fire_with_telegraph(player)

func _fire_with_telegraph(target: Node2D) -> void:
	_is_telegraphing = true
	
	# Telegraph: flash white rapidly
	modulate = Color(1, 1, 1)
	await get_tree().create_timer(0.15).timeout
	modulate = Color(1.0, 0.3, 0.0)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)
	await get_tree().create_timer(0.1).timeout
	
	# Fire!
	if is_dead or not is_instance_valid(target):
		_is_telegraphing = false
		return
	
	var target_pos: Vector2 = TimeManager.get_enemy_target_position(target)
	var direction: Vector2 = (target_pos - global_position).normalized()
	
	var b: Node2D = bullet_scene.instantiate()
	b.global_position = global_position
	b.setup(direction, true)
	if "speed" in b:
		b.speed = 400.0
	
	var container: Node = get_tree().get_first_node_in_group("projectiles_container")
	if container:
		container.add_child(b)
	else:
		get_parent().add_child(b)
	
	# Muzzle flash
	modulate = Color(1, 1, 0.5)
	await get_tree().create_timer(0.05).timeout
	modulate = Color(1.0, 0.6, 0.0)
	
	_is_telegraphing = false

func take_damage(amount: float = 10.0) -> void:
	if is_dead:
		return
	health -= amount
	
	modulate = Color.WHITE
	await get_tree().create_timer(0.05).timeout
	if not is_dead:
		modulate = Color(1.0, 0.6, 0.0)
	
	if health <= 0.0:
		_die()

var _health_core_scene: PackedScene = preload("res://scenes/effects/health_core.tscn")

func _die() -> void:
	is_dead = true
	GameJuice.death_impact()
	GameJuice.spawn_death_particles(global_position, Color(1.0, 0.6, 0.0), 10)
	
	# Fracture reduction / lockdown exit
	TimeManager.on_enemy_killed()
	
	# 30% chance to drop a Health Core
	if randf() < 0.3:
		var core := _health_core_scene.instantiate()
		core.global_position = global_position
		get_tree().current_scene.add_child(core)
	
	enemy_died.emit(self)
	queue_free()
