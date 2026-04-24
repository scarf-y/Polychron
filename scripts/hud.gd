extends CanvasLayer

## HUD — Displays HP bar, Time Gauge, Fracture Meter, Time State,
## Fracture Stage indicator, Lockdown warning, and Death Screen.
## Overhauled for visibility and polish.

# --- Node references (built programmatically) ---
var hp_bar: ProgressBar = null
var hp_label: Label = null
var hp_panel: PanelContainer = null
var gauge_bar: ProgressBar = null
var gauge_label: Label = null
var fracture_bar: ProgressBar = null
var fracture_label: Label = null
var fracture_stage_label: Label = null
var fracture_debuff_label: Label = null
var state_label: Label = null
var lockdown_warning: Label = null
var game_timer_label: Label = null

var _lockdown_pulse_tween: Tween = null
var _player_ref: Node = null

# State display colors
const STATE_COLORS := {
	"NORMAL": Color(1, 1, 1),
	"STOPPED": Color(0, 1, 1),
	"SLOWED": Color(1, 0.85, 0.3),
	"ERASED": Color(0.5, 0.5, 1.0),
	"NULLIFIED": Color(0.5, 0.0, 0.0),
	"LOCKDOWN": Color(1.0, 0.15, 0.15),
}

func _ready() -> void:
	layer = 90
	_build_hud()
	
	# Connect TimeManager signals
	TimeManager.time_gauge_changed.connect(_on_gauge_changed)
	TimeManager.time_state_changed.connect(_on_state_changed)
	TimeManager.null_zone_changed.connect(_on_null_zone_changed)
	TimeManager.fracture_changed.connect(_on_fracture_changed)
	TimeManager.lockdown_changed.connect(_on_lockdown_changed)
	
	# Initialize values
	if gauge_bar:
		gauge_bar.max_value = TimeManager.GAUGE_MAX
		gauge_bar.value = TimeManager.time_gauge
	if fracture_bar:
		fracture_bar.max_value = TimeManager.FRACTURE_MAX
		fracture_bar.value = TimeManager.fracture_level
	_update_state_display(TimeManager.current_state)
	
	# Find player and connect signals
	await get_tree().process_frame
	_player_ref = get_tree().get_first_node_in_group("player")
	if _player_ref and _player_ref.has_signal("player_damaged"):
		_player_ref.player_damaged.connect(_on_player_damaged)
		_update_health(_player_ref.health)
	if _player_ref and _player_ref.has_signal("player_died"):
		_player_ref.player_died.connect(_on_player_died)

