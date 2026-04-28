extends CanvasLayer

## Pause Menu logic for The Vector Void.
## Handles game pause state and UI interactions.

@onready var menu_container = $CenterContainer/MenuVBox
@onready var confirm_panel = $CenterContainer/ConfirmPanel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	confirm_panel.visible = false

func toggle_pause() -> void:
	if not get_tree().paused:
		_pause_game()
	else:
		_resume_game()

func _pause_game() -> void:
	get_tree().paused = true
	visible = true
	confirm_panel.visible = false
	menu_container.visible = true

func _resume_game() -> void:
	get_tree().paused = false
	visible = false

func _on_resume_pressed() -> void:
	GameJuice.play_sfx("res://assets/audio/uiClick.wav")
	_resume_game()

func _on_menu_pressed() -> void:
	GameJuice.play_sfx("res://assets/audio/uiClick.wav")
	menu_container.visible = false
	confirm_panel.visible = true

func _on_confirm_quit_pressed() -> void:
	GameJuice.play_sfx("res://assets/audio/uiClick.wav")
	get_tree().paused = false # Unpause before changing scene
	GameJuice.transition_to_scene("res://scenes/ui/main_menu.tscn")

func _on_cancel_quit_pressed() -> void:
	GameJuice.play_sfx("res://assets/audio/uiClick.wav")
	confirm_panel.visible = false
	menu_container.visible = true
