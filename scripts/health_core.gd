extends Area2D

## Health Core — A healing pickup dropped by enemies.
## Glowing white-green square that heals the player on contact.
## Features spawn animation, pickup glow effect, and auto-destroy timer.

const HEAL_AMOUNT: float = 10.0
const LIFETIME: float = 8.0

var _pulse_tween: Tween = null

func _ready() -> void:
	# Set collision: detect Player (layer 2)
	collision_layer = 0
	collision_mask = 2  # Player layer
	
	body_entered.connect(_on_body_entered)
	
	# Build visual
	_create_visual()
	
	# Spawn animation
	_play_spawn_animation()
	
	# Auto-destroy timer with fade-out
	_start_lifetime_timer()

func _create_visual() -> void:
	# Glowing white-green square
	var core_visual := Polygon2D.new()
	core_visual.name = "CoreVisual"
	core_visual.polygon = PackedVector2Array([
		Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)
	])
	core_visual.color = Color(0.8, 1.0, 0.85, 0.9)
	core_visual.z_index = 10
	add_child(core_visual)
	
	# Outer glow ring
	var glow := Polygon2D.new()
	glow.name = "GlowRing"
	glow.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	glow.color = Color(0.3, 1.0, 0.5, 0.25)
	glow.z_index = 9
	add_child(glow)
	
	# Collision shape
	var col_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	col_shape.shape = circle
	add_child(col_shape)
	
	# Start pulsing glow
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(glow, "modulate:a", 0.6, 0.4).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(glow, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_IN_OUT)
	
	# Rotate the glow ring slowly
	var rotate_tween := create_tween().set_loops()
	rotate_tween.tween_property(glow, "rotation", TAU, 3.0).from(0.0)

func _play_spawn_animation() -> void:
	# Start small and invisible, pop into existence
	scale = Vector2.ZERO
	modulate.a = 0.0
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	
	# Spawn burst particles
	_spawn_particles(global_position, Color(0.3, 1.0, 0.5, 0.8), 6)

func _start_lifetime_timer() -> void:
	await get_tree().create_timer(LIFETIME - 2.0).timeout
	
	# Flicker warning before disappearing
	if not is_inside_tree():
		return
	var flicker_tween := create_tween().set_loops(10)
	flicker_tween.tween_property(self, "modulate:a", 0.2, 0.1)
	flicker_tween.tween_property(self, "modulate:a", 1.0, 0.1)
	
	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	# Heal the player
	if body.has_method("heal"):
		body.heal(HEAL_AMOUNT)
	
	# Pickup VFX: green glow around the player
	_play_pickup_effect(body)
	
	# Pickup burst particles
	_spawn_particles(global_position, Color(0.2, 1.0, 0.4, 0.9), 8)
	
	# Disable collision immediately so we don't double-trigger
	set_deferred("monitoring", false)
	
	# Quick scale-down and free
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)

func _play_pickup_effect(player: Node2D) -> void:
	# Create a green glow ring around the player that expands and fades
	var glow_ring := Polygon2D.new()
	var segments: int = 16
	var radius: float = 12.0
	var points: PackedVector2Array = PackedVector2Array()
	for i in segments:
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	glow_ring.polygon = points
	glow_ring.color = Color(0.2, 1.0, 0.4, 0.6)
	glow_ring.z_index = 50
	glow_ring.global_position = player.global_position
	get_tree().current_scene.add_child(glow_ring)
	
	# Expand and fade
	var tween := glow_ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(glow_ring, "scale", Vector2(3.0, 3.0), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow_ring, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(glow_ring.queue_free)
	
	# Also flash the player green briefly
	var original_modulate: Color = player.modulate
	player.modulate = Color(0.3, 1.0, 0.5, 1.0)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(player) and not player.is_dead:
		# Let the player's own _update_modulate handle the restoration
		if player.has_method("_update_modulate"):
			player._update_modulate()

func _spawn_particles(pos: Vector2, color: Color, count: int) -> void:
	for i in count:
		var particle := ColorRect.new()
		var size: float = randf_range(2, 4)
		particle.size = Vector2(size, size)
		particle.color = color
		particle.global_position = pos + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var target_pos: Vector2 = particle.position + Vector2(
			randf_range(-25, 25),
			randf_range(-30, -5)
		)
		
		var tween := particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target_pos, randf_range(0.3, 0.5)).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, randf_range(0.3, 0.5)).set_delay(0.1)
		tween.chain().tween_callback(particle.queue_free)
