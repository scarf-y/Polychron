extends Node

## GameJuice — Global VFX utility for hitstop, screen shake, and damage numbers.
## Autoloaded as "GameJuice".

# --- Hitstop ---
var _hitstop_active: bool = false
var _saved_time_scale: float = 1.0

# --- Screen Shake ---
var _shake_camera: Camera2D = null
var _shake_intensity: float = 0.0
var _shake_decay: float = 8.0
var _shake_offset: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	_process_shake(delta)

# =========================
# HITSTOP
# =========================
func hitstop(duration_real: float = 0.08, freeze_scale: float = 0.05) -> void:
	if _hitstop_active:
		return
	
	_hitstop_active = true
	_saved_time_scale = Engine.time_scale
	Engine.time_scale = freeze_scale
	
	await get_tree().create_timer(duration_real * freeze_scale).timeout
	
	Engine.time_scale = _saved_time_scale
	_hitstop_active = false
	
	# Re-sync with TimeManager
	match TimeManager.current_state:
		TimeManager.TimeState.NORMAL:
			Engine.time_scale = 1.0
		TimeManager.TimeState.STOPPED:
			Engine.time_scale = 1.0
		TimeManager.TimeState.SLOWED:
			Engine.time_scale = 0.2
		TimeManager.TimeState.ERASED:
			Engine.time_scale = 1.0

# =========================
# SCREEN SHAKE
# =========================
func screen_shake(intensity: float = 4.0, x_bias: float = 1.5) -> void:
	_shake_intensity = intensity
	
	var viewport := get_viewport()
	if viewport:
		_shake_camera = viewport.get_camera_2d()
	
	if _shake_camera:
		_shake_camera.set_meta("x_bias", x_bias)

func _process_shake(delta: float) -> void:
	if not _shake_camera or _shake_intensity <= 0.01:
		if _shake_camera:
			_shake_camera.offset = Vector2.ZERO
		return
	
	var x_bias: float = 1.5
	if _shake_camera.has_meta("x_bias"):
		x_bias = _shake_camera.get_meta("x_bias")
	
	_shake_offset = Vector2(
		randf_range(-_shake_intensity, _shake_intensity) * x_bias,
		randf_range(-_shake_intensity, _shake_intensity)
	)
	
	_shake_camera.offset = _shake_offset
	_shake_intensity = lerpf(_shake_intensity, 0.0, delta * _shake_decay)
	
	if _shake_intensity < 0.1:
		_shake_intensity = 0.0
		_shake_camera.offset = Vector2.ZERO

# =========================
# FLOATING DAMAGE NUMBERS
# =========================
func spawn_damage_number(amount: float, pos: Vector2, is_crit: bool, color_override: Color = Color(-1, -1, -1), scale_override: float = 1.0) -> void:
	var label := Label.new()
	label.text = str(int(amount))
	label.global_position = pos + Vector2(randf_range(-8, 8), -10)
	label.z_index = 100
	
	# Check for color override (e.g. Stage IV fracture — purple + 2x)
	var has_override: bool = color_override.r >= 0.0
	
	# Style based on crit or override
	if has_override:
		label.add_theme_color_override("font_color", color_override)
		label.add_theme_font_size_override("font_size", int(12 * scale_override))
		label.scale = Vector2(scale_override, scale_override)
		label.text += "!!"
	elif is_crit:
		label.add_theme_color_override("font_color", Color(1, 0.9, 0.1))  # Bright gold
		label.add_theme_font_size_override("font_size", 14)
		label.scale = Vector2(1.5, 1.5)
		label.text += "!"
	else:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 10)
	
	get_tree().current_scene.add_child(label)
	
	# Pop-up tween: float up + fade out
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.tween_property(label, "scale", label.scale * 0.5, 0.6).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)

## Spawn a "BLOCKED" or "NULLIFIED" text
func spawn_blocked_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "BLOCKED"
	label.global_position = pos + Vector2(-20, -10)
	label.z_index = 100
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	label.add_theme_font_size_override("font_size", 8)
	
	get_tree().current_scene.add_child(label)
	
	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

# =========================
# DEATH EFFECT — Glitch Evaporation
# =========================
func spawn_death_particles(pos: Vector2, color: Color, count: int = 12) -> void:
	for i in count:
		var particle := ColorRect.new()
		var size: float = randf_range(2, 5)
		particle.size = Vector2(size, size)
		particle.color = color
		particle.global_position = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		# Random explosion direction
		var target_pos: Vector2 = particle.position + Vector2(
			randf_range(-40, 40),
			randf_range(-50, -10)
		)
		
		var tween := particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target_pos, randf_range(0.3, 0.6)).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, randf_range(0.3, 0.5)).set_delay(0.1)
		tween.tween_property(particle, "scale", Vector2.ZERO, randf_range(0.3, 0.6))
		# Glitch flicker
		tween.tween_property(particle, "modulate", Color(randf(), randf(), randf(), 0.8), 0.05).set_delay(0.05)
		tween.chain().tween_callback(particle.queue_free)

# =========================
# CONVENIENCE COMBOS
# =========================
func hit_impact() -> void:
	hitstop(0.08, 0.05)
	screen_shake(3.0, 1.5)

func crit_impact() -> void:
	hitstop(0.12, 0.03)
	screen_shake(5.0, 2.0)

func big_impact() -> void:
	hitstop(0.12, 0.02)
	screen_shake(6.0, 2.0)

func time_stop_impact() -> void:
	screen_shake(5.0, 1.8)

func death_impact() -> void:
	hitstop(0.15, 0.01)
	screen_shake(8.0, 2.0)
