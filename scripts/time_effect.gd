extends CanvasLayer

## Time Effect Manager — applies visual shaders based on current time state.
## Place in level scene. Listens to TimeManager signals.

@onready var stop_rect: ColorRect = $StopEffect
@onready var slow_rect: ColorRect = $SlowEffect 
@onready var erase_rect: ColorRect = $EraseEffect

var _transition_speed: float = 6.0
var _target_stop_intensity: float = 0.0
var _target_slow_intensity: float = 0.0
var _target_erase_intensity: float = 0.0
var _time_accumulator: float = 0.0

func _ready() -> void:
	layer = 100  # Render on top of everything
	TimeManager.time_state_changed.connect(_on_time_state_changed)
	
	# Initialize all effects to invisible
	_set_intensity(stop_rect, 0.0)
	_set_intensity(slow_rect, 0.0)
	_set_intensity(erase_rect, 0.0)

func _process(delta: float) -> void:
	_time_accumulator += delta
	
	# Smooth transitions for all effects
	_lerp_effect(stop_rect, _target_stop_intensity, delta)
	_lerp_effect(slow_rect, _target_slow_intensity, delta)
	_lerp_effect(erase_rect, _target_erase_intensity, delta)
	
	# Update time uniforms for animated shaders
	if slow_rect and slow_rect.material:
		(slow_rect.material as ShaderMaterial).set_shader_parameter("time_val", _time_accumulator)
	if erase_rect and erase_rect.material:
		(erase_rect.material as ShaderMaterial).set_shader_parameter("time_val", _time_accumulator)

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
