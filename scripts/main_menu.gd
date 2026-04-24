extends Control

## Main Menu — Entry point for Chronos Bound.
## Title, Start, and Quit buttons.

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Ensure time is normal when returning to menu
	Engine.time_scale = 1.0
	TimeManager.game_is_active = false
	
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
	TimeManager.reset_fracture(true)
	TimeManager.game_time = 0.0
	TimeManager.game_is_active = true
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
