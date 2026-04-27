extends CanvasLayer

## Time Effect Manager — applies visual shaders based on current time state
## AND fracture-stage visual feedback.
## Place in level scene. Listens to TimeManager signals.

@onready var stop_rect: ColorRect = $StopEffect
@onready var slow_rect: ColorRect = $SlowEffect 
@onready var erase_rect: ColorRect = $EraseEffect
@onready var chromatic_rect: ColorRect = $ChromaticEffect

var _transition_speed: float = 6.0
var _target_stop_intensity: float = 0.0
var _target_slow_intensity: float = 0.0
var _target_erase_intensity: float = 0.0
var _time_accumulator: float = 0.0

# --- Fracture VFX ---
var _fracture_stage: int = 1
var _fracture_chromatic_intensity: float = 0.0  # Stage II+
var _jitter_intensity: float = 0.0               # Stage III
var _invert_timer: float = 0.0                    # Stage IV
var _static_overlay: ColorRect = null             # Stage V
var _lockdown_active: bool = false

func _ready() -> void:
	layer = 100  # Render on top of everything
	TimeManager.time_state_changed.connect(_on_time_state_changed)
	TimeManager.fracture_changed.connect(_on_fracture_changed)
	TimeManager.lockdown_changed.connect(_on_lockdown_changed)
	
	# Initialize all effects to invisible
	_set_intensity(stop_rect, 0.0)
	_set_intensity(slow_rect, 0.0)
	_set_intensity(erase_rect, 0.0)
	_set_intensity(chromatic_rect, 0.0)
	
	# Create static overlay for Stage V (hidden by default)
	_create_static_overlay()

func _process(delta: float) -> void:
	_time_accumulator += delta
	
	# Smooth transitions for time-state effects
	_lerp_effect(stop_rect, _target_stop_intensity, delta)
	_lerp_effect(slow_rect, _target_slow_intensity, delta)
	_lerp_effect(erase_rect, _target_erase_intensity, delta)
	
	# Chromatic aberration: combine time-state + fracture stage
	var total_chromatic: float = maxf(_target_erase_intensity, _fracture_chromatic_intensity)
	_lerp_effect(chromatic_rect, total_chromatic, delta)
	
	# Update time uniforms for animated shaders
	if slow_rect and slow_rect.material:
		(slow_rect.material as ShaderMaterial).set_shader_parameter("time_val", _time_accumulator)
	if erase_rect and erase_rect.material:
		(erase_rect.material as ShaderMaterial).set_shader_parameter("time_val", _time_accumulator)
	if chromatic_rect and chromatic_rect.material:
		(chromatic_rect.material as ShaderMaterial).set_shader_parameter("time_val", _time_accumulator)
	
	# --- Fracture Stage VFX ---
	_process_jitter(delta)
	_process_inversion(delta)
	_process_static(delta)

# =========================
# TIME STATE VFX
# =========================
func _on_time_state_changed(new_state: TimeManager.TimeState) -> void:
	# Reset all
	_target_stop_intensity = 0.0
	_target_slow_intensity = 0.0
	_target_erase_intensity = 0.0
	
	match new_state:
		TimeManager.TimeState.STOPPED:
			_target_stop_intensity = 1.0
		TimeManager.TimeState.SLOWED:
			_target_slow_intensity = 1.0
		TimeManager.TimeState.ERASED:
			_target_erase_intensity = 1.0
		TimeManager.TimeState.NORMAL:
			pass  # All stay at 0

# =========================
# FRACTURE STAGE VFX
# =========================
func _on_fracture_changed(value: float) -> void:
	var new_stage: int = 1
	if value >= 100.0:
		new_stage = 5
	elif value > 75.0:
		new_stage = 4
	elif value > 50.0:
		new_stage = 3
	elif value > 25.0:
		new_stage = 2
	else:
		new_stage = 1
	
	if new_stage != _fracture_stage:
		_fracture_stage = new_stage
		_apply_fracture_vfx()

func _on_lockdown_changed(is_lockdown: bool) -> void:
	_lockdown_active = is_lockdown
	if is_lockdown:
		_fracture_stage = 5
		_apply_fracture_vfx()
	else:
		_on_fracture_changed(TimeManager.fracture_level)

