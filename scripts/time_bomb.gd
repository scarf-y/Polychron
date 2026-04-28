extends Area2D

const RADIUS: float = 80.0
const DAMAGE: float = 30.0
const COUNTDOWN_TIME: float = 3.0

var _timer: float = COUNTDOWN_TIME
var _label: Label = null
var _exploded: bool = false

func _ready() -> void:
	# Setup Collision
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	
	# Setup Label
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	_label.add_theme_color_override("font_outline_color", Color(0,0,0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.position = Vector2(-50, -12)
	_label.custom_minimum_size = Vector2(100, 24)
	add_child(_label)
	
	# Pop in animation
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _process(delta: float) -> void:
	if _exploded:
		return
		
	# Obey time scale
	_timer -= delta * Engine.time_scale
	
	if _timer <= 0.0:
		_explode()
	else:
		_label.text = "%.1f" % _timer
		queue_redraw()

func _draw() -> void:
	if _exploded:
		return
		
	# Draw outer warning ring
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 32, Color(1.0, 0.2, 0.2, 0.5), 2.0)
	
	# Draw inner fill based on time left
	var ratio := 1.0 - (_timer / COUNTDOWN_TIME)
	draw_circle(Vector2.ZERO, RADIUS * ratio, Color(1.0, 0.2, 0.2, 0.2))

func _explode() -> void:
	_exploded = true
	_label.visible = false
	
	# Check for player
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(DAMAGE)
	
	# Visual effects
	GameJuice.screen_shake(15.0, 1.0)
	GameJuice.spawn_death_particles(global_position, Color(1.0, 0.2, 0.2), 40)
	GameJuice.play_sfx("res://assets/audio/timeBomb.wav", -2.0)
	
	# Flash and fade out
	var tween := create_tween()
	tween.tween_method(func(a: float): modulate.a = a, 1.0, 0.0, 0.2)
	tween.tween_callback(queue_free)
