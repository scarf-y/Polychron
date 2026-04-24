extends CanvasLayer

func _ready() -> void:
	# Reset player health completely for a new run
	TimeManager.player_health = 100.0
	TimeManager.reset_fracture()
	
	var btn := get_node("CenterContainer/VBoxContainer/MenuButton") as Button
	if btn:
		btn.pressed.connect(_on_menu_pressed)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