func _build_hud() -> void:
	# Remove any existing HUDContainer from the .tscn
	var old_container = get_node_or_null("HUDContainer")
	if old_container:
		old_container.queue_free()
	
	# === TOP BAR (HP + Fracture + State) ===
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 8.0
	top_bar.offset_right = -8.0
	top_bar.offset_top = 6.0
	top_bar.offset_bottom = 50.0
	top_bar.add_theme_constant_override("separation", 12)
	add_child(top_bar)
	
	# Game Timer Label
	game_timer_label = Label.new()
	game_timer_label.text = "00:00.00"
	game_timer_label.add_theme_font_size_override("font_size", 16)
	game_timer_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.9))
	game_timer_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	game_timer_label.offset_right = -16.0
	game_timer_label.offset_bottom = -16.0
	game_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(game_timer_label)
	
	# --- HP Section ---
	var hp_vbox := VBoxContainer.new()
	hp_vbox.add_theme_constant_override("separation", 1)
	hp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(hp_vbox)
	
	# HP Header
	hp_label = Label.new()
	hp_label.text = "HP: 100/100"
	hp_label.add_theme_font_size_override("font_size", 10)
	hp_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.85))
	hp_vbox.add_child(hp_label)
	
	# HP Bar with background
	hp_panel = PanelContainer.new()
	hp_panel.custom_minimum_size = Vector2(160, 14)
	var hp_style := StyleBoxFlat.new()
	hp_style.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	hp_style.corner_radius_top_left = 3
	hp_style.corner_radius_top_right = 3
	hp_style.corner_radius_bottom_left = 3
	hp_style.corner_radius_bottom_right = 3
	hp_style.border_color = Color(0.3, 0.8, 0.4, 0.5)
	hp_style.border_width_left = 1
	hp_style.border_width_right = 1
	hp_style.border_width_top = 1
	hp_style.border_width_bottom = 1
	hp_panel.add_theme_stylebox_override("panel", hp_style)
	hp_vbox.add_child(hp_panel)
	
	hp_bar = ProgressBar.new()
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(160, 14)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Style the fill
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.2, 0.9, 0.35)
	hp_fill.corner_radius_top_left = 2
	hp_fill.corner_radius_top_right = 2
	hp_fill.corner_radius_bottom_left = 2
	hp_fill.corner_radius_bottom_right = 2
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.15, 0.05, 0.05, 0.8)
	hp_bg.corner_radius_top_left = 2
	hp_bg.corner_radius_top_right = 2
	hp_bg.corner_radius_bottom_left = 2
	hp_bg.corner_radius_bottom_right = 2
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	hp_panel.add_child(hp_bar)
	
	# --- Fracture Section (Center) ---
	var fracture_vbox := VBoxContainer.new()
	fracture_vbox.add_theme_constant_override("separation", 1)
	fracture_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(fracture_vbox)
	
	fracture_label = Label.new()
	fracture_label.text = "FRACTURE: 0%"
	fracture_label.add_theme_font_size_override("font_size", 10)
	fracture_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	fracture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fracture_vbox.add_child(fracture_label)
	
	fracture_bar = ProgressBar.new()
	fracture_bar.max_value = 100.0
	fracture_bar.value = 0.0
	fracture_bar.show_percentage = false
	fracture_bar.custom_minimum_size = Vector2(140, 10)
	var frac_fill := StyleBoxFlat.new()
	frac_fill.bg_color = Color(0.3, 0.5, 1.0)
	frac_fill.corner_radius_top_left = 2
	frac_fill.corner_radius_top_right = 2
	frac_fill.corner_radius_bottom_left = 2
	frac_fill.corner_radius_bottom_right = 2
	fracture_bar.add_theme_stylebox_override("fill", frac_fill)
	var frac_bg := StyleBoxFlat.new()
	frac_bg.bg_color = Color(0.08, 0.08, 0.12, 0.8)
	frac_bg.corner_radius_top_left = 2
	frac_bg.corner_radius_top_right = 2
	frac_bg.corner_radius_bottom_left = 2
	frac_bg.corner_radius_bottom_right = 2
	fracture_bar.add_theme_stylebox_override("background", frac_bg)
	fracture_vbox.add_child(fracture_bar)
	
	fracture_stage_label = Label.new()
	fracture_stage_label.text = "STAGE I — STABLE"
	fracture_stage_label.add_theme_font_size_override("font_size", 8)
	fracture_stage_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.7))
	fracture_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fracture_vbox.add_child(fracture_stage_label)
	
	fracture_debuff_label = Label.new()
	fracture_debuff_label.text = "[ All Systems Nominal ]"
	fracture_debuff_label.add_theme_font_size_override("font_size", 8)
	fracture_debuff_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.8))
	fracture_debuff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fracture_vbox.add_child(fracture_debuff_label)
	
	# --- State Label (Right) ---
	var state_vbox := VBoxContainer.new()
	state_vbox.add_theme_constant_override("separation", 2)
	state_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_bar.add_child(state_vbox)
	
	state_label = Label.new()
	state_label.text = "[ NORMAL ]"
	state_label.add_theme_font_size_override("font_size", 14)
	state_label.add_theme_color_override("font_color", Color.WHITE)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_vbox.add_child(state_label)
	
	# === BOTTOM BAR (Gauge) ===
	var bottom_bar := VBoxContainer.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_left = 100.0
	bottom_bar.offset_right = -100.0
	bottom_bar.offset_top = -30.0
	bottom_bar.offset_bottom = -6.0
	bottom_bar.add_theme_constant_override("separation", 1)
	add_child(bottom_bar)
	
	gauge_label = Label.new()
	gauge_label.text = "CHRONO: 100%"
	gauge_label.add_theme_font_size_override("font_size", 10)
	gauge_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	gauge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_bar.add_child(gauge_label)
	
	gauge_bar = ProgressBar.new()
	gauge_bar.max_value = 100.0
	gauge_bar.value = 100.0
	gauge_bar.show_percentage = false
	gauge_bar.custom_minimum_size = Vector2(200, 10)
	var gauge_fill := StyleBoxFlat.new()
	gauge_fill.bg_color = Color(0.3, 0.7, 1.0)
	gauge_fill.corner_radius_top_left = 2
	gauge_fill.corner_radius_top_right = 2
	gauge_fill.corner_radius_bottom_left = 2
	gauge_fill.corner_radius_bottom_right = 2
	gauge_bar.add_theme_stylebox_override("fill", gauge_fill)
	var gauge_bg := StyleBoxFlat.new()
	gauge_bg.bg_color = Color(0.08, 0.08, 0.15, 0.8)
	gauge_bg.corner_radius_top_left = 2
	gauge_bg.corner_radius_top_right = 2
	gauge_bg.corner_radius_bottom_left = 2
	gauge_bg.corner_radius_bottom_right = 2
	gauge_bar.add_theme_stylebox_override("background", gauge_bg)
	bottom_bar.add_child(gauge_bar)
	
	# === LOCKDOWN WARNING (Center of screen, hidden by default) ===
	lockdown_warning = Label.new()
	lockdown_warning.name = "LockdownWarning"
	lockdown_warning.text = "⚠ LOCKDOWN — KILL TO RE-SYNC ⚠"
	lockdown_warning.set_anchors_preset(Control.PRESET_CENTER)
	lockdown_warning.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lockdown_warning.grow_vertical = Control.GROW_DIRECTION_BOTH
	lockdown_warning.add_theme_font_size_override("font_size", 16)
	lockdown_warning.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	lockdown_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lockdown_warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lockdown_warning.visible = false
	add_child(lockdown_warning)

