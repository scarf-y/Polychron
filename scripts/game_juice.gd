extends Node

## GameJuice — Global VFX utility for hitstop and screen shake.
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
## Brief time freeze that makes hits feel heavy.
## duration_real = actual real-world seconds (not affected by time_scale)
func hitstop(duration_real: float = 0.08, freeze_scale: float = 0.05) -> void:
	if _hitstop_active:
		return  # Don't stack hitstops
	
	_hitstop_active = true
	_saved_time_scale = Engine.time_scale
	Engine.time_scale = freeze_scale
	
	# Wait in real time (not game time)
	await get_tree().create_timer(duration_real * freeze_scale).timeout
	
	# Restore previous time scale (respect TimeManager state)
	Engine.time_scale = _saved_time_scale
	_hitstop_active = false
	
	# Re-sync with TimeManager in case state changed during hitstop
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
## Shake the active camera. Higher intensity = bigger shake.
## x_bias makes horizontal shake stronger for cinematic feel.
func screen_shake(intensity: float = 4.0, x_bias: float = 1.5) -> void:
	_shake_intensity = intensity
	
	# Find the active camera
	var viewport := get_viewport()
	if viewport:
		_shake_camera = viewport.get_camera_2d()
	
	# Apply x_bias by storing it for the shake calculation
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
	
	# Random shake with x-axis bias
	_shake_offset = Vector2(
		randf_range(-_shake_intensity, _shake_intensity) * x_bias,
		randf_range(-_shake_intensity, _shake_intensity)
	)
	
	_shake_camera.offset = _shake_offset
	
	# Decay the shake
	_shake_intensity = lerpf(_shake_intensity, 0.0, delta * _shake_decay)
	
	if _shake_intensity < 0.1:
		_shake_intensity = 0.0
		_shake_camera.offset = Vector2.ZERO

# =========================
# CONVENIENCE COMBOS
# =========================
## Hit impact: hitstop + small shake. Call when a bullet hits an enemy.
func hit_impact() -> void:
	hitstop(0.08, 0.05)
	screen_shake(3.0, 1.5)

## Big impact: longer hitstop + heavy shake. Call on boss hits or explosions.
func big_impact() -> void:
	hitstop(0.12, 0.02)
	screen_shake(6.0, 2.0)

## Time stop activation: dramatic shake.
func time_stop_impact() -> void:
	screen_shake(5.0, 1.8)

## Death impact: maximum drama.
func death_impact() -> void:
	hitstop(0.15, 0.01)
	screen_shake(8.0, 2.0)
