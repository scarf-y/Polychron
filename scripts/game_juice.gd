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
# AUDIO SFX
# =========================
func play_sfx(stream_path: String, volume_db: float = 0.0, pitch: float = 1.0, bus: String = "Gameplay") -> void:
	var stream = load(stream_path)
	if not stream:
		return
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = bus
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

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
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs and not gs.screenshake_enabled:
		return
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
func spawn_damage_number(amount: float, pos: Vector2, is_crit: bool, color_override: Color = Color(-1, -1, -1), scale_override: float = 1.0, suffix: String = "") -> void:
	var label := Label.new()
	label.text = str(int(amount)) + suffix
	label.global_position = pos + Vector2(randf_range(-8, 8), -10)
	label.z_index = 100
	
	# Check for color override
	var has_override: bool = color_override.r >= 0.0
	
	# Style based on crit or override
	if has_override:
		label.add_theme_color_override("font_color", color_override)
		label.add_theme_font_size_override("font_size", int(12 * scale_override))
		label.scale = Vector2(scale_override, scale_override)
	elif is_crit:
		label.add_theme_color_override("font_color", Color(0.8, 0.2, 1.0)) # Neon Purple
		label.add_theme_font_size_override("font_size", 14)
		label.scale = Vector2(1.5, 1.5)
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

## Spawn a "LOCKED OUT" or "NULLIFIED" text with visual emphasis
func spawn_blocked_text(pos: Vector2) -> void:
	var label := Label.new()
	var is_lockdown: bool = TimeManager.is_lockdown
	
	if is_lockdown:
		label.text = "⚠ LOCKED OUT ⚠"
		label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
		label.add_theme_font_size_override("font_size", 11)
	else:
		label.text = "NULLIFIED"
		label.add_theme_color_override("font_color", Color(0.6, 0.0, 0.0))
		label.add_theme_font_size_override("font_size", 9)
	
	label.global_position = pos + Vector2(-30, -18)
	label.z_index = 100
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	get_tree().current_scene.add_child(label)
	
	# Pop up and fade with a shake feel
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 25.0, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.3)
	# Quick scale pop
	label.scale = Vector2(1.3, 1.3)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(label.queue_free)

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
	hitstop(0.1, 0.01)
	screen_shake(6.0, 2.0)
	play_sfx("res://assets/audio/deathExplosion.wav", -4.0, randf_range(0.9, 1.1))

# =========================
# LOCKDOWN FLICKER
# =========================
var _lockdown_flicker_tween: Tween = null

## Start the lockdown flicker on a target node (player)
## Oscillates modulate.a between 0.2 and 1.0 every 0.05s
func start_lockdown_flicker(target: Node2D) -> void:
	stop_lockdown_flicker()
	if not is_instance_valid(target):
		return
	_lockdown_flicker_tween = create_tween().set_loops()
	_lockdown_flicker_tween.tween_property(target, "modulate:a", 0.2, 0.05)
	_lockdown_flicker_tween.tween_property(target, "modulate:a", 1.0, 0.05)

## Stop the lockdown flicker
func stop_lockdown_flicker() -> void:
	if _lockdown_flicker_tween and _lockdown_flicker_tween.is_valid():
		_lockdown_flicker_tween.kill()
		_lockdown_flicker_tween = null

func lockdown_impact() -> void:
	screen_shake(6.0, 2.5)
	hitstop(0.2, 0.02)

# =========================
# LEVEL TRANSITION (GLITCH EFFECT)
# =========================
var _transition_active: bool = false

func transition_to_scene(path: String) -> void:
	if _transition_active:
		return
	_transition_active = true
	
	# Create canvas layer for top-level rendering
	var canvas := CanvasLayer.new()
	canvas.layer = 120
	get_tree().root.add_child(canvas)
	
	# Create ColorRect to fill screen
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(0, 0, 0, 0)
	canvas.add_child(rect)
	
	# Play transition sound / shake
	screen_shake(8.0, 2.0)
	
	# Glitch sequence
	var tween := create_tween()
	
	# Fast rapid flashes
	for i in range(10):
		tween.tween_callback(func():
			rect.color = Color(randf_range(0, 1), randf_range(0, 0.5), randf_range(0.5, 1), randf_range(0.3, 0.8))
		)
		tween.tween_interval(0.05)
	
	# Solid black
	tween.tween_callback(func(): rect.color = Color.BLACK)
	tween.tween_interval(0.3)
	
	# Change scene
	tween.tween_callback(func():
		get_tree().change_scene_to_file(path)
	)
	
	# Wait for scene to load
	tween.tween_interval(0.1)
	
	# Glitch fade in
	for i in range(5):
		tween.tween_callback(func():
			rect.color = Color(randf_range(0, 1), randf_range(0, 0.5), randf_range(0.5, 1), randf_range(0.1, 0.4))
		)
		tween.tween_interval(0.05)
		
	# Fade out completely
	tween.tween_property(rect, "color", Color(0, 0, 0, 0), 0.3)
	
	# Cleanup
	tween.tween_callback(func():
		canvas.queue_free()
		_transition_active = false
	)
