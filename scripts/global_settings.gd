extends Node

var music_enabled: bool = true
var master_volume: float = 1.0 # 0.0 to 1.0
var screenshake_enabled: bool = true

# It could be useful to convert volume (0.0 to 1.0) to linear Decibels for AudioStreamPlayer.
func get_volume_db() -> float:
	if master_volume <= 0.001:
		return -80.0
	return linear_to_db(master_volume)
