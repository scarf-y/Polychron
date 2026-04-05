extends Node

## The central time manipulation system for Chronos Bound.
## Autoloaded as "TimeManager". Manages time states and the Time Gauge resource.

# --- Enums ---
enum TimeState { NORMAL, STOPPED, SLOWED, ERASED }

# --- Signals ---
signal time_state_changed(new_state: TimeState)
signal time_gauge_changed(new_value: float)
signal time_gauge_depleted()

# --- Time Gauge ---
const GAUGE_MAX: float = 100.0
const DRAIN_RATE_STOPPED: float = 25.0   # per second
const DRAIN_RATE_SLOWED: float = 15.0    # per second
const DRAIN_RATE_ERASED: float = 33.0    # per second
const RECHARGE_RATE: float = 10.0        # per second in NORMAL state

var time_gauge: float = GAUGE_MAX
var current_state: TimeState = TimeState.NORMAL

# --- Process ---
func _process(delta: float) -> void:
	# We use unscaled delta for gauge management so slowing time
	# doesn't also slow the gauge drain
	var real_delta: float = delta
	if Engine.time_scale > 0.0:
		real_delta = delta / Engine.time_scale
	
	match current_state:
		TimeState.NORMAL:
			# Recharge gauge
			if time_gauge < GAUGE_MAX:
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

func change_time_state(new_state: TimeState) -> void:
	# Don't allow activation if gauge is empty (except returning to NORMAL)
	if new_state != TimeState.NORMAL and time_gauge <= 0.0:
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

## Check if an ability can be activated (has gauge)
func can_use_ability() -> bool:
	return time_gauge > 5.0  # Minimum threshold to activate
