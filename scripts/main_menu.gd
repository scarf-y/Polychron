extends Control

## Main Menu — Entry point for Chronos Bound.
## Title, Start, and Quit buttons.

@onready var start_button: Button = $VBoxContainer/StartButton
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
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	close_settings_btn.pressed.connect(_on_close_settings)
	music_check.toggled.connect(_on_music_toggled)
	shake_check.toggled.connect(_on_shake_toggled)
	vol_slider.value_changed.connect(_on_volume_changed)
	
	_load_settings()
	
	# Ensure time is normal when returning to menu
	Engine.time_scale = 1.0
	TimeManager.game_is_active = false

func _load_settings() -> void:
	music_check.set_pressed_no_signal(GlobalSettings.music_enabled)
	shake_check.set_pressed_no_signal(GlobalSettings.screenshake_enabled)
	vol_slider.set_value_no_signal(GlobalSettings.master_volume)
	_apply_audio_settings()

func _apply_audio_settings() -> void:
	if GlobalSettings.music_enabled:
		if not bgm_player.playing:
			bgm_player.play()
		bgm_player.volume_db = GlobalSettings.get_volume_db()
	else:
		bgm_player.stop()

func _on_settings_pressed() -> void:
	settings_panel.show()

func _on_close_settings() -> void:
	settings_panel.hide()

func _on_music_toggled(toggled_on: bool) -> void:
	GlobalSettings.music_enabled = toggled_on
	_apply_audio_settings()

func _on_shake_toggled(toggled_on: bool) -> void:
	GlobalSettings.screenshake_enabled = toggled_on

func _on_volume_changed(value: float) -> void:
	GlobalSettings.master_volume = value
	_apply_audio_settings()
	
	# Animate title
	_animate_title()
	
	# Display Best Time
	if TimeManager.best_game_time > 0.0:
		var best_time_label := Label.new()
		best_time_label.text = "FASTEST CLEAR: " + _format_time(TimeManager.best_game_time)
		best_time_label.add_theme_font_size_override("font_size", 12)
		best_time_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		best_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Insert above the VBoxContainer
		var vbox = get_node("VBoxContainer")
		if vbox:
			vbox.add_sibling(best_time_label)
			best_time_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			best_time_label.position = vbox.position - Vector2(0, 30)

func _on_start_pressed() -> void:
	TimeManager.start_new_run()
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")

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
