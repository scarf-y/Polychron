extends Node2D

## Laser Hazard — a beam that damages the player on contact.
## Player can phase through during TIME_ERASE.
## Visually represented as a red line.

# --- Config ---
@export var damage: int = 1
@export var beam_length: float = 80.0
@export var blink_speed: float = 2.0

# --- State ---
var _blink_timer: float = 0.0
var _is_visible_phase: bool = true
var _damage_cooldown: float = 0.0
const DAMAGE_COOLDOWN_TIME: float = 0.8

@onready var line: Line2D = $Line2D
@onready var area: Area2D = $HitArea

func _ready() -> void:
	# Setup the visual line
	if line:
		line.clear_points()
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2(beam_length, 0))
		line.width = 2.0
		line.default_color = Color.RED
	
	# Connect hit detection
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

var _player_in_beam: Node2D = null

func _process(delta: float) -> void:
	# Blink effect
	_blink_timer += delta * blink_speed
	_is_visible_phase = sin(_blink_timer * PI) > 0.0
	
	if line:
		line.default_color = Color.RED if _is_visible_phase else Color(1, 0, 0, 0.3)
	
	# Damage cooldown
	if _damage_cooldown > 0.0:
		_damage_cooldown -= delta
	
	# During TIME_ERASE, laser can't hurt player
	if TimeManager.current_state == TimeManager.TimeState.ERASED:
		if line:
			line.default_color = Color(1, 0, 0, 0.1)
		return
	
	# During TIME_STOP, laser freezes (no damage ticking)
	if TimeManager.current_state == TimeManager.TimeState.STOPPED:
		return
	
	# Apply damage to player in beam
	if _player_in_beam and is_instance_valid(_player_in_beam) and _damage_cooldown <= 0.0:
		if _player_in_beam.has_method("take_damage"):
			_player_in_beam.take_damage(damage)
			_damage_cooldown = DAMAGE_COOLDOWN_TIME

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_beam = body

func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_beam:
		_player_in_beam = null
