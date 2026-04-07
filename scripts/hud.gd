extends CanvasLayer

## HUD — displays continuous HP bar, Time Gauge, and time state.

@onready var gauge_bar: ProgressBar = $HUDContainer/GaugeBar
@onready var hp_bar: ProgressBar = $HUDContainer/HPBar
@onready var state_label: Label = $HUDContainer/StateLabel
@onready var gauge_label: Label = $HUDContainer/GaugeLabel

# State display colors
const STATE_COLORS := {
	"NORMAL": Color(1, 1, 1),
	"STOPPED": Color(0, 1, 1),
	"SLOWED": Color(1, 0.85, 0.3),
	"ERASED": Color(0.5, 0.5, 1.0),
	"NULLIFIED": Color(0.5, 0.0, 0.0),
}

func _ready() -> void:
	layer = 90
	TimeManager.time_gauge_changed.connect(_on_gauge_changed)
	TimeManager.time_state_changed.connect(_on_state_changed)
	TimeManager.null_zone_changed.connect(_on_null_zone_changed)
	
	# Initialize
	if gauge_bar:
		gauge_bar.max_value = TimeManager.GAUGE_MAX
		gauge_bar.value = TimeManager.time_gauge
	if hp_bar:
		hp_bar.max_value = 100.0
		hp_bar.value = 100.0
	_update_state_display(TimeManager.current_state)
	
	# Find player and connect signals
	await get_tree().process_frame
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("player_damaged"):
		player.player_damaged.connect(_on_player_damaged)
		_update_health(player.health)
	if player and player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)

func _on_null_zone_changed(is_active: bool) -> void:
	if is_active:
		if state_label:
			state_label.text = "[ NULLIFIED ]"
			state_label.modulate = STATE_COLORS["NULLIFIED"]
	else:
		_update_state_display(TimeManager.current_state)

func _on_gauge_changed(new_value: float) -> void:
	if gauge_bar:
		gauge_bar.value = new_value
	if gauge_label:
		gauge_label.text = "CHRONO: %d%%" % int(new_value)

func _on_state_changed(new_state: TimeManager.TimeState) -> void:
	_update_state_display(new_state)

func _update_state_display(state: TimeManager.TimeState) -> void:
	if not state_label:
		return
	
	match state:
		TimeManager.TimeState.NORMAL:
			state_label.text = "[ NORMAL ]"
			state_label.modulate = STATE_COLORS["NORMAL"]
		TimeManager.TimeState.STOPPED:
			state_label.text = "[ TIME STOP ]"
			state_label.modulate = STATE_COLORS["STOPPED"]
		TimeManager.TimeState.SLOWED:
			state_label.text = "[ TIME SLOW ]"
			state_label.modulate = STATE_COLORS["SLOWED"]
		TimeManager.TimeState.ERASED:
			state_label.text = "[ TIME ERASE ]"
			state_label.modulate = STATE_COLORS["ERASED"]

func _on_player_damaged(new_health: float) -> void:
	_update_health(new_health)

func _update_health(hp: float) -> void:
	if hp_bar:
		hp_bar.value = hp
		
		# Color shift: green → yellow → red
		var ratio: float = hp / 100.0
		if ratio > 0.5:
			hp_bar.modulate = Color(0.2, 1.0, 0.3)  # Green
		elif ratio > 0.25:
			hp_bar.modulate = Color(1.0, 0.85, 0.2)  # Yellow
		else:
			hp_bar.modulate = Color(1.0, 0.2, 0.2)  # Red — DANGER
		
		# Flash on damage
		var tween := create_tween()
		tween.tween_property(hp_bar, "modulate:a", 0.5, 0.05)
		tween.tween_property(hp_bar, "modulate:a", 1.0, 0.1)

func _on_player_died() -> void:
	if state_label:
		state_label.text = "[ SEQUENCE TERMINATED ]"
		state_label.modulate = Color.RED
	
	await get_tree().create_timer(1.5).timeout
	_show_death_screen()

func _show_death_screen() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0, 0.05, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(vbox)
	
	var death_text := Label.new()
	death_text.text = "SEQUENCE TERMINATED"
	death_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_text.add_theme_font_size_override("font_size", 24)
	death_text.add_theme_color_override("font_color", Color(1, 0, 0.3))
	vbox.add_child(death_text)
	
	var retry_btn := Button.new()
	retry_btn.text = "REBOOT SEQUENCE"
	retry_btn.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(retry_btn)
	
	var menu_btn := Button.new()
	menu_btn.text = "EXIT TO VOID"
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	vbox.add_child(menu_btn)
