extends Control

## POLYCHRON — Entry point for the game.
## Title, Start, and Quit buttons.

@onready var start_button: Button = $MainHBox/LeftVBox/VBoxContainer/StartButton
@onready var tutorial_button: Button = $MainHBox/LeftVBox/VBoxContainer/TutorialButton
@onready var settings_button: Button = $MainHBox/LeftVBox/VBoxContainer/SettingsButton
@onready var quit_button: Button = $MainHBox/LeftVBox/VBoxContainer/QuitButton

@onready var settings_panel: ColorRect = $SettingsPanel
@onready var close_settings_btn: Button = $SettingsPanel/VBox/CloseSettings
@onready var music_check: CheckBox = $SettingsPanel/VBox/MusicCheck
@onready var shake_check: CheckBox = $SettingsPanel/VBox/ShakeCheck
@onready var vol_slider: HSlider = $SettingsPanel/VBox/VolSlider

@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

@onready var title_label: Label = $MainHBox/LeftVBox/TitleLabel
@onready var subtitle_label: Label = $MainHBox/LeftVBox/SubtitleLabel
@onready var best_time_label: Label = $MainHBox/RightVBox/BestTimeLabel
@onready var cube_container: Control = $MainHBox/RightVBox/PlayerPreviewContainer

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
	
	_load_settings()
	_animate_title()
	
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
	_apply_audio_settings()

func _apply_audio_settings() -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs and gs.music_enabled:
		if bgm_player.stream is AudioStreamMP3:
			bgm_player.stream.loop = true
		if not bgm_player.playing:
			bgm_player.play()
		bgm_player.volume_db = gs.get_volume_db()
	else:
		bgm_player.stop()

func _on_settings_pressed() -> void:
	GameJuice.play_sfx("res://assets/audio/uiClick.wav")
	settings_panel.show()

func _on_close_settings() -> void:
	GameJuice.play_sfx("res://assets/audio/uiClick.wav")
	settings_panel.hide()

func _on_music_toggled(toggled_on: bool) -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs:
		gs.music_enabled = toggled_on
	_apply_audio_settings()

func _on_shake_toggled(toggled_on: bool) -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs:
		gs.screenshake_enabled = toggled_on

func _on_volume_changed(value: float) -> void:
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs:
		gs.master_volume = value
	_apply_audio_settings()

func _on_start_pressed() -> void:
	TimeManager.start_new_run()
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")

func _on_tutorial_pressed() -> void:
	GameJuice.play_sfx("res://assets/audio/uiClick.wav")
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
