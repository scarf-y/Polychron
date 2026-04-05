extends CharacterBody2D

## Stalker Enemy — chases the player relentlessly.
## Freezes during TIME_STOP, slows with TIME_SLOW, loses sight during TIME_ERASE.

# --- Stats ---
@export var speed: float = 60.0
@export var health: int = 3
var is_dead: bool = false

# --- Contact Damage ---
const CONTACT_DAMAGE_COOLDOWN: float = 1.0
var _damage_timer: float = 0.0

# --- Signals ---
signal enemy_died(enemy: Node2D)

func _ready() -> void:
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Tick contact damage cooldown
	if _damage_timer > 0.0:
		_damage_timer -= delta
	
	# --- Time State Reactions ---
	match TimeManager.current_state:
		TimeManager.TimeState.STOPPED:
			# Frozen solid
			modulate = Color(0.3, 0.3, 0.3)
			return
		TimeManager.TimeState.ERASED:
			# Can't see the player — idle
			modulate = Color(1.0, 0.5, 0.5, 0.5)
			velocity = velocity.move_toward(Vector2.ZERO, speed)
			move_and_slide()
			return
		_:
			modulate = Color.RED
	
	# --- Chase Logic ---
	var player := get_tree().get_first_node_in_group("player")
	
	if player and is_instance_valid(player):
		var direction := (player.global_position - global_position).normalized()
		var distance := global_position.distance_to(player.global_position)
		
		if distance > 12.0:
			velocity = direction * speed
		else:
			velocity = Vector2.ZERO
			# Contact damage with cooldown
			if _damage_timer <= 0.0 and player.has_method("take_damage"):
				player.take_damage(1)
				_damage_timer = CONTACT_DAMAGE_COOLDOWN
		
		move_and_slide()

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	health -= amount
	
	# Flash white
	modulate = Color.WHITE
	await get_tree().create_timer(0.05).timeout
	if not is_dead:
		modulate = Color.RED
	
	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	enemy_died.emit(self)
	queue_free()
