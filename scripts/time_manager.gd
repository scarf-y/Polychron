extends Node

## The central time manipulation system for Chronos Bound.
## Autoloaded as "TimeManager". Manages time states, Time Gauge, and Temporal Fracture.

# --- Enums ---
enum TimeState { NORMAL, STOPPED, SLOWED, ERASED }

# --- Signals ---
signal time_state_changed(new_state: TimeState)
signal time_gauge_changed(new_value: float)
signal time_gauge_depleted()
signal null_zone_changed(is_active: bool)
signal fracture_changed(new_value: float)
signal lockdown_changed(is_lockdown: bool)

# --- Time Gauge ---
const GAUGE_MAX: float = 100.0
const DRAIN_RATE_STOPPED: float = 25.0   # per second
const DRAIN_RATE_SLOWED: float = 15.0    # per second
const DRAIN_RATE_ERASED: float = 33.0    # per second
const RECHARGE_RATE: float = 10.0        # per second in NORMAL state

var time_gauge: float = GAUGE_MAX
var current_state: TimeState = TimeState.NORMAL
var null_zone_active: bool = false  # Set by Null Zone — disables abilities
var _null_zone_count: int = 0

# --- Temporal Fracture ---
const FRACTURE_MAX: float = 100.0
const FRACTURE_ACCUMULATE_RATE: float = 15.0  # per second while using abilities
const FRACTURE_DECAY_RATE: float = 1.5        # per second in NORMAL state (slow decay)
const FRACTURE_KILL_REDUCTION: float = 10.0   # per enemy kill

var fracture_level: float = 0.0
var is_lockdown: bool = false
var can_use_time: bool = true

var _lockdown_timer: float = 0.0
const LOCKDOWN_DURATION: float = 60.0

# --- Decoy Target (Time Erase) ---
var erased_target_position: Vector2 = Vector2.ZERO

# --- Persistent Player State ---
var player_health: float = 100.0

# --- Timer ---
var game_time: float = 0.0
var best_game_time: float = -1.0
var game_is_active: bool = false

## Reset all fracture state — call on scene reload / respawn
func reset_fracture(reset_hp: bool = false) -> void:
	if reset_hp:
		player_health = 100.0
		
	fracture_level = 0.0
	is_lockdown = false
	can_use_time = true
	_lockdown_timer = 0.0
	time_gauge = GAUGE_MAX
	current_state = TimeState.NORMAL
	Engine.time_scale = 1.0
	fracture_changed.emit(fracture_level)
	lockdown_changed.emit(false)
	time_gauge_changed.emit(time_gauge)
	time_state_changed.emit(current_state)

# --- Process ---
func _process(delta: float) -> void:
	# We use unscaled delta for gauge management so slowing time
	# doesn't also slow the gauge drain
	var real_delta: float = delta
	if Engine.time_scale > 0.0:
		real_delta = delta / Engine.time_scale
	
	if game_is_active:
		game_time += real_delta
	
	# --- Time Gauge Logic ---
	match current_state:
		TimeState.NORMAL:
			# Recharge gauge (blocked inside Null Zone)
			if time_gauge < GAUGE_MAX and not null_zone_active:
				time_gauge = minf(time_gauge + RECHARGE_RATE * real_delta, GAUGE_MAX)
				time_gauge_changed.emit(time_gauge)
		TimeState.STOPPED:
			time_gauge -= DRAIN_RATE_STOPPED * real_delta
			time_gauge_changed.emit(time_gauge)
			if time_gauge <= 0.0:
				time_gauge = 0.0
				_force_normal()
		TimeState.SLOWED:
			time_gauge -= DRAIN_RATE_SLOWED * real_delta
			time_gauge_changed.emit(time_gauge)
			if time_gauge <= 0.0:
				time_gauge = 0.0
				_force_normal()
		TimeState.ERASED:
			time_gauge -= DRAIN_RATE_ERASED * real_delta
			time_gauge_changed.emit(time_gauge)
			if time_gauge <= 0.0:
				time_gauge = 0.0
				_force_normal()
	
	# --- Fracture Logic ---
	_process_fracture(real_delta)

