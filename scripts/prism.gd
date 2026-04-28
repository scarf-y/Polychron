extends CharacterBody2D

@export var health: float = 300.0
var is_dead: bool = false
var is_active_in_room: bool = true

enum State { IDLE, TELEGRAPH, FIRING }
var current_state: State = State.IDLE

var _timer: float = 0.0
const IDLE_TIME: float = 4.0
const TELEGRAPH_TIME: float = 1.5
const FIRING_TIME: float = 3.0

@onready var _laser_area: Area2D = $LaserArea
const LASER_WIDTH: float = 30.0
const LASER_LENGTH: float = 1200.0
const DAMAGE: float = 20.0
var _damage_timer: float = 0.0
const DAMAGE_TICK: float = 0.3

signal enemy_died(enemy: Node2D)

func _ready() -> void:
	add_to_group("enemies")
	
	# Ensure LaserArea is initially disabled
	_laser_area.monitoring = false
	_timer = IDLE_TIME

func _physics_process(delta: float) -> void:
	if is_dead or not is_active_in_room:
		return
		
	# Obey time stop for the enemy base
	if TimeManager.current_state == TimeManager.TimeState.STOPPED:
		modulate = Color(0.3, 0.3, 0.3)
		# Pause timer during time stop
		return
	elif TimeManager.current_state == TimeManager.TimeState.ERASED:
		modulate = Color(1.0, 0.5, 0.5, 0.5)
	else:
		modulate = Color.WHITE
		
	_timer -= delta * Engine.time_scale
	if _damage_timer > 0.0:
		_damage_timer -= delta * Engine.time_scale
		
	match current_state:
		State.IDLE:
			if _timer <= 0.0:
				current_state = State.TELEGRAPH
				_timer = TELEGRAPH_TIME
				GameJuice.screen_shake(2.0, 0.5)
				GameJuice.play_sfx("res://assets/audio/chargeBeam.wav", -6.0)
		State.TELEGRAPH:
			if _timer <= 0.0:
				current_state = State.FIRING
				_timer = FIRING_TIME
				_laser_area.monitoring = true
				GameJuice.screen_shake(8.0, 3.0)
				GameJuice.play_sfx("res://assets/audio/continuousBeam.wav", 5.0)
		State.FIRING:
			if _timer <= 0.0:
				current_state = State.IDLE
				_timer = IDLE_TIME
				_laser_area.monitoring = false
			else:
				# Deal continuous damage
				if _damage_timer <= 0.0:
					var hit_player = false
					for body in _laser_area.get_overlapping_bodies():
						if body.is_in_group("player") and body.has_method("take_damage"):
							body.take_damage(DAMAGE)
							hit_player = true
							GameJuice.screen_shake(4.0, 0.5)
					if hit_player:
						_damage_timer = DAMAGE_TICK
						
	queue_redraw()

func _draw() -> void:
	# Draw Core (Diamond)
	var points = PackedVector2Array([
		Vector2(0, -20), Vector2(20, 0), Vector2(0, 20), Vector2(-20, 0)
	])
	draw_polygon(points, PackedColorArray([Color(1, 0.2, 0.4)]))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 1, 1), 2.0)
	
	if current_state == State.TELEGRAPH:
		# Draw thin red warning cross
		var ext = LASER_LENGTH / 2.0
		var c = Color(1.0, 0.0, 0.0, 0.5 + sin(Time.get_ticks_msec()/50.0)*0.5)
		draw_rect(Rect2(-ext, -2, LASER_LENGTH, 4), c)
		draw_rect(Rect2(-2, -ext, 4, LASER_LENGTH), c)
	elif current_state == State.FIRING:
		var ext = LASER_LENGTH / 2.0
		var w = LASER_WIDTH / 2.0
		# Red outer
		draw_rect(Rect2(-ext, -w, LASER_LENGTH, LASER_WIDTH), Color(1.0, 0.2, 0.0, 0.8)) 
		draw_rect(Rect2(-w, -ext, LASER_WIDTH, LASER_LENGTH), Color(1.0, 0.2, 0.0, 0.8))
		
		# Inner yellow core
		draw_rect(Rect2(-ext, -w/2, LASER_LENGTH, LASER_WIDTH/2), Color(1.0, 1.0, 0.0, 1.0))
		draw_rect(Rect2(-w/2, -ext, LASER_WIDTH/2, LASER_LENGTH), Color(1.0, 1.0, 0.0, 1.0))
		
		# Random particles along the laser
		if randf() < 0.6:
			var rand_x = randf_range(-ext, ext)
			GameJuice.spawn_death_particles(global_position + Vector2(rand_x, 0), Color(1, 1, 0), 2)
			var rand_y = randf_range(-ext, ext)
			GameJuice.spawn_death_particles(global_position + Vector2(0, rand_y), Color(1, 1, 0), 2)

func take_damage(amount: float = 10.0) -> void:
	if is_dead: return
	health -= amount
	modulate = Color(1, 1, 1)
	await get_tree().create_timer(0.08).timeout
	if health <= 0.0:
		_die()

var _health_core_scene: PackedScene = preload("res://scenes/effects/health_core.tscn")
func _die() -> void:
	is_dead = true
	GameJuice.death_impact()
	GameJuice.spawn_death_particles(global_position, Color(1.0, 0.2, 0.4), 25)
	
	TimeManager.on_enemy_killed()
	if randf() <= 0.4:
		var core = _health_core_scene.instantiate()
		core.global_position = global_position
		get_tree().current_scene.add_child(core)
		
	enemy_died.emit(self)
	queue_free()
