extends CanvasLayer

## HUD — displays Time Gauge, Health, and current time state.
## Instance this in the level scene.

@onready var gauge_bar: ProgressBar = $HUDContainer/GaugeBar
@onready var health_label: Label = $HUDContainer/HealthLabel
@onready var state_label: Label = $HUDContainer/StateLabel
@onready var gauge_label: Label = $HUDContainer/GaugeLabel

# State display colors
const STATE_COLORS := {
	"NORMAL": Color(1, 1, 1),
	"STOPPED": Color(0, 1, 1),
	"SLOWED": Color(1, 0.85, 0.3),
	"ERASED": Color(0.5, 0.5, 1.0),
}

func _ready() -> void:
	layer = 90
	TimeManager.time_gauge_changed.connect(_on_gauge_changed)
	TimeManager.time_state_changed.connect(_on_state_changed)
	
	# Initialize
	if gauge_bar:
		gauge_bar.max_value = TimeManager.GAUGE_MAX
		gauge_bar.value = TimeManager.time_gauge
	_update_state_display(TimeManager.current_state)
	
	# Find player and connect health signal
	await get_tree().process_frame
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("player_damaged"):
		player.player_damaged.connect(_on_player_damaged)
		_update_health(player.health)
	if player and player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)

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

func _on_player_damaged(new_health: int) -> void:
	_update_health(new_health)

func _update_health(hp: int) -> void:
	if health_label:
		var hearts := ""
		for i in hp:
			hearts += "♥ "
		health_label.text = hearts.strip_edges()
		
		# Flash red on damage
		health_label.modulate = Color.RED
		var tween := create_tween()
		tween.tween_property(health_label, "modulate", Color.WHITE, 0.3)

func _on_player_died() -> void:
	if state_label:
		state_label.text = "[ TEMPORAL COLLAPSE ]"
		state_label.modulate = Color.RED
	
	# Show death screen after a delay
	await get_tree().create_timer(1.5).timeout
	_show_death_screen()

func _show_death_screen() -> void:
	# Create a simple death overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.1, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(vbox)
	
	var death_text := Label.new()
	death_text.text = "TEMPORAL COLLAPSE"
	death_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_text.add_theme_font_size_override("font_size", 24)
	death_text.add_theme_color_override("font_color", Color.RED)
	vbox.add_child(death_text)
	
	var retry_btn := Button.new()
	retry_btn.text = "RETRY"
	retry_btn.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(retry_btn)
	
	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	vbox.add_child(menu_btn)
