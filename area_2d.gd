extends Area2D

# Ссылка на главную карточку (Sprite2D)
@onready var Main_card := $Front

# Ссылки на подкарты (Sprite2D)
@onready var sub_cards := [
	$CanvasLayer/SubCard1,
	$CanvasLayer/SubCard2,
	$CanvasLayer/SubCard3,
	$CanvasLayer/SubCard4
]

@onready var flip_button := $CanvasLayer/FlipButton

var selected := false
var flipped := false  # Показывает, перевернуты ли карты

func _ready():
	hide_subcards()
	flip_button.pressed.connect(_on_flip_button_pressed)

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		toggle_selection()

func hide_subcards():
	var screen_size = get_viewport().get_visible_rect().size
	for i in range(sub_cards.size()):
		# Убираем карты вниз за пределы экрана
		sub_cards[i].position = Vector2(300 + i * 150, screen_size.y + 200)

func toggle_selection():
	selected = !selected

	var screen_size = get_viewport().get_visible_rect().size
	var hidden_y = screen_size.y + 200
	var shown_y = screen_size.y - 100
	var target_y = shown_y if selected else hidden_y

	for i in range(sub_cards.size()):
		var card = sub_cards[i]
		var target_x = 300 + i * 150

		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position", Vector2(target_x, target_y), 0.4 + i * 0.05)

# Функция вызывается по нажатию кнопки "Перевернуть карты"
func _on_flip_button_pressed():
	flipped = !flipped
	
	# Сначала переворачиваем главную карточку и ждем завершения
	await flip_card(Main_card, flipped)
	
	# Потом волной переворачиваем подкарты с задержкой
	for i in range(sub_cards.size()):
		var card = sub_cards[i]
		
		# Запускаем с задержкой в 0.1 сек * номер карты
		await get_tree().create_timer(0.05).timeout
		flip_card(card, flipped)


# Функция плавного переворота Sprite2D (анимация scale.x от 1 до 0 и обратно)
# Теперь эта функция async — чтобы можно было ждать её завершения
func flip_card(card: Sprite2D, to_back: bool) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# Сжатие
	tween.tween_property(card, "scale:x", 0.0, 0.15)
	tween.tween_callback(func():
		card.texture = card.get("back_texture") if to_back else card.get("front_texture")
	)
	# Расширение обратно
	tween.tween_property(card, "scale:x", 3.0, 0.15)

	# Дождаться завершения tween
	await tween.finished
