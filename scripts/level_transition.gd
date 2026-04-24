extends Area2D

## Level Transition — teleports player to next level when they enter this area.

@export var next_level_path: String = "res://scenes/levels/level_02.tscn"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Prevent death mid-transition
		if body.has_method("set"):
			body.set("_invincibility_timer", 999.0)
			
		# Reset time state before transitioning
		TimeManager.change_time_state(TimeManager.TimeState.NORMAL)
		
		# Use glitch transition instead of immediate scene change
		GameJuice.transition_to_scene(next_level_path)