func _process_fracture(real_delta: float) -> void:
	if is_lockdown:
		_lockdown_timer += real_delta
		if _lockdown_timer >= LOCKDOWN_DURATION:
			_exit_lockdown()
		return  # Fracture stays at 100 during lockdown
	
	var old_fracture: float = fracture_level
	
	if current_state != TimeState.NORMAL:
		# Accumulate fracture while using time abilities
		fracture_level = minf(fracture_level + FRACTURE_ACCUMULATE_RATE * real_delta, FRACTURE_MAX)
	else:
		# Decay fracture when in NORMAL state
		fracture_level = maxf(fracture_level - FRACTURE_DECAY_RATE * real_delta, 0.0)
	
	# Only emit if changed meaningfully
	if absf(fracture_level - old_fracture) > 0.01:
		fracture_changed.emit(fracture_level)
	
	# Check lockdown trigger
	if fracture_level >= FRACTURE_MAX and not is_lockdown:
		_enter_lockdown()

func _enter_lockdown() -> void:
	is_lockdown = true
	can_use_time = false
	_lockdown_timer = 0.0
	fracture_level = FRACTURE_MAX
	fracture_changed.emit(fracture_level)
	lockdown_changed.emit(true)
	
	# Force back to NORMAL immediately
	if current_state != TimeState.NORMAL:
		_force_normal()

func _exit_lockdown() -> void:
	is_lockdown = false
	can_use_time = true
	_lockdown_timer = 0.0
	fracture_level = 75.0
	fracture_changed.emit(fracture_level)
	lockdown_changed.emit(false)

## Called when any enemy dies — reduces fracture and can exit lockdown
func on_enemy_killed() -> void:
	if is_lockdown:
		# Exit lockdown — the "clutch moment"
		_exit_lockdown()
	else:
		# Normal fracture reduction per kill
		fracture_level = maxf(fracture_level - FRACTURE_KILL_REDUCTION, 0.0)
		fracture_changed.emit(fracture_level)

func change_time_state(new_state: TimeState) -> void:
	# Don't allow activation if gauge is empty (except returning to NORMAL)
	if new_state != TimeState.NORMAL and time_gauge <= 0.0:
		return
	
	# Block time abilities during lockdown
	if new_state != TimeState.NORMAL and not can_use_time:
		return
	
	current_state = new_state
	
	match current_state:
		TimeState.NORMAL:
			Engine.time_scale = 1.0
		TimeState.STOPPED:
			# We keep Engine.time_scale at 1.0 so player can still move.
			# Enemies check TimeManager.current_state themselves.
			Engine.time_scale = 1.0
		TimeState.SLOWED:
			Engine.time_scale = 0.2  # World slows to 20%
		TimeState.ERASED:
			Engine.time_scale = 1.0
	
	time_state_changed.emit(new_state)

func _force_normal() -> void:
	time_gauge_depleted.emit()
	change_time_state(TimeState.NORMAL)

## Check if an ability can be activated (has gauge and not locked down)
func can_use_ability() -> bool:
	if null_zone_active:
		return false
	if not can_use_time:
		return false
	return time_gauge > 5.0  # Minimum threshold to activate

## Get the target position for enemies (fools enemies into attacking the decoy during ERASED)
func get_enemy_target_position(player: Node2D) -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO
	if current_state == TimeState.ERASED:
		return erased_target_position
	return player.global_position

# --- Null Zone Logic ---
func enter_null_zone() -> void:
	_null_zone_count += 1
	if _null_zone_count == 1:
		null_zone_active = true
		null_zone_changed.emit(true)

func exit_null_zone() -> void:
	_null_zone_count -= 1
	if _null_zone_count <= 0:
		_null_zone_count = 0
		null_zone_active = false
		null_zone_changed.emit(false)
