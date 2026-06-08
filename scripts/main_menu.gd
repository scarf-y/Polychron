extends Control

## POLYCHRON — Entry point for the game.
## Title, Start, and Quit buttons.

@onready var start_button: Button = $MainHBox/LeftVBox/VBoxContainer/StartButton
@onready var tutorial_button: Button = $MainHBox/LeftVBox/VBoxContainer/TutorialButton
@onready var settings_button: Button = $MainHBox/LeftVBox/VBoxContainer/SettingsButton
@onready var quit_button: Button = $MainHBox/LeftVBox/VBoxContainer/QuitButton

@onready var settings_panel: ColorRect = $SettingsPanel
@onready var settings_vbox: VBoxContainer = $SettingsPanel/MarginContainer/ScrollContainer/VBox
@onready var close_settings_btn: Button = $SettingsPanel/MarginContainer/ScrollContainer/VBox/CloseSettings
@onready var music_check: CheckBox = $SettingsPanel/MarginContainer/ScrollContainer/VBox/MusicCheck
@onready var shake_check: CheckBox = $SettingsPanel/MarginContainer/ScrollContainer/VBox/ShakeCheck
@onready var vol_slider: HSlider = $SettingsPanel/MarginContainer/ScrollContainer/VBox/VolSlider

@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

@onready var title_label: Label = $MainHBox/LeftVBox/TitleLabel
@onready var subtitle_label: Label = $MainHBox/LeftVBox/SubtitleLabel
@onready var best_time_label: Label = $MainHBox/RightVBox/BestTimeLabel
@onready var cube_container: Control = $MainHBox/RightVBox/PlayerPreviewContainer
@onready var controls_label: Label = $MainHBox/RightVBox/ControlsLabel

# --- Input Settings ---
var rebindable_actions = {
	"move_up": "Move Up",
	"move_down": "Move Down",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"dash": "Phase Dash",
	"time_stop": "Time Stop",
	"time_slow": "Time Slow",
	"time_erase": "Time Erase"
}

var _waiting_for_key: String = ""
var _action_buttons: Dictionary = {}
var _conflict_label: Label

# --- Cube Data ---
var _cube_rotation: Vector3 = Vector3.ZERO
var _cube_vertices: Array[Vector3] = [
	Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
	Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)
]
var _cube_edges: Array[Array] = [
	[0, 1], [1, 2], [2, 3], [3, 0],
	[4, 5], [5, 6], [6, 7], [7, 4],
	[0, 4], [1, 5], [2, 6], [3, 7]
]

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	close_settings_btn.pressed.connect(_on_close_settings)
	music_check.toggled.connect(_on_music_toggled)
	shake_check.toggled.connect(_on_shake_toggled)
	vol_slider.value_changed.connect(_on_volume_changed)
	
	_setup_controls_ui()
	_load_settings()
	_animate_title()
	_update_controls_label()
	
	# Update Best Time Display
	var has_best = TimeManager.best_game_time > 0.0
	if has_best:
		best_time_label.text = "FASTEST CLEAR: " + _format_time(TimeManager.best_game_time)
		best_time_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	else:
		best_time_label.text = "FASTEST CLEAR: NONE"
		best_time_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	
	# Connect draw signal
	cube_container.draw.connect(_on_cube_draw)
	
	# Ensure time is normal when returning to menu
	Engine.time_scale = 1.0
	TimeManager.game_is_active = false

func _setup_controls_ui() -> void:
	var sep = HSeparator.new()
	settings_vbox.add_child(sep)
	settings_vbox.move_child(sep, close_settings_btn.get_index())
	
	var title = Label.new()
	title.text = "— CONTROLS —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_vbox.add_child(title)
	settings_vbox.move_child(title, close_settings_btn.get_index())
	
	for action in rebindable_actions.keys():
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = rebindable_actions[action]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 0)
		btn.pressed.connect(_on_rebind_pressed.bind(action))
		
		hbox.add_child(lbl)
		hbox.add_child(btn)
		
		settings_vbox.add_child(hbox)
		settings_vbox.move_child(hbox, close_settings_btn.get_index())
		_action_buttons[action] = btn
		
	_conflict_label = Label.new()
	_conflict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_conflict_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_conflict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_conflict_label.hide()
	settings_vbox.add_child(_conflict_label)
	settings_vbox.move_child(_conflict_label, close_settings_btn.get_index())
	
	var reset_btn = Button.new()
	reset_btn.text = "RESET CONTROLS"
	reset_btn.pressed.connect(_on_reset_controls)
	settings_vbox.add_child(reset_btn)
	settings_vbox.move_child(reset_btn, close_settings_btn.get_index())
	
	var sep2 = HSeparator.new()
	settings_vbox.add_child(sep2)
	settings_vbox.move_child(sep2, close_settings_btn.get_index())

