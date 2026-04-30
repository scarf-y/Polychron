extends Node

var music_enabled: bool = true
var master_volume: float = 1.0:
	set(value):
		master_volume = value
		_update_master_bus()
var screenshake_enabled: bool = true

func _ready() -> void:
	_update_master_bus()

func _update_master_bus() -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		if master_volume <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))

func get_volume_db() -> float:
	if master_volume <= 0.001:
		return -80.0
	return linear_to_db(master_volume)
