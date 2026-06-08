extends Node

const SETTINGS_PATH = "user://settings.cfg"

var music_enabled: bool = true
var master_volume: float = 1.0:
	set(value):
		master_volume = value
		_update_master_bus()
var screenshake_enabled: bool = true

func _ready() -> void:
	load_settings()
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

# --- Persistence ---

func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("general", "screenshake_enabled", screenshake_enabled)

	# Input bindings — simpan physical keycode per action
	var actions := [
		"move_up", "move_down", "move_left", "move_right",
		"dash", "time_stop", "time_slow", "time_erase"
	]
	for action in actions:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				config.set_value("input", action, (event as InputEventKey).physical_keycode)
				break

	config.save(SETTINGS_PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	music_enabled = config.get_value("audio", "music_enabled", true)
	master_volume = config.get_value("audio", "master_volume", 1.0)
	screenshake_enabled = config.get_value("general", "screenshake_enabled", true)

	# Restore input bindings
	if not config.has_section("input"):
		return
	var actions := [
		"move_up", "move_down", "move_left", "move_right",
		"dash", "time_stop", "time_slow", "time_erase"
	]
	for action in actions:
		if not config.has_section_key("input", action):
			continue
		var keycode: int = config.get_value("input", action)
		# Hapus binding keyboard lama, ganti dengan yang disimpan
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				InputMap.action_erase_event(action, e)
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode as Key
		InputMap.action_add_event(action, ev)
