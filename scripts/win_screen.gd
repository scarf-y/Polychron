extends CanvasLayer

func _ready() -> void:
	# Stop the timer
	TimeManager.game_is_active = false
	
	# Check for new best time
	var current_time = TimeManager.game_time
	var is_new_best = false
	if TimeManager.best_game_time < 0.0 or current_time < TimeManager.best_game_time:
		TimeManager.best_game_time = current_time
		is_new_best = true
		
	# Display the time
	var time_text := "CLEAR TIME: " + _format_time(current_time)
	if is_new_best:
		time_text += " [NEW BEST!]"
		
	var time_label := Label.new()
	time_label.text = time_text
	time_label.add_theme_font_size_override("font_size", 16)
	time_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if is_new_best else Color(0.8, 0.8, 0.8))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var vbox = get_node("CenterContainer/VBoxContainer")
	if vbox:
		# Insert below subtitle, above button
		vbox.add_child(time_label)
		vbox.move_child(time_label, 2)
	
	# Reset player health completely for a new run
	TimeManager.player_health = 100.0
	TimeManager.reset_fracture()
	
	var btn := get_node("CenterContainer/VBoxContainer/MenuButton") as Button
	if btn:
		btn.pressed.connect(_on_menu_pressed)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _format_time(time_seconds: float) -> String:
	var minutes := int(time_seconds) / 60
	var seconds := int(time_seconds) % 60
	var millis := int((time_seconds - int(time_seconds)) * 100)
	return "%02d:%02d.%02d" % [minutes, seconds, millis]
