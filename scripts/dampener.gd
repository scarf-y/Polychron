extends CharacterBody2D

## Dampener — The Support. Pentagon shape with rotating ring.
## Doesn't attack HP. Attacks your TIME LOGIC.
## Drops Null Zones and tethers to Sentinels with Data Shield.

# --- Stats ---
@export var health: float = 80.0
@export var orbit_speed: float = 60.0
var is_dead: bool = false
var is_active_in_room: bool = true

# --- Null Zone ---
const NULL_ZONE_INTERVAL: float = 3.0
const NULL_ZONE_SCENE_PATH: String = "res://scenes/enemies/null_zone.tscn"
var _null_zone_timer: float = 1.5  # First zone drops at 1.5s
var null_zone_scene: PackedScene = null

# --- Data Shield ---
const TETHER_RANGE: float = 250.0
const DAMAGE_REDUCTION: float = 0.5  # 50% reduction
var _tethered_sentinels: Array[Node2D] = []

# --- Visual ---
var _ring_rotation: float = 0.0

# --- Signals ---
signal enemy_died(enemy: Node2D)

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("dampeners")
	
	# Load null zone scene
	if ResourceLoader.exists(NULL_ZONE_SCENE_PATH):
		null_zone_scene = load(NULL_ZONE_SCENE_PATH)

func _physics_process(delta: float) -> void:
	if is_dead or not is_active_in_room:
		return
	
	# Rotate the visual ring
	_ring_rotation += delta * 2.0
	queue_redraw() # Force a redraw for the tethers
	
	# --- Time State Reactions ---
	match TimeManager.current_state:
		TimeManager.TimeState.STOPPED:
			modulate = Color(0.3, 0.3, 0.3)
			return
		TimeManager.TimeState.ERASED:
			modulate = Color(0, 0.8, 0.7, 0.4)
		_:
			modulate = Color(0, 1.0, 0.8)  # Neon cyan
	
	# --- Null Zone Logic ---
	_null_zone_timer -= delta
	if _null_zone_timer <= 0.0:
		_null_zone_timer = NULL_ZONE_INTERVAL
		_drop_null_zone()
	
	# --- Data Shield Logic ---
	_update_tether()
	
	# Move towards the closest tethered sentinel to follow them
	if _tethered_sentinels.size() > 0:
		var target: Node2D = _tethered_sentinels[0]
		if is_instance_valid(target):
			var dist = global_position.distance_to(target.global_position)
			if dist > 80.0: # Keep a slight distance
				velocity = global_position.direction_to(target.global_position) * orbit_speed
			else:
				# Orbit it
				velocity = Vector2(cos(_ring_rotation), sin(_ring_rotation)) * orbit_speed
	else:
		# Just orbit in place
		velocity = Vector2(cos(_ring_rotation), sin(_ring_rotation)) * orbit_speed
		
	move_and_slide()

func _draw() -> void:
	if is_dead or not is_active_in_room:
		return
	var pulse: float = 0.5 + sin(_ring_rotation * 3.0) * 0.3
	var c := Color(0, 0.8, 1.0, pulse)
	for s in _tethered_sentinels:
		if is_instance_valid(s):
			draw_line(Vector2.ZERO, to_local(s.global_position), c, 1.5)

func _drop_null_zone() -> void:
	# Spawn near the player, not on the Dampener
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player or not is_instance_valid(player):
		return
	
	# Random offset from player (30-60px away in a random direction)
	var offset_dir := Vector2.from_angle(randf() * TAU)
	var offset_dist := randf_range(30.0, 60.0)
	var spawn_pos: Vector2 = player.global_position + offset_dir * offset_dist
	
	if null_zone_scene:
		var zone := null_zone_scene.instantiate()
		zone.global_position = spawn_pos
		get_tree().current_scene.add_child(zone)
	else:
		null_zone_scene = load(NULL_ZONE_SCENE_PATH)
		if null_zone_scene:
			var zone := null_zone_scene.instantiate()
			zone.global_position = spawn_pos
			get_tree().current_scene.add_child(zone)

func _update_tether() -> void:
	# Clear old tethers' explicitly if they exist and are valid
	for old_s in _tethered_sentinels:
		if is_instance_valid(old_s):
			old_s.damage_reduction = 0.0
	
	var new_tethers: Array[Node2D] = []
	var nodes := get_tree().get_nodes_in_group("enemies")
	
	# Find all sentinels in range
	for node in nodes:
		if node == self or not is_instance_valid(node):
			continue
		if node.get_script() and node.has_method("get_damage_reduction"):
			if global_position.distance_to(node.global_position) < TETHER_RANGE:
				new_tethers.append(node)
	
	# Try to sort the new tethers by distance so [0] is closest
	new_tethers.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	
	# Update active list
	_tethered_sentinels = new_tethers
	
	# Re-apply shield to all in range
	for s in _tethered_sentinels:
		if is_instance_valid(s):
			s.damage_reduction = DAMAGE_REDUCTION

func take_damage(amount: float = 10.0) -> void:
	if is_dead:
		return
	health -= amount
	
	modulate = Color.WHITE
	await get_tree().create_timer(0.05).timeout
	if not is_dead:
		modulate = Color(0, 1.0, 0.8)
	
	if health <= 0.0:
		_die()

var _health_core_scene: PackedScene = preload("res://scenes/effects/health_core.tscn")

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Remove shields
	for s in _tethered_sentinels:
		if is_instance_valid(s):
			s.damage_reduction = 0.0
	
	# Fracture reduction / lockdown exit
	TimeManager.on_enemy_killed()
	
	# 30% chance to drop a Health Core
	if randf() < 0.3:
		var core := _health_core_scene.instantiate()
		core.global_position = global_position
		get_tree().current_scene.add_child(core)
	
	enemy_died.emit(self)
	
	# GameJuice glitch particles
	GameJuice.spawn_death_particles(global_position, Color(0, 1.0, 0.8))
	GameJuice.screen_shake(2.0, 0.15)
	
	# Score
	var hud: CanvasLayer = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("add_chrono"):
		hud.add_chrono(20)
	
	queue_free()
