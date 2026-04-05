extends CharacterBody2D

## Turret Enemy — static, fires bullets at intervals.
## Freezes during TIME_STOP. Slows with TIME_SLOW.

# --- Stats ---
@export var health: int = 5
@export var fire_interval: float = 2.0
@export var detection_range: float = 200.0
var is_dead: bool = false

# --- Shooting ---
var _fire_timer: float = 0.0
var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet.tscn")

# --- Signals ---
signal enemy_died(enemy: Node2D)

func _ready() -> void:
	add_to_group("enemies")
	_fire_timer = fire_interval  # Fire immediately on first detection

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# --- Time State Reactions ---
	match TimeManager.current_state:
		TimeManager.TimeState.STOPPED:
			modulate = Color(0.3, 0.3, 0.3)
			return  # Completely frozen
		TimeManager.TimeState.ERASED:
			modulate = Color(1.0, 0.6, 0.3, 0.5)
			return  # Can't see player
		_:
			modulate = Color(1.0, 0.5, 0.0)  # Orange
	
	# --- Turret Logic ---
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	
	var distance := global_position.distance_to(player.global_position)
	if distance > detection_range:
		return
	
	# Fire timer
	_fire_timer += delta
	if _fire_timer >= fire_interval:
		_fire_timer = 0.0
		_fire_at(player)

func _fire_at(target: Node2D) -> void:
	var direction := (target.global_position - global_position).normalized()
	
	var bullet := bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.setup(direction, true)  # true = enemy bullet
	
	var container := get_tree().get_first_node_in_group("projectiles_container")
	if container:
		container.add_child(bullet)
	else:
		get_parent().add_child(bullet)

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	health -= amount
	
	# Flash white
	modulate = Color.WHITE
	await get_tree().create_timer(0.05).timeout
	if not is_dead:
		modulate = Color(1.0, 0.5, 0.0)
	
	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	enemy_died.emit(self)
	queue_free()