func _input(event: InputEvent) -> void:
	if _waiting_for_key != "" and event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			_waiting_for_key = ""
			_update_all_action_buttons()
			return
			
		var action = _waiting_for_key
		_waiting_for_key = ""
		
		# Hapus event keyboard lama
		for old_event in InputMap.action_get_events(action):
			if old_event is InputEventKey:
				InputMap.action_erase_event(action, old_event)
				
		var new_event = InputEventKey.new()
		new_event.physical_keycode = event.physical_keycode
		InputMap.action_add_event(action, new_event)
		
		_update_all_action_buttons()
		_check_conflicts()
		_update_controls_label()
		
		if GlobalSettings.has_method("save_settings"):
			GlobalSettings.save_settings()

func _on_rebind_pressed(action: String) -> void:
	if _waiting_for_key != "":
		return
	_waiting_for_key = action
	_action_buttons[action].text = "..."
	GameJuice.play_sfx("res://assets/audio/uiClick.wav")

func _update_all_action_buttons() -> void:
	for action in _action_buttons.keys():
		var btn = _action_buttons[action]
		btn.text = "None"
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var keyname = OS.get_keycode_string(event.physical_keycode)
				if keyname == "":
					keyname = OS.get_keycode_string(event.keycode)
				btn.text = keyname
				break

func _check_conflicts() -> void:
	var key_to_actions = {}
	for action in rebindable_actions.keys():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key = event.physical_keycode
				if not key_to_actions.has(key):
					key_to_actions[key] = []
				key_to_actions[key].append(rebindable_actions[action])
	
	var conflicts = []
	for key in key_to_actions.keys():
		if key_to_actions[key].size() > 1:
			var keyname = OS.get_keycode_string(key)
			conflicts.append("Key [" + keyname + "] dipakai oleh: " + ", ".join(key_to_actions[key]))
			
	if conflicts.size() > 0:
		_conflict_label.text = "⚠ CONFLICT:\n" + "\n".join(conflicts)
		_conflict_label.show()
	else:
		_conflict_label.text = ""
		_conflict_label.hide()

func _on_reset_controls() -> void:
	GameJuice.play_sfx("res://assets/audio/uiClick.wav")
	var default_bindings = {
		"move_up": KEY_W,
		"move_down": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"dash": KEY_Q,
		"time_stop": KEY_SPACE,
		"time_slow": KEY_SHIFT,
		"time_erase": KEY_E
	}
	for action in default_bindings.keys():
		for old_event in InputMap.action_get_events(action):
			if old_event is InputEventKey:
				InputMap.action_erase_event(action, old_event)
		var new_event = InputEventKey.new()
		new_event.physical_keycode = default_bindings[action]
		InputMap.action_add_event(action, new_event)
		
	_update_all_action_buttons()
	_check_conflicts()
	_update_controls_label()
	
	if GlobalSettings.has_method("save_settings"):
		GlobalSettings.save_settings()

func _update_controls_label() -> void:
	if not is_instance_valid(controls_label):
		return
	
	var get_key_name = func(action):
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var keyname = OS.get_keycode_string(event.physical_keycode)
				if keyname == "":
					keyname = OS.get_keycode_string(event.keycode)
				return keyname
		return "None"
		
	controls_label.text = "%s/%s/%s/%s - Move\nLMB - Shoot\n%s - Phase Dash\n%s - Time Stop\n%s - Time Slow\n%s - Time Erase" % [
		get_key_name.call("move_up"),
		get_key_name.call("move_left"),
		get_key_name.call("move_down"),
		get_key_name.call("move_right"),
		get_key_name.call("dash"),
		get_key_name.call("time_stop"),
		get_key_name.call("time_slow"),
		get_key_name.call("time_erase")
	]