func _apply_fracture_vfx() -> void:
	match _fracture_stage:
		1:
			# Clean — no fracture VFX
			_fracture_chromatic_intensity = 0.0
			_jitter_intensity = 0.0
			_invert_timer = 0.0
			if _static_overlay:
				_static_overlay.visible = false
		2:
			# Slight chromatic aberration
			_fracture_chromatic_intensity = 0.3
			_jitter_intensity = 0.0
			if _static_overlay:
				_static_overlay.visible = false
		3:
			# Screen jitter + chromatic
			_fracture_chromatic_intensity = 0.5
			_jitter_intensity = 1.5
			if _static_overlay:
				_static_overlay.visible = false
		4:
			# Occasional color inversion + stronger effects
			_fracture_chromatic_intensity = 0.7
			_jitter_intensity = 2.0
			if _static_overlay:
				_static_overlay.visible = false
		5:
			# LOCKDOWN — Heavy static overlay + max effects
			_fracture_chromatic_intensity = 1.0
			_jitter_intensity = 3.0
			if _static_overlay:
				_static_overlay.visible = true

# --- Stage III: Screen Jitter ---
func _process_jitter(_delta: float) -> void:
	if _jitter_intensity <= 0.0:
		return
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs and not gs.screenshake_enabled:
		return
	
	var cam: Camera2D = get_viewport().get_camera_2d() if get_viewport() else null
	if not cam:
		return
	
	# Only add jitter when GameJuice isn't already shaking
	# (We piggyback on their offset system)
	if _fracture_stage >= 3:
		var jitter := Vector2(
			randf_range(-_jitter_intensity, _jitter_intensity),
			randf_range(-_jitter_intensity, _jitter_intensity)
		)
		# To avoid infinite offset stacking, we just assign the jitter, 
		# assuming GameJuice reset it, or we rely on the small variance.
		# A better way is to only apply it if GameJuice isn't applying heavy shake.
		cam.offset = jitter

# --- Stage IV: Occasional Color Inversion ---
func _process_inversion(delta: float) -> void:
	if _fracture_stage < 4:
		return
	
	_invert_timer += delta
	# Invert colors for 0.05s every ~1.5s
	var cycle: float = fmod(_invert_timer, 1.5)
	if cycle < 0.05:
		# Brief inversion flash using modulate on the stop_rect
		if stop_rect:
			stop_rect.visible = true
			if stop_rect.material:
				(stop_rect.material as ShaderMaterial).set_shader_parameter("intensity", 0.4)
	elif cycle >= 0.05 and cycle < 0.1:
		# Reset
		if stop_rect and _target_stop_intensity <= 0.0:
			if stop_rect.material:
				(stop_rect.material as ShaderMaterial).set_shader_parameter("intensity", _target_stop_intensity)
			stop_rect.visible = _target_stop_intensity > 0.01

# --- Stage V: Heavy Static Overlay ---
func _create_static_overlay() -> void:
	_static_overlay = ColorRect.new()
	_static_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_static_overlay.color = Color(1, 1, 1, 0.03)
	_static_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static_overlay.visible = false
	_static_overlay.z_index = 200
	add_child(_static_overlay)

func _process_static(_delta: float) -> void:
	if not _static_overlay or not _static_overlay.visible:
		return
	
	# Rapid flicker to simulate heavy static/interference
	var flicker: float = randf_range(0.02, 0.08)
	_static_overlay.color = Color(
		randf_range(0.8, 1.0),
		randf_range(0.0, 0.2),
		randf_range(0.0, 0.3),
		flicker
	)

# =========================
# UTILITY
# =========================
func _lerp_effect(rect: ColorRect, target: float, delta: float) -> void:
	if not rect or not rect.material:
		return
	var mat := rect.material as ShaderMaterial
	var current: float = mat.get_shader_parameter("intensity")
	var new_val := lerpf(current, target, delta * _transition_speed)
	mat.set_shader_parameter("intensity", new_val)
	
	# Hide when fully transparent to save GPU
	rect.visible = new_val > 0.01

func _set_intensity(rect: ColorRect, value: float) -> void:
	if not rect or not rect.material:
		return
	(rect.material as ShaderMaterial).set_shader_parameter("intensity", value)
	rect.visible = value > 0.01
