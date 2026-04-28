extends Control

## POLYCHRON — Entry point for the game.
## Title, Start, and Quit buttons.

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var tutorial_button: Button = $VBoxContainer/TutorialButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

@onready var settings_panel: ColorRect = $SettingsPanel
@onready var close_settings_btn: Button = $SettingsPanel/VBox/CloseSettings
@onready var music_check: CheckBox = $SettingsPanel/VBox/MusicCheck
@onready var shake_check: CheckBox = $SettingsPanel/VBox/ShakeCheck
@onready var vol_slider: HSlider = $SettingsPanel/VBox/VolSlider

@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel

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
	
	# 1. Create Layout Structure
	var main_hbox := HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_left = 60
	main_hbox.offset_right = -60
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.set_theme_constant_override("separation", 100)
	add_child(main_hbox)
	
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.set_theme_constant_override("separation", 10)
	main_hbox.add_child(left_vbox)
	
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.set_theme_constant_override("separation", 20)
	main_hbox.add_child(right_vbox)
	
	# 2. Populate Left Side (Title + Buttons)
	if title_label:
		title_label.reparent(left_vbox)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		
	if subtitle_label:
		subtitle_label.reparent(left_vbox)
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Spacer below subtitle
		var sub_spacer := Control.new()
		sub_spacer.custom_minimum_size = Vector2(0, 30)
		left_vbox.add_child(sub_spacer)
		
	# Move the original button container's buttons into the left_vbox
	var old_vbox = get_node("VBoxContainer")
	if old_vbox:
		var buttons = old_vbox.get_children()
		for b in buttons:
			if b is Button:
				b.reparent(left_vbox)
				b.custom_minimum_size = Vector2(180, 0)
		old_vbox.queue_free()
		
	# 3. Populate Right Side (Player Preview + Best Time + Controls)
	
	# Player Preview Container
	var player_container := Control.new()
	player_container.custom_minimum_size = Vector2(100, 100)
	right_vbox.add_child(player_container)
	
	# Simple Player Visual (Diamond Shape)
	var player_poly := Polygon2D.new()
	player_poly.polygon = PackedVector2Array([
		Vector2(0, -25), Vector2(20, 0), Vector2(0, 25), Vector2(-20, 0)
	])
	player_poly.color = Color(0.3, 0.5, 1.0)
	player_poly.position = Vector2(50, 50)
	player_container.add_child(player_poly)
	
	# Glow effect for player preview
	var tween = player_poly.create_tween().set_loops()
	tween.tween_property(player_poly, "scale", Vector2(1.1, 1.1), 1.0)
	tween.tween_property(player_poly, "scale", Vector2(1.0, 1.0), 1.0)
	
	# Best Time
	var best_time_label := Label.new()
	var has_best = TimeManager.best_game_time > 0.0
	best_time_label.text = "FASTEST CLEAR: " + (_format_time(TimeManager.best_game_time) if has_best else "NONE")
	best_time_label.add_theme_font_size_override("font_size", 12)
	best_time_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if has_best else Color(0.5, 0.5, 0.5))
	best_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(best_time_label)
	
	# Controls
	var controls = get_node_or_null("ControlsLabel")
	if controls:
		controls.reparent(right_vbox)
		controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		controls.add_theme_font_size_override("font_size", 10)
		controls.text = controls.text.replace("  |  ", "\n") # Stack them for the side view
		
	# Ensure time is normal when returning to menu
	Engine.time_scale = 1.0
	TimeManager.game_is_active = false

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