func _process(delta: float) -> void:
	# Rotate the cube
	_cube_rotation.x += delta * 1.0
	_cube_rotation.y += delta * 1.5
	_cube_rotation.z += delta * 0.5
	cube_container.queue_redraw()

func _on_cube_draw() -> void:
	var center = cube_container.size / 2.0
	var scale = 35.0
	
	var projected_points: Array[Vector2] = []
	for v in _cube_vertices:
		# Rotate around X
		var p = v
		var x1 = p.x
		var y1 = p.y * cos(_cube_rotation.x) - p.z * sin(_cube_rotation.x)
		var z1 = p.y * sin(_cube_rotation.x) + p.z * cos(_cube_rotation.x)
		p = Vector3(x1, y1, z1)
		
		# Rotate around Y
		var x2 = p.x * cos(_cube_rotation.y) + p.z * sin(_cube_rotation.y)
		var y2 = p.y
		var z2 = -p.x * sin(_cube_rotation.y) + p.z * cos(_cube_rotation.y)
		p = Vector3(x2, y2, z2)
		
		# Rotate around Z
		var x3 = p.x * cos(_cube_rotation.z) - p.y * sin(_cube_rotation.z)
		var y3 = p.x * sin(_cube_rotation.z) + p.y * cos(_cube_rotation.z)
		var z3 = p.z
		
		projected_points.append(center + Vector2(x3, y3) * scale)
	
	# Draw edges
	for edge in _cube_edges:
		var p1 = projected_points[edge[0]]
		var p2 = projected_points[edge[1]]
		cube_container.draw_line(p1, p2, Color(0.3, 0.7, 1.0), 1.5, true)
		
	# Draw vertices (dots)
	for p in projected_points:
		cube_container.draw_circle(p, 2.0, Color(0, 1, 1))

func _load_settings() -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs:
		music_check.set_pressed_no_signal(gs.music_enabled)
		shake_check.set_pressed_no_signal(gs.screenshake_enabled)
		vol_slider.set_value_no_signal(gs.master_volume)
	_update_all_action_buttons()
	_check_conflicts()
	_apply_audio_settings()

func _apply_audio_settings() -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs and gs.music_enabled:
		if bgm_player.stream is AudioStreamMP3:
			bgm_player.stream.loop = true
		if not bgm_player.playing:
			bgm_player.play()
	else:
		bgm_player.stop()

func _on_settings_pressed() -> void:
	GameJuice.play_sfx("res://assets/audio/uiClick.wav")
	settings_panel.show()
	_update_all_action_buttons()
	_check_conflicts()

func _on_close_settings() -> void:
	if _waiting_for_key != "":
		_waiting_for_key = ""
		_update_all_action_buttons()
	GameJuice.play_sfx("res://assets/audio/uiClick.wav")
	settings_panel.hide()

func _on_music_toggled(toggled_on: bool) -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs:
		gs.music_enabled = toggled_on
		if gs.has_method("save_settings"):
			gs.save_settings()
	_apply_audio_settings()

func _on_shake_toggled(toggled_on: bool) -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs:
		gs.screenshake_enabled = toggled_on
		if gs.has_method("save_settings"):
			gs.save_settings()

func _on_volume_changed(value: float) -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs:
		gs.master_volume = value
		if gs.has_method("save_settings"):
			gs.save_settings()
	_apply_audio_settings()

func _on_start_pressed() -> void:
	TimeManager.start_new_run()
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")

func _on_tutorial_pressed() -> void:
	GameJuice.play_sfx("res://assets/audio/uiClick.wav")
	TimeManager.start_new_run()
	get_tree().change_scene_to_file("res://scenes/levels/tutorial_level.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _animate_title() -> void:
	if not title_label:
		return
	# Pulse the title color
	var tween := create_tween().set_loops()
	tween.tween_property(title_label, "modulate", Color(0.5, 0.8, 1.0), 1.5)
	tween.tween_property(title_label, "modulate", Color(1.0, 1.0, 1.0), 1.5)

func _format_time(time_seconds: float) -> String:
	var minutes := int(time_seconds) / 60
	var seconds := int(time_seconds) % 60
	var millis := int((time_seconds - int(time_seconds)) * 100)
	return "%02d:%02d.%02d" % [minutes, seconds, millis]
