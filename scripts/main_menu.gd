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
	
	# Animate title
	_animate_title()

func _on_start_pressed() -> void:
	TimeManager.reset_fracture(true)
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
