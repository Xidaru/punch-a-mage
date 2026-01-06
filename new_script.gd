extends Node2D

@onready var sub_cards := [
	$CanvasLayer/SubCard1,
	$CanvasLayer/SubCard2,
	$CanvasLayer/SubCard3,
	$CanvasLayer/SubCard4
]

var selected := false

func _ready():
	# Изначально спрятать за пределами экрана
	for i in range(sub_cards.size()):
		sub_cards[i].position = Vector2(300 + i * 150, 1200)  # внизу экрана

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		toggle_selection()

func toggle_selection():
	selected = !selected

	for i in range(sub_cards.size()):
		var card = sub_cards[i]
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		var target_y = 700.0 if selected else 1200.0  # вверх или вниз экрана
		var target_x = 300 + i * 150  # X — позиции по горизонтали

		tween.tween_property(card, "position", Vector2(target_x, target_y), 0.4 + i * 0.05)
