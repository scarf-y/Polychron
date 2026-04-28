extends Node2D

## Tutorial Controller for The Vector Void.
## Handles the sequence of instructional steps and trigger zones.

@onready var player = $Player
@onready var instructions = $CanvasLayer/Instructions
@onready var step_label = $CanvasLayer/Instructions/StepLabel
@onready var info_label = $CanvasLayer/Instructions/InfoLabel

var current_step: int = 0
var _pending_step: bool = false
var steps = [
	{
		"title": "MOVEMENT",
		"info": "WASD to Move\nQ to Phase Dash (Invincibility)",
		"condition": "move"
	},
	{
		"title": "TIME SLOW",
		"info": "Hold SHIFT to Slow Time\nDrains the CHRONO BAR (Blue Bar)",
		"condition": "slow"
	},
	{
		"title": "TIME STOP",
		"info": "Hold SPACE to Stop Time\nDrains the CHRONO BAR quickly",
		"condition": "stop"
	},
	{
		"title": "TIME ERASE",
		"info": "Hold E to Erase Time\nYou become intangible and leave a DECOY\nEnemies target the decoy while you move freely",
		"condition": "erase"
	},
	{
		"title": "FRACTURE & LOCKDOWN",
		"info": "Abilities increase the FRACTURE METER (Red/Purple Bar)\n100% Fracture = LOCKDOWN (Abilities Locked)\nKill enemies to reduce Fracture and end Lockdown",
		"condition": "kill"
	},
	{
		"title": "TUTORIAL COMPLETE",
		"info": "You are ready to enter THE VECTOR VOID.\nPress ENTER to return to menu",
		"condition": "finish"
	}
]

func _ready() -> void:
	TimeManager.reset_fracture(true)
	TimeManager.game_is_active = true
	_update_step_ui()
	
	if has_node("Dummy"):
		$Dummy.dummy_killed.connect(_on_dummy_killed)
	
	# Connect to signals if needed
	TimeManager.lockdown_changed.connect(_on_lockdown_changed)

func _process(_delta: float) -> void:
	match current_step:
		0: # Movement
			if not _pending_step and (Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("move_left")):
				_pending_step = true
				_next_step_delayed(2.0)
		1: # Slow
			if not _pending_step and Input.is_action_just_pressed("time_slow"):
				_pending_step = true
				_next_step_delayed(3.0)
		2: # Stop
			if not _pending_step and Input.is_action_just_pressed("time_stop"):
				_pending_step = true
				_next_step_delayed(3.0)
		3: # Erase
			if not _pending_step and Input.is_action_just_pressed("time_erase"):
				_pending_step = true
				_next_step_delayed(4.0)
		4: # Kill/Fracture
			# This might be triggered by a dummy death or just waiting
			pass
		5: # Finish
			if Input.is_key_pressed(KEY_ENTER):
				GameJuice.transition_to_scene("res://scenes/ui/main_menu.tscn")

func _update_step_ui() -> void:
	_pending_step = false
	var step = steps[current_step]
	step_label.text = step.title
	info_label.text = step.info
	
	# Animate UI
	instructions.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(instructions, "modulate:a", 1.0, 0.5)

func _next_step_delayed(delay: float) -> void:
	if current_step >= steps.size() - 1: return
	
	# Use a one-shot timer to wait before moving to next step
	var t = get_tree().create_timer(delay)
	t.timeout.connect(func(): 
		if current_step < steps.size() - 1:
			current_step += 1
			_update_step_ui()
	)

func _on_lockdown_changed(is_lockdown: bool) -> void:
	if is_lockdown and current_step == 4:
		# Maybe show extra info about how to clear it
		info_label.text += "\n\nLOCKDOWN ACTIVE! Kill the dummy to clear it!"

func _on_dummy_killed() -> void:
	if current_step == 4 and not _pending_step:
		_pending_step = true
		_next_step_delayed(1.0)
