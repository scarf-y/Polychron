extends Area2D

## Level Transition — teleports player to next level when they enter this area.

@export var next_level_path: String = "res://scenes/levels/level_02.tscn"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Reset time state before transitioning
		TimeManager.change_time_state(TimeManager.TimeState.NORMAL)
		get_tree().change_scene_to_file(next_level_path)
