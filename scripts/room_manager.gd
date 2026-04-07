extends Node2D

## Room Manager — handles room locking/unlocking based on enemy count.
## Attach to a Node2D that contains an Area2D trigger and door nodes.

# --- Signals ---
signal room_entered(camera_rect: Rect2)
signal room_cleared()

# --- Config ---
@export var room_id: String = "room_0"
var is_active: bool = false
var is_cleared: bool = false
var enemies_in_room: Array[Node] = []

# Door references (set in _ready by finding children)
# Door references (set in _ready by finding children)
var doors: Array[StaticBody2D] = []

# Portal references
var portals: Array[Area2D] = []

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
	
	# Find all enemies in this room and put them to sleep initially
	# Find all enemies in this room and put them to sleep initially
	for child in get_children():
		if child.is_in_group("enemies"):
			enemies_in_room.append(child)
			child.connect("enemy_died", _on_enemy_died)
			if "is_active_in_room" in child:
				child.is_active_in_room = false
	
	# Find adjacent portals (siblings or anywhere else we can infer, actually let's just find children named *Portal)
	# Wait, portals are siblings. We need to check if the parent has "Portal" children, or just use groups.
	# Simplest: export var, but since we modify via script, let's look for LevelPortal/BossPortal in the scene tree.
	# Even simpler: attach the portal as a child of RoomManager! If a child is an Area2D and has "Portal" in name:
	for child in get_children():
		if child is Area2D and "Portal" in child.name:
			portals.append(child)
			child.visible = false
			for grand_child in child.get_children():
				if grand_child is CollisionShape2D:
					grand_child.set_deferred("disabled", true)

func _on_trigger_body_entered(body: Node2D) -> void:
	if is_active or is_cleared:
		return
	if body.is_in_group("player"):
		_activate_room(body)

func _activate_room(player: Node2D) -> void:
	is_active = true
	
	# Compute room bounds based on trigger shape
	var room_rect := Rect2()
	var trigger := get_node_or_null("RoomTrigger/Col") as CollisionShape2D
	if trigger and trigger.shape is RectangleShape2D:
		var rect_shape := trigger.shape as RectangleShape2D
		room_rect = Rect2(trigger.global_position - rect_shape.size / 2.0, rect_shape.size)
	
	if player.has_method("set_camera_limits") and room_rect.has_area():
		player.set_camera_limits(room_rect)
	
	# Wake up enemies
	for enemy in enemies_in_room:
		if is_instance_valid(enemy) and "is_active_in_room" in enemy:
			enemy.is_active_in_room = true
	
	room_entered.emit(room_rect)
	
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
	
	# Unlock doors EXCEPT "DoorBack"
	for door in doors:
		if door.name.begins_with("DoorBack"):
			continue # Leave it locked forever
		door.visible = false
		_set_door_collision(door, false)
	
	# Show and enable portals
	for portal in portals:
		portal.visible = true
		for child in portal.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", false)

func _set_door_collision(door: StaticBody2D, enabled: bool) -> void:
	for child in door.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not enabled)

## Register an enemy spawned at runtime
func register_enemy(enemy: Node) -> void:
	if not is_cleared:
		enemies_in_room.append(enemy)
		enemy.connect("enemy_died", _on_enemy_died)
