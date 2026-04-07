extends Area2D

## Null Zone — Disables player's time abilities.
## Spawned by Dampener. Starts at 50px, grows for 2s, then vanishes.
## HIGHLY VISIBLE: red pulsing circle with border.

# --- Config ---
const INITIAL_RADIUS: float = 60.0
const GROWTH_RADIUS: float = 120.0
const STABLE_DURATION: float = 3.0
const GROWTH_DURATION: float = 2.0

var _timer: float = 0.0
var _phase: int = 0  # 0 = stable, 1 = growing

# --- Visual ---
var _fill: ColorRect = null
var _border_top: ColorRect = null
var _border_bottom: ColorRect = null
var _border_left: ColorRect = null
var _border_right: ColorRect = null
var _warning_label: Label = null
var _current_radius: float = INITIAL_RADIUS
var _player_inside: bool = false
var _collision_shape: CollisionShape2D = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect player
	
	# Create collision shape
	_collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INITIAL_RADIUS
	_collision_shape.shape = circle
	add_child(_collision_shape)
	
	# --- HIGHLY VISIBLE FILL ---
	_fill = ColorRect.new()
	_update_visual_size(INITIAL_RADIUS)
	_fill.color = Color(0.8, 0.0, 0.0, 0.25)
	_fill.z_index = 10
	add_child(_fill)
	
	# --- BRIGHT RED BORDER LINES ---
	_border_top = _create_border()
	_border_bottom = _create_border()
	_border_left = _create_border()
	_border_right = _create_border()
	_update_borders(INITIAL_RADIUS)
	
	# --- WARNING TEXT ---
	_warning_label = Label.new()
	_warning_label.text = "NULL ZONE"
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	_warning_label.add_theme_font_size_override("font_size", 8)
	_warning_label.position = Vector2(-25, -_current_radius - 12)
	_warning_label.z_index = 11
	add_child(_warning_label)
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _create_border() -> ColorRect:
	var border := ColorRect.new()
	border.color = Color(1.0, 0.1, 0.1, 0.8)
	border.z_index = 11
	add_child(border)
	return border

func _update_visual_size(radius: float) -> void:
	if _fill:
		_fill.size = Vector2(radius * 2, radius * 2)
		_fill.position = Vector2(-radius, -radius)

func _update_borders(radius: float) -> void:
	var thickness: float = 2.0
	if _border_top:
		_border_top.size = Vector2(radius * 2, thickness)
		_border_top.position = Vector2(-radius, -radius)
	if _border_bottom:
		_border_bottom.size = Vector2(radius * 2, thickness)
		_border_bottom.position = Vector2(-radius, radius - thickness)
	if _border_left:
		_border_left.size = Vector2(thickness, radius * 2)
		_border_left.position = Vector2(-radius, -radius)
	if _border_right:
		_border_right.size = Vector2(thickness, radius * 2)
		_border_right.position = Vector2(radius - thickness, -radius)

func _process(delta: float) -> void:
	_timer += delta
	
	# Pulsing effect — very visible
	var pulse: float = 0.6 + sin(_timer * 6.0) * 0.35
	if _fill:
		_fill.modulate.a = pulse
	
	# Flash border
	var border_pulse: float = 0.5 + sin(_timer * 10.0) * 0.5
	var border_color := Color(1.0, border_pulse * 0.3, 0.1, 0.7 + border_pulse * 0.3)
	for border in [_border_top, _border_bottom, _border_left, _border_right]:
		if border:
			border.color = border_color
	
	if _phase == 0:
		# Stable phase (3 seconds)
		if _timer >= STABLE_DURATION:
			_phase = 1
			_timer = 0.0
	elif _phase == 1:
		# Growing phase (2 seconds)
		var growth_progress: float = _timer / GROWTH_DURATION
		_current_radius = lerpf(INITIAL_RADIUS, GROWTH_RADIUS, growth_progress)
		
		# Update collision
		if _collision_shape and _collision_shape.shape is CircleShape2D:
			(_collision_shape.shape as CircleShape2D).radius = _current_radius
		
		# Update visuals
		_update_visual_size(_current_radius)
		_update_borders(_current_radius)
		
		# Fill gets more intense as it grows
		if _fill:
			_fill.color = Color(1.0, 0, 0, 0.2 + growth_progress * 0.2)
		
		# Update label position
		if _warning_label:
			_warning_label.position.y = -_current_radius - 12
		
		if _timer >= GROWTH_DURATION:
			_vanish()

func _vanish() -> void:
	if _player_inside:
		TimeManager.null_zone_active = false
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		TimeManager.null_zone_active = true
		
		# Force cancel any active time ability
		if TimeManager.current_state != TimeManager.TimeState.NORMAL:
			TimeManager.change_time_state(TimeManager.TimeState.NORMAL)
		
		# Visual feedback on player
		if body.has_method("_update_modulate"):
			body.modulate = Color(0.5, 0.5, 0.5, 0.7)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		TimeManager.null_zone_active = false
		
		# Restore player visual
		if body.has_method("_update_modulate"):
			body._update_modulate()
