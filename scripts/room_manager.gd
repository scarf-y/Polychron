extends Node2D

## Room Manager — handles room locking/unlocking based on enemy count.
## Attach to a Node2D that contains an Area2D trigger and door nodes.

# --- Signals ---
signal room_entered()
signal room_cleared()

# --- Config ---
@export var room_id: String = "room_0"
var is_active: bool = false
var is_cleared: bool = false
var enemies_in_room: Array[Node] = []

# Door references (set in _ready by finding children)
var doors: Array[StaticBody2D] = []

func _ready() -> void:
	# Find the trigger area
	var trigger := get_node_or_null("RoomTrigger") as Area2D
	if trigger:
		trigger.body_entered.connect(_on_trigger_body_entered)
	
	# Find all door nodes (children named "Door*")
	for child in get_children():
		if child is StaticBody2D and child.name.begins_with("Door"):
			doors.append(child)
			# Doors start open (disabled)
			child.visible = false
			_set_door_collision(child, false)
	
	# Find all enemies in this room
	for child in get_children():
		if child.is_in_group("enemies"):
			enemies_in_room.append(child)
			child.connect("enemy_died", _on_enemy_died)

func _on_trigger_body_entered(body: Node2D) -> void:
	if is_active or is_cleared:
		return
	if body.is_in_group("player"):
		_activate_room()

func _activate_room() -> void:
	is_active = true
	room_entered.emit()
	
	if enemies_in_room.size() == 0:
		_clear_room()
		return
	
	# Lock doors
	for door in doors:
		door.visible = true
		_set_door_collision(door, true)

func _on_enemy_died(enemy: Node) -> void:
	enemies_in_room.erase(enemy)
	
	if enemies_in_room.size() == 0 and is_active:
		_clear_room()

func _clear_room() -> void:
	is_cleared = true
	is_active = false
	room_cleared.emit()
	
	# Unlock doors
	for door in doors:
		door.visible = false
		_set_door_collision(door, false)

func _set_door_collision(door: StaticBody2D, enabled: bool) -> void:
	for child in door.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not enabled)

## Register an enemy spawned at runtime
func register_enemy(enemy: Node) -> void:
	if not is_cleared:
		enemies_in_room.append(enemy)
		enemy.connect("enemy_died", _on_enemy_died)