func _process(_delta: float) -> void:
	if game_timer_label and TimeManager.game_is_active:
		var time_seconds = TimeManager.game_time
		var minutes := int(time_seconds) / 60
		var seconds := int(time_seconds) % 60
		var millis := int((time_seconds - int(time_seconds)) * 100)
		game_timer_label.text = "%02d:%02d.%02d" % [minutes, seconds, millis]

# =========================
# SIGNAL HANDLERS
# =========================
func _on_null_zone_changed(is_active: bool) -> void:
	if is_active:
		if state_label:
			state_label.text = "[ NULLIFIED ]"
			state_label.add_theme_color_override("font_color", STATE_COLORS["NULLIFIED"])
	else:
		_update_state_display(TimeManager.current_state)

func _on_gauge_changed(new_value: float) -> void:
	if gauge_bar:
		gauge_bar.value = new_value
		# Color shift based on gauge level
		var ratio: float = new_value / TimeManager.GAUGE_MAX
		var fill_style: StyleBoxFlat = gauge_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if ratio > 0.5:
				fill_style.bg_color = Color(0.3, 0.7, 1.0)
			elif ratio > 0.2:
				fill_style.bg_color = Color(1.0, 0.7, 0.2)
			else:
				fill_style.bg_color = Color(1.0, 0.2, 0.2)
	if gauge_label:
		gauge_label.text = "CHRONO: %d%%" % int(new_value)

func _on_state_changed(new_state: TimeManager.TimeState) -> void:
	_update_state_display(new_state)

func _update_state_display(state: TimeManager.TimeState) -> void:
	if not state_label:
		return
	
	if TimeManager.is_lockdown:
		state_label.text = "[ LOCKDOWN ]"
		state_label.add_theme_color_override("font_color", STATE_COLORS["LOCKDOWN"])
		return
	
	match state:
		TimeManager.TimeState.NORMAL:
			state_label.text = "[ NORMAL ]"
			state_label.add_theme_color_override("font_color", STATE_COLORS["NORMAL"])
		TimeManager.TimeState.STOPPED:
			state_label.text = "[ TIME STOP ]"
			state_label.add_theme_color_override("font_color", STATE_COLORS["STOPPED"])
		TimeManager.TimeState.SLOWED:
			state_label.text = "[ TIME SLOW ]"
			state_label.add_theme_color_override("font_color", STATE_COLORS["SLOWED"])
		TimeManager.TimeState.ERASED:
			state_label.text = "[ TIME ERASE ]"
			state_label.add_theme_color_override("font_color", STATE_COLORS["ERASED"])

