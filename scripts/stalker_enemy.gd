extends CharacterBody2D

## Stalker Enemy — relentless chaser with visible attack telegraph.
## Triangle shape. Glows red when about to strike.

# --- Stats ---
@export var speed: float = 60.0
@export var health: float = 80.0
var is_dead: bool = false
var is_active_in_room: bool = true

# --- Contact Damage ---
const CONTACT_DAMAGE: float = 18.0
const CONTACT_DAMAGE_COOLDOWN: float = 1.0
var _damage_timer: float = 0.0

# --- Attack Telegraph ---
var _is_attacking: bool = false
const LUNGE_SPEED: float = 200.0
const LUNGE_DURATION: float = 0.2
const ATTACK_RANGE: float = 50.0
const ATTACK_COOLDOWN: float = 1.5
var _attack_cooldown_timer: float = 0.0

# --- Signals ---
signal enemy_died(enemy: Node2D)

func _ready() -> void:
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if is_dead or not is_active_in_room:
		return
	
	# Tick cooldowns
	if _damage_timer > 0.0:
		_damage_timer -= delta
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
	
	# --- Time State Reactions ---
	match TimeManager.current_state:
		TimeManager.TimeState.STOPPED:
			modulate = Color(0.3, 0.3, 0.3)
			return
		TimeManager.TimeState.ERASED:
			modulate = Color(1.0, 0.3, 0.3, 0.4)
		_:
			if not _is_attacking:
				modulate = Color(1.0, 0.2, 0.2)  # Neon red
	
	# --- Chase Logic ---
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	
	if player and is_instance_valid(player):
		var target_pos: Vector2 = TimeManager.get_enemy_target_position(player)
		var direction: Vector2 = (target_pos - global_position).normalized()
		var distance: float = global_position.distance_to(target_pos)
		
		if distance <= ATTACK_RANGE and _attack_cooldown_timer <= 0.0 and not _is_attacking:
			# Telegraph: flash bright yellow before lunging
			_perform_lunge(direction, player)
		elif distance > 20.0 and not _is_attacking:
			velocity = direction * speed
		else:
			if not _is_attacking:
				velocity = Vector2.ZERO
				# Contact damage handled naturally, since Time Erase disables damage inside player anyway
				if _damage_timer <= 0.0 and global_position.distance_to(player.global_position) <= 20.0 and player.has_method("take_damage"):
					player.take_damage(CONTACT_DAMAGE)
					_damage_timer = CONTACT_DAMAGE_COOLDOWN
		
		move_and_slide()

func _perform_lunge(direction: Vector2, player: Node2D) -> void:
	_is_attacking = true
	_attack_cooldown_timer = ATTACK_COOLDOWN
	
	# Telegraph: flash yellow for 0.3s
	modulate = Color(1, 1, 0)  # Bright yellow warning
	await get_tree().create_timer(0.3).timeout
	
	# Lunge!
	modulate = Color(1, 0, 0)  # Bright red during attack
	velocity = direction * LUNGE_SPEED
	GameJuice.screen_shake(2.0, 1.5)
	
	await get_tree().create_timer(LUNGE_DURATION).timeout
	
	# Check if we hit the player during lunge
	if player and is_instance_valid(player):
		var dist: float = global_position.distance_to(player.global_position)
		if dist < 24.0 and player.has_method("take_damage"):
			player.take_damage(CONTACT_DAMAGE)
			GameJuice.screen_shake(4.0, 2.0)
	
	_is_attacking = false
	modulate = Color(1.0, 0.2, 0.2)

func take_damage(amount: float = 10.0) -> void:
	if is_dead:
		return
	health -= amount
	
	modulate = Color.WHITE
	await get_tree().create_timer(0.05).timeout
	if not is_dead:
		modulate = Color(1.0, 0.2, 0.2)
	
	if health <= 0.0:
		_die()

var _health_core_scene: PackedScene = preload("res://scenes/effects/health_core.tscn")

func _die() -> void:
	is_dead = true
	GameJuice.big_impact()
	GameJuice.spawn_death_particles(global_position, Color(1.0, 0.2, 0.2), 10)
	
	# Fracture reduction / lockdown exit
	TimeManager.on_enemy_killed()
	
	# 30% chance to drop a Health Core
	if randf() < 0.3:
		var core := _health_core_scene.instantiate()
		core.global_position = global_position
		get_tree().current_scene.add_child(core)
	
	enemy_died.emit(self)
	queue_free()
