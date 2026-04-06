extends Area2D

## Null Zone — Disables player's time abilities.
## Spawned by Dampener. Starts at 50px, grows for 2s, then vanishes.

# --- Config ---
const INITIAL_RADIUS: float = 50.0
const GROWTH_RADIUS: float = 80.0
const STABLE_DURATION: float = 3.0
const GROWTH_DURATION: float = 2.0

var _timer: float = 0.0
var _phase: int = 0  # 0 = stable, 1 = growing

# --- Visual ---
var _visual: ColorRect = null
var _current_radius: float = INITIAL_RADIUS
var _player_inside: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect player
	
	# Create collision shape
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INITIAL_RADIUS
	shape.shape = circle
	add_child(shape)
	
	# Create visual (flickering grid overlay)
	_visual = ColorRect.new()
	_visual.size = Vector2(INITIAL_RADIUS * 2, INITIAL_RADIUS * 2)
	_visual.position = Vector2(-INITIAL_RADIUS, -INITIAL_RADIUS)
	_visual.color = Color(0.8, 0, 0, 0.15)
	_visual.z_index = -2
	add_child(_visual)
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	_timer += delta
	
	# Flickering effect
	_visual.modulate.a = 0.5 + sin(_timer * 8.0) * 0.3
	
	if _phase == 0:
		# Stable phase (3 seconds)
		if _timer >= STABLE_DURATION:
			_phase = 1
			_timer = 0.0
	elif _phase == 1:
		# Growing phase (2 seconds)
		var growth_progress: float = _timer / GROWTH_DURATION
		_current_radius = lerpf(INITIAL_RADIUS, GROWTH_RADIUS, growth_progress)
		
		# Update collision shape
		var shape_node: CollisionShape2D = get_child(0) as CollisionShape2D
		if shape_node and shape_node.shape is CircleShape2D:
			(shape_node.shape as CircleShape2D).radius = _current_radius
		
		# Update visual
		_visual.size = Vector2(_current_radius * 2, _current_radius * 2)
		_visual.position = Vector2(-_current_radius, -_current_radius)
		
		# Turn more red/opaque as it grows
		_visual.color = Color(1.0, 0, 0, 0.15 + growth_progress * 0.15)
		
		if _timer >= GROWTH_DURATION:
			_vanish()

func _vanish() -> void:
	# Release player if inside
	if _player_inside:
		TimeManager.null_zone_active = false
	
	# Fade out
	var tween := create_tween()
	tween.tween_property(_visual, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		TimeManager.null_zone_active = true
		
		# Force cancel any active time ability
		if TimeManager.current_state != TimeManager.TimeState.NORMAL:
			TimeManager.change_time_state(TimeManager.TimeState.NORMAL)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		TimeManager.null_zone_active = false
