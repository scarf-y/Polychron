extends AnimatableBody2D

## Crusher Hazard — slides back and forth, damages player on contact.
## Freezes during TIME_STOP. Player phases through during TIME_ERASE.

# --- Config ---
@export var move_distance: float = 64.0
@export var move_speed: float = 40.0
@export var pause_duration: float = 0.5
@export var damage: int = 2

# --- State ---
var _start_position: Vector2
var _end_position: Vector2
var _moving_forward: bool = true
var _is_paused: bool = false
var _pause_timer: float = 0.0
var _damage_cooldown: float = 0.0
const DAMAGE_COOLDOWN_TIME: float = 1.0

func _ready() -> void:
	_start_position = global_position
	_end_position = _start_position + Vector2(move_distance, 0)
	
	# Connect contact detection via Area2D child
	var hit_area := get_node_or_null("HitArea") as Area2D
	if hit_area:
		hit_area.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Damage cooldown
	if _damage_cooldown > 0.0:
		_damage_cooldown -= delta
	
	# Freeze during TIME_STOP
	if TimeManager.current_state == TimeManager.TimeState.STOPPED:
		modulate = Color(0.3, 0.3, 0.3)
		return
	else:
		modulate = Color(0.6, 0.6, 0.6)
	
	# Handle pause at endpoints
	if _is_paused:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_is_paused = false
			_moving_forward = not _moving_forward
		return
	
	# Move
	var target := _end_position if _moving_forward else _start_position
	var direction := (target - global_position).normalized()
	var distance_to_target := global_position.distance_to(target)
	
	if distance_to_target < move_speed * delta:
		global_position = target
		_is_paused = true
		_pause_timer = pause_duration
	else:
		global_position += direction * move_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if TimeManager.current_state == TimeManager.TimeState.ERASED:
		return  # Player is phasing through
	
	if body.is_in_group("player") and _damage_cooldown <= 0.0:
		if body.has_method("take_damage"):
			body.take_damage(damage)
			_damage_cooldown = DAMAGE_COOLDOWN_TIME
