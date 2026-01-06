extends Area2D

@export var front_texture: Texture2D
@export var back_texture: Texture2D

@onready var sprite = $Front

var is_flipped = false
var flipping = false

func _ready():
	sprite.texture = front_texture
	sprite.scale.x = 1.0

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and not flipping:
		flip_card()

func flip_card():
	flipping = true

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)

	# Сжатие по X
	tween.tween_property(sprite, "scale:x", 0.0, 0.2)
	await tween.finished

	# Смена текстуры
	is_flipped = not is_flipped
	sprite.texture = back_texture if is_flipped else front_texture

	# Разворот обратно
	var tween_out = create_tween()
	tween_out.set_trans(Tween.TRANS_QUAD)
	tween_out.set_ease(Tween.EASE_OUT)

	tween_out.tween_property(sprite, "scale:x", 1.0, 0.2)
	await tween_out.finished

	flipping = false
