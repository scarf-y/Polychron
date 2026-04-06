extends CharacterBody2D

## Dampener — The Support. Pentagon shape with rotating ring.
## Doesn't attack HP. Attacks your TIME LOGIC.
## Drops Null Zones and tethers to Sentinels with Data Shield.

# --- Stats ---
@export var health: float = 30.0
@export var orbit_speed: float = 20.0
var is_dead: bool = false

# --- Null Zone ---
const NULL_ZONE_INTERVAL: float = 6.0
const NULL_ZONE_SCENE_PATH: String = "res://scenes/enemies/null_zone.tscn"
var _null_zone_timer: float = 3.0  # First zone drops at 3s
var null_zone_scene: PackedScene = null

# --- Data Shield ---
const TETHER_RANGE: float = 120.0
const DAMAGE_REDUCTION: float = 0.5  # 50% reduction
var _tethered_sentinel: Node2D = null
var _tether_line: Line2D = null

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
	
	# Create tether line
	_tether_line = Line2D.new()
	_tether_line.width = 1.5
	_tether_line.default_color = Color(0, 0.8, 1.0, 0.6)
	_tether_line.z_index = 3
	_tether_line.visible = false
	add_child(_tether_line)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Rotate the visual ring
	_ring_rotation += delta * 2.0
	
	# --- Time State Reactions ---
	match TimeManager.current_state:
		TimeManager.TimeState.STOPPED:
			modulate = Color(0.3, 0.3, 0.3)
			return
		TimeManager.TimeState.ERASED:
			modulate = Color(0, 0.8, 0.7, 0.4)
			return
		_:
			modulate = Color(0, 1.0, 0.8)  # Neon cyan
	
	# --- Null Zone Logic ---
	_null_zone_timer -= delta
	if _null_zone_timer <= 0.0:
		_null_zone_timer = NULL_ZONE_INTERVAL
		_drop_null_zone()
	
	# --- Data Shield Logic ---
	_update_tether()
	
	# Dampener doesn't chase — it orbits slowly in place
	velocity = Vector2(cos(_ring_rotation), sin(_ring_rotation)) * orbit_speed
	move_and_slide()

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
	# Find nearest Sentinel
	var nearest_sentinel: Node2D = null
	var nearest_dist: float = TETHER_RANGE
	
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not is_instance_valid(node):
			continue
		if node.get_script() and node.has_method("get_damage_reduction"):
			var dist: float = global_position.distance_to(node.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_sentinel = node
	
	# Update tether
	if nearest_sentinel and is_instance_valid(nearest_sentinel):
		if _tethered_sentinel != nearest_sentinel:
			# Remove old tether
			if _tethered_sentinel and is_instance_valid(_tethered_sentinel):
				_tethered_sentinel.damage_reduction = 0.0
			_tethered_sentinel = nearest_sentinel
		
		# Apply shield
		_tethered_sentinel.damage_reduction = DAMAGE_REDUCTION
		
		# Draw tether line
		_tether_line.visible = true
		_tether_line.clear_points()
		_tether_line.add_point(Vector2.ZERO)
		_tether_line.add_point(nearest_sentinel.global_position - global_position)
		
		# Pulse the tether
		_tether_line.modulate.a = 0.5 + sin(_ring_rotation * 3.0) * 0.3
	else:
		_tether_line.visible = false
		if _tethered_sentinel and is_instance_valid(_tethered_sentinel):
			_tethered_sentinel.damage_reduction = 0.0
		_tethered_sentinel = null

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

func _die() -> void:
	is_dead = true
	
	# Release tether with spark effect
	if _tethered_sentinel and is_instance_valid(_tethered_sentinel):
		_tethered_sentinel.damage_reduction = 0.0
		GameJuice.spawn_death_particles(
			(_tethered_sentinel.global_position + global_position) / 2.0,
			Color(0, 0.8, 1.0), 6
		)
	
	GameJuice.big_impact()
	GameJuice.spawn_death_particles(global_position, Color(0, 1.0, 0.8), 12)
	enemy_died.emit(self)
	queue_free()