func _on_fracture_changed(new_value: float) -> void:
	if fracture_bar:
		fracture_bar.value = new_value
		
		# Color shift: blue → orange → red
		var fill_style: StyleBoxFlat = fracture_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if new_value <= 25.0:
				fill_style.bg_color = Color(0.3, 0.5, 1.0)
			elif new_value <= 50.0:
				fill_style.bg_color = Color(0.8, 0.6, 0.2)
			elif new_value <= 75.0:
				fill_style.bg_color = Color(1.0, 0.4, 0.1)
			else:
				fill_style.bg_color = Color(1.0, 0.15, 0.15)
	
	if fracture_label:
		fracture_label.text = "FRACTURE: %d%%" % int(new_value)
		# Tint label color to match severity
		if new_value <= 25.0:
			fracture_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		elif new_value <= 50.0:
			fracture_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		elif new_value <= 75.0:
			fracture_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		else:
			fracture_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	
	# Update stage indicator
	_update_fracture_stage(new_value)

func _update_fracture_stage(value: float) -> void:
	if not fracture_stage_label:
		return
	
	if value >= 100.0:
		fracture_stage_label.text = "STAGE V — LOCKDOWN"
		fracture_stage_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1, 1.0))
		if fracture_debuff_label:
			fracture_debuff_label.text = "[ TIME ABILITIES DISABLED ]"
			fracture_debuff_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif value > 75.0:
		fracture_stage_label.text = "STAGE IV — CRITICAL"
		fracture_stage_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 0.9))
		if fracture_debuff_label:
			fracture_debuff_label.text = "[ +50% DMG Taken | -20% Speed | x2 Dash CD ]"
			fracture_debuff_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	elif value > 50.0:
		fracture_stage_label.text = "STAGE III — TEMPORAL DECAY"
		fracture_stage_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2, 0.8))
		if fracture_debuff_label:
			fracture_debuff_label.text = "[ -20% Speed | x2 Dash CD | -50% Crit Chance ]"
			fracture_debuff_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	elif value > 25.0:
		fracture_stage_label.text = "STAGE II — INSTABILITY"
		fracture_stage_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 0.7))
		if fracture_debuff_label:
			fracture_debuff_label.text = "[ -50% Crit Chance ]"
			fracture_debuff_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	else:
		fracture_stage_label.text = "STAGE I — STABLE"
		fracture_stage_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.7))
		if fracture_debuff_label:
			fracture_debuff_label.text = "[ All Systems Nominal ]"
			fracture_debuff_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.8))

func _on_lockdown_changed(is_lockdown: bool) -> void:
	if lockdown_warning:
		lockdown_warning.visible = is_lockdown
	
	if is_lockdown:
		# Pulse the lockdown warning
		if _lockdown_pulse_tween and _lockdown_pulse_tween.is_valid():
			_lockdown_pulse_tween.kill()
		_lockdown_pulse_tween = create_tween().set_loops()
		_lockdown_pulse_tween.tween_property(lockdown_warning, "modulate:a", 0.3, 0.3)
		_lockdown_pulse_tween.tween_property(lockdown_warning, "modulate:a", 1.0, 0.3)
		
		# Update state display
		if state_label:
			state_label.text = "[ LOCKDOWN ]"
			state_label.add_theme_color_override("font_color", STATE_COLORS["LOCKDOWN"])
	else:
		if _lockdown_pulse_tween and _lockdown_pulse_tween.is_valid():
			_lockdown_pulse_tween.kill()
			_lockdown_pulse_tween = null
		_update_state_display(TimeManager.current_state)

# =========================
# HEALTH
# =========================
func _on_player_damaged(new_health: float) -> void:
	_update_health(new_health)

