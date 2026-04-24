extends Area2D

## Projectile — used by Player and Enemies.
## Freezes during TIME_STOP. Player bullets use crit system.

# --- Collision Layer Map ---
# Layer 1: Walls    | Layer 2: Player
# Layer 3: Enemies  | Layer 4: Player Bullets | Layer 5: Enemy Bullets

# --- Config ---
const BULLET_SPEED: float = 250.0
const LIFETIME: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var is_enemy_bullet: bool = false

# --- Time Stop Storage ---
var _stored_direction: Vector2 = Vector2.ZERO
var _is_frozen: bool = false

func setup(dir: Vector2, enemy_bullet: bool = false) -> void:
	direction = dir.normalized()
	is_enemy_bullet = enemy_bullet
	rotation = direction.angle()
	
	if is_enemy_bullet:
		collision_layer = 16  # bit 4 = layer 5
		collision_mask = 3    # bits 0+1 = layers 1+2
	else:
		collision_layer = 8   # bit 3 = layer 4
		collision_mask = 5    # bits 0+2 = layers 1+3

func _ready() -> void:
	add_to_group("projectiles")
	
	body_entered.connect(_on_body_entered)
	
	var timer := Timer.new()
	timer.wait_time = LIFETIME
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

func _physics_process(delta: float) -> void:
	if TimeManager.current_state == TimeManager.TimeState.STOPPED:
		if not _is_frozen:
			_stored_direction = direction
			_is_frozen = true
			modulate = Color(0.5, 0.5, 0.5)
		return
	else:
		if _is_frozen:
			direction = _stored_direction
			_is_frozen = false
			modulate = Color.WHITE
	
	position += direction * BULLET_SPEED * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and is_enemy_bullet:
		if body.has_method("take_damage"):
			body.take_damage(15.0)  # Enemy bullets do fixed damage
		GameJuice.screen_shake(3.0, 1.2)
		queue_free()
	elif body.is_in_group("enemies") and not is_enemy_bullet:
		# Use player's crit system
		var player: Node = get_tree().get_first_node_in_group("player")
		var damage: float = 12.0
		var is_crit: bool = false
		
		if player and player.has_method("deal_damage"):
			var result: Array = player.deal_damage()
			damage = result[0]
			is_crit = result[1]
		
		# Check if enemy has damage reduction (Data Shield from Dampener)
		if body.has_method("get_damage_reduction"):
			var reduction: float = body.get_damage_reduction()
			if reduction > 0.0:
				damage *= (1.0 - reduction)
				is_crit = false  # Can't crit shielded targets
		
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		# Spawn floating damage number
		GameJuice.spawn_damage_number(damage, body.global_position, is_crit)
		
		# Impact effect
		if is_crit:
			GameJuice.crit_impact()
		else:
			GameJuice.hit_impact()
		
		queue_free()
	else:
		queue_free()
