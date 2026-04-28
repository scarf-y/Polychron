extends CharacterBody2D

signal dummy_killed

@export var health: float = 1.0 # 1 hit to kill

func _ready() -> void:
	add_to_group("enemies")

func take_damage(_amount: float) -> void:
	# Dummies just die instantly for tutorial flow
	_die()

func _die() -> void:
	GameJuice.death_impact()
	GameJuice.spawn_death_particles(global_position, Color(1, 1, 1), 15)
	TimeManager.on_enemy_killed() # Reduces fracture
	dummy_killed.emit()
	
	# Notify parent if it's the tutorial level
	if get_parent().has_method("_on_dummy_killed"):
		get_parent()._on_dummy_killed()
		
	queue_free()

func _draw() -> void:
	# Draw a simple target-like shape
	draw_circle(Vector2.ZERO, 15, Color(0.8, 0.8, 0.8))
	draw_circle(Vector2.ZERO, 10, Color(1.0, 0.2, 0.2))
	draw_circle(Vector2.ZERO, 5, Color(1.0, 1.0, 1.0))
