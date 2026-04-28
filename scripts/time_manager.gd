extends Node

## The central time manipulation system for POLYCHRON.
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

# --- Timer & Deaths ---
var game_time: float = 0.0
var best_game_time: float = -1.0
var game_is_active: bool = false
var death_count: int = 0

# --- Audio Bus ---
var _gameplay_bus_idx: int = -1
var _lowpass_effect_idx: int = -1
var _timeability_bus_idx: int = -1

func _ready() -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	
	# Create "Gameplay" bus (child of Master) — all normal SFX/BGM route here
	AudioServer.add_bus()
	_gameplay_bus_idx = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(_gameplay_bus_idx, "Gameplay")
	AudioServer.set_bus_send(_gameplay_bus_idx, "Master")
	
	# Create LowPass filter on Gameplay bus (disabled by default)
	var lowpass = AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 800.0
	lowpass.resonance = 0.5
	AudioServer.add_bus_effect(_gameplay_bus_idx, lowpass)
	_lowpass_effect_idx = AudioServer.get_bus_effect_count(_gameplay_bus_idx) - 1
	AudioServer.set_bus_effect_enabled(_gameplay_bus_idx, _lowpass_effect_idx, false)
	
	# Create "TimeAbility" bus (child of Master directly — bypasses Gameplay effects)
	AudioServer.add_bus()
	_timeability_bus_idx = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(_timeability_bus_idx, "TimeAbility")
	AudioServer.set_bus_send(_timeability_bus_idx, "Master")

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
	AudioServer.playback_speed_scale = 1.0
	fracture_changed.emit(fracture_level)
	lockdown_changed.emit(false)
	time_gauge_changed.emit(time_gauge)
	time_state_changed.emit(current_state)

## Called ONLY from the Main Menu when starting a fresh game
func start_new_run() -> void:
	game_time = 0.0
	death_count = 0
	game_is_active = true
	reset_fracture(true)

# --- Process ---
func _process(delta: float) -> void:
	if not game_is_active or get_tree().paused:
		return
		
	# We use unscaled delta for gauge management so slowing time
	# doesn't also slow the gauge drain
	var real_delta: float = delta
	if Engine.time_scale > 0.0:
		real_delta = delta / Engine.time_scale
		
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
	GameJuice.play_sfx("res://assets/audio/resyncTime.wav", 0.0, 1.0, "TimeAbility")

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
			AudioServer.playback_speed_scale = 1.0
			_set_audio_normal()
		TimeState.STOPPED:
			# We keep Engine.time_scale at 1.0 so player can still move.
			# Enemies check TimeManager.current_state themselves.
			Engine.time_scale = 1.0
			AudioServer.playback_speed_scale = 1.0
			_set_audio_muffled()
		TimeState.SLOWED:
			Engine.time_scale = 0.2  # World slows to 20%
			# Audio slows down, but 0.2 pitch is too garbled, 0.5 sounds thick and warped.
			AudioServer.playback_speed_scale = 0.5
			_set_audio_normal()  # No extra effect beyond pitch
		TimeState.ERASED:
			Engine.time_scale = 1.0
			AudioServer.playback_speed_scale = 1.0
			_set_audio_silent()
	
	time_state_changed.emit(new_state)

## Muffled: LowPass enabled on Gameplay bus (underwater / dampened)
func _set_audio_muffled() -> void:
	if _lowpass_effect_idx >= 0:
		AudioServer.set_bus_effect_enabled(_gameplay_bus_idx, _lowpass_effect_idx, true)
	AudioServer.set_bus_volume_db(_gameplay_bus_idx, 0.0)

## Silent: Gameplay bus volume to -80dB (total silence for gameplay audio)
func _set_audio_silent() -> void:
	if _lowpass_effect_idx >= 0:
		AudioServer.set_bus_effect_enabled(_gameplay_bus_idx, _lowpass_effect_idx, false)
	AudioServer.set_bus_volume_db(_gameplay_bus_idx, -80.0)

## Normal: Disable all effects, restore volume
func _set_audio_normal() -> void:
	if _lowpass_effect_idx >= 0:
		AudioServer.set_bus_effect_enabled(_gameplay_bus_idx, _lowpass_effect_idx, false)
	AudioServer.set_bus_volume_db(_gameplay_bus_idx, 0.0)

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