func _update_health(hp: float) -> void:
	if hp_bar:
		hp_bar.value = hp
		
		# Color shift fill style: green → yellow → red
		var fill_style: StyleBoxFlat = hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
		var ratio: float = hp / 100.0
		if fill_style:
			if ratio > 0.5:
				fill_style.bg_color = Color(0.2, 0.9, 0.35)
			elif ratio > 0.25:
				fill_style.bg_color = Color(1.0, 0.85, 0.2)
			else:
				fill_style.bg_color = Color(1.0, 0.2, 0.2)
		
		# Border glow on HP panel
		if hp_panel:
			var panel_style: StyleBoxFlat = hp_panel.get_theme_stylebox("panel") as StyleBoxFlat
			if panel_style:
				if ratio > 0.5:
					panel_style.border_color = Color(0.3, 0.8, 0.4, 0.5)
				elif ratio > 0.25:
					panel_style.border_color = Color(1.0, 0.85, 0.2, 0.6)
				else:
					panel_style.border_color = Color(1.0, 0.2, 0.2, 0.8)
		
		# Flash on damage
		var tween := create_tween()
		tween.tween_property(hp_bar, "modulate:a", 0.5, 0.05)
		tween.tween_property(hp_bar, "modulate:a", 1.0, 0.1)
	
	if hp_label:
		hp_label.text = "HP: %d/100" % int(hp)
		# Color the label too
		var ratio: float = hp / 100.0
		if ratio > 0.5:
			hp_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.85))
		elif ratio > 0.25:
			hp_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		else:
			hp_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

# =========================
# DEATH SCREEN
# =========================
func _on_player_died() -> void:
	TimeManager.death_count += 1
	
	if state_label:
		state_label.text = "[ SEQUENCE TERMINATED ]"
		state_label.add_theme_color_override("font_color", Color.RED)
	
	# Hide lockdown warning if active
	if lockdown_warning:
		lockdown_warning.visible = false
	
	await get_tree().create_timer(1.5).timeout
	_show_death_screen()

func _show_death_screen() -> void:
	# Full-screen dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.03, 0.0, 0.05, 0.9)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Centered container using FULL_RECT + centered VBox
	var center_container := CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center_container)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	center_container.add_child(vbox)
	
	# Death title
	var death_text := Label.new()
	death_text.text = "SEQUENCE TERMINATED"
	death_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_text.add_theme_font_size_override("font_size", 28)
	death_text.add_theme_color_override("font_color", Color(1.0, 0.05, 0.2))
	vbox.add_child(death_text)
	
	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Temporal link severed."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.3, 0.4))
	vbox.add_child(subtitle)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)
	
	# Retry button
	var retry_btn := Button.new()
	retry_btn.text = "  REBOOT SEQUENCE  "
	retry_btn.custom_minimum_size = Vector2(200, 36)
	_style_death_button(retry_btn, Color(0.15, 0.4, 0.8))
	retry_btn.pressed.connect(func():
		TimeManager.reset_fracture(true)
		get_tree().reload_current_scene()
	)
	vbox.add_child(retry_btn)
	
	# Menu button
	var menu_btn := Button.new()
	menu_btn.text = "  EXIT TO VOID  "
	menu_btn.custom_minimum_size = Vector2(200, 36)
	_style_death_button(menu_btn, Color(0.4, 0.1, 0.15))
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	vbox.add_child(menu_btn)
	
	# Fade in the overlay
	overlay.modulate.a = 0.0
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	
	# Pulse the death title
	var title_tween := create_tween().set_loops()
	title_tween.tween_property(death_text, "modulate", Color(1.0, 0.3, 0.4), 1.0)
	title_tween.tween_property(death_text, "modulate", Color(1.0, 0.05, 0.2), 1.0)

func _style_death_button(btn: Button, base_color: Color) -> void:
	# Normal state
	var normal := StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.border_color = base_color.lightened(0.3)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", normal)
	
	# Hover state
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = base_color.lightened(0.2)
	hover.border_color = base_color.lightened(0.5)
	btn.add_theme_stylebox_override("hover", hover)
	
	# Pressed state
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = base_color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed)
	
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
