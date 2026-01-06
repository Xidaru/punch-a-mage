extends Node2D 

# Состояния игры
enum GameState { PLAYER_TURN, ENEMY_TURN, GAME_OVER }

# Эффекты карт
enum CardEffect { ATTACK, DEFENSE, HEAL, FLIP, FIREBALL, SUMMON, DRAW_CARDS, STRENGTH, VULNERABLE }

enum EnemyAction { ATTACK_PLAYER, ATTACK_ALL, DEFEND }

# Параметры игрока
var player_hp := 100
var player_max_hp := 100
var energy := 3
var max_energy := 3
var player_block := 0  # Блокируемый урон
var player_gold := 0  # НОВОЕ: золото игрока
var game_state = GameState.PLAYER_TURN
var player_strength := 0  # ДОБАВЬТЕ ЭТУ СТРОКУ

# Карты и враги
var is_flipping := false
var is_animation_locked := false  # Глобальная блокировка действий во время анимации
var highlighted_card: Area2D = null
var hovered_card: Area2D = null
var selected_card: Area2D = null
var attack_mode := false
var current_attack_card: Area2D = null
@onready var card_manager = preload("res://CardManager.gd").new() #Дата база карт
@onready var enemy_manager = preload("res://EnemyManager.gd").new()  # НОВОЕ: менеджер врагов
@onready var Main_card_area := $MainCardArea as Area2D
@onready var flip_button := $CanvasLayer/FlipButton
@onready var end_turn_button := $CanvasLayer/EndTurnButton
@onready var SubCardScene := preload("res://SubCard.tscn")
@onready var enemy_scene := preload("res://Enemy.tscn")
var main_card_sprite: Sprite2D
var enemy_instance: Node2D
var card_area_margin := 100
var card_max_spacing := 150
var card_width := 100
var sub_cards := []  # Карты в руке
var selected := false
var flipped := false
var animation_speed := 5.0
var enemy_highlight_tween: Tween
var original_main_card_scale: Vector2

# НОВОЕ: Система стопок карт
var draw_pile := []  # Стопка добора
var discard_pile := []  # Стопка сброса
var cards_per_turn := 6  # Количество карт, которые берутся за ход

#Summons
@onready var summon_scene := preload("res://Summon.tscn")
var summons := []  # Массив активных саммонов
var max_summons := 3  # Максимум саммонов одновременно

# Хранилище исходных параметров
var original_enemy_scale: Vector2
var original_enemy_position: Vector2
var original_enemy_modulate: Color
var original_card_scales: Dictionary = {}
var original_card_positions: Dictionary = {}

var transformation_progress := 0  # Текущий прогресс трансформации
var transformation_threshold := 5  # Карт для трансформации в форму 2
var transformation_threshold_return := 10  # Карт для возврата в форму 1
var player_transformed := false  # Текущая форма (false = форма 1, true = форма 2)

# UI элементы
@onready var player_hp_label := $CanvasLayer/PlayerHPLabel
@onready var energy_label := $CanvasLayer/EnergyLabel
@onready var block_label := $CanvasLayer/BlockLabel
@onready var turn_label := $CanvasLayer/TurnLabel
@onready var game_over_screen := $CanvasLayer/GameOverScreen
@onready var draw_pile_label := $CanvasLayer/DrawPileLabel
@onready var discard_pile_label := $CanvasLayer/DiscardPileLabel
@onready var gold_label := $CanvasLayer/GoldLabel
var transformation_bar: ProgressBar  # НОВОЕ: Шкала трансформации
var transformation_label: Label  # НОВОЕ: Текст на шкале
var enemy_burn_label: Label  # Метка для отображения числа Burn
var enemy_burn_sprite: Sprite2D  # Спрайт для иконки Burn
# НОВОЕ: Tooltip для карт
var card_tooltip: PanelContainer
var tooltip_label: RichTextLabel
# НОВОЕ: Tooltip для врага
var enemy_tooltip: PanelContainer
var enemy_tooltip_label: RichTextLabel
# Текстуры карт
@onready var attack_texture = preload("res://attack_card.png")
@onready var defense_texture = preload("res://defense_card.png")
@onready var heal_texture = preload("res://heal_card.png")
@onready var flip_texture = preload("res://Back.png")
@onready var front_texture = preload("res://Front.png")
@onready var back_texture = preload("res://Back.png")
@onready var fireball_texture = preload("res://Fireball.png") if ResourceLoader.exists("res://Fireball.png") else preload("res://attack_card.png")
@onready var burn_texture = preload("res://Burn.png")  # Текстура иконки огня
@onready var attackfunny_texture = preload("res://Counterattackmeme.png")


func _ready():
	add_child(card_manager)
	
	# Создаем tooltip для карт
	create_card_tooltip()
	# НОВОЕ: Создаем tooltip для врага
	create_enemy_tooltip()
	# НОВОЕ: Создаем шкалу трансформации
	create_transformation_bar()	
	# Получаем спрайт главной карты
	main_card_sprite = Main_card_area.get_node("Sprite2D")
	original_main_card_scale = main_card_sprite.scale
	
	# Отключаем фильтрацию для пиксель-арта главной карты
	main_card_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Инициализация главной карты
	main_card_sprite.set_meta("front_texture", front_texture)
	main_card_sprite.set_meta("back_texture", back_texture)
	main_card_sprite.set_meta("flipped", false)
	main_card_sprite.texture = front_texture
	
	# Подключаем сигналы главной карты
	Main_card_area.connect("input_event", Callable(self, "_on_main_card_input"))
	Main_card_area.connect("mouse_entered", Callable(self, "_on_main_card_mouse_entered"))
	Main_card_area.connect("mouse_exited", Callable(self, "_on_main_card_mouse_exited"))
	
	# Подключаем кнопки
	flip_button.pressed.connect(_on_flip_button_pressed)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	
	# Инициализация UI
	update_ui()
	game_over_screen.visible = false
	
	# Инициализация системы карт
	initialize_card_system()
	
	print("=== SPAWNING FIRST ENEMY ===")
	await spawn_enemy()
	print("=== FIRST ENEMY SPAWNED ===")
	if enemy_instance:
		print("First enemy HP: %d/%d" % [enemy_instance.current_hp, enemy_instance.max_hp])
	
	# ИСПРАВЛЕНО: Обновляем UI после создания первого врага
	await get_tree().process_frame
	update_ui()

	# Начинаем ход игрока
	start_player_turn()


# Инициализация системы карт
func initialize_card_system():
	# Создаем начальную колоду
	for i in range(15):
		var card = create_random_card()
		draw_pile.append(card)
	
	# Добавляем 5 карт Fireball
	for i in range(5):
		var fireball_card = create_fireball_card()
		draw_pile.append(fireball_card)
	
	# НОВОЕ: Добавляем карты призыва
	for i in range(3):
		var summon_card = create_summon_card("damage")
		draw_pile.append(summon_card)
	
		# НОВОЕ: Добавляем карты с добором
	for i in range(3):
		var attack_draw = create_attack_draw_card()
		draw_pile.append(attack_draw)
	
	for i in range(3):
		var defense_draw = create_defense_draw_card()
		draw_pile.append(defense_draw)
	
		# НОВОЕ: Добавляем карты силы
	for i in range(3):
		var strength_card = create_strength_card()
		draw_pile.append(strength_card)
	
	# НОВОЕ: Добавляем карты уязвимости
	for i in range(3):
		var vulnerable_card = create_vulnerable_card()
		draw_pile.append(vulnerable_card)
	
	# Создаем специальную карту
	var attack_heal_card = create_specific_card()
	if attack_heal_card:
		draw_pile.append(attack_heal_card)
	
	# Перемешиваем колоду
	shuffle_draw_pile()
	update_pile_counts()


# Создание случайной карты
func create_random_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	
	# Отключаем фильтрацию для пиксель-арта
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# НОВОЕ: Автоматически подгоняем размер текстуры
	fit_texture_to_card(sprite, 100.0)
	
	# Сохраняем исходные параметры карты
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	# Случайные эффекты для карты
	var back_effect_type = randi() % 3
	
	# Устанавливаем текстуры
	sprite.set_meta("front_texture", attack_texture)
	sprite.texture = attack_texture
	
	# Текстура для обратной стороны
	match back_effect_type:
		0:
			sprite.set_meta("back_texture", defense_texture)
			card.set_meta("back_effect_type", CardEffect.DEFENSE)
		1:
			sprite.set_meta("back_texture", heal_texture)
			card.set_meta("back_effect_type", CardEffect.HEAL)
		2:
			sprite.set_meta("back_texture", flip_texture)
			card.set_meta("back_effect_type", CardEffect.FLIP)
	
	# Создаем эффекты
	var front_effect_value = randi_range(15, 30)
	var back_effect_value = randi_range(10, 20)
	
	if back_effect_type == 2:
		back_effect_value = 0
	
	card.set_meta("front_effect_type", CardEffect.ATTACK)
	card.set_meta("front_effect_value", front_effect_value)
	card.set_meta("back_effect_value", back_effect_value)
	card.set_meta("cost", 1)
	card.set_meta("flipped", false)
	
	# Добавляем RichTextLabel для значения эффекта
	var value_label = RichTextLabel.new()
	value_label.name = "ValueLabel"
	value_label.position = Vector2(10, 70)
	value_label.size = Vector2(80, 40)
	value_label.bbcode_enabled = true
	value_label.scroll_active = false
	value_label.fit_content = true
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.focus_mode = Control.FOCUS_NONE
	
	card.add_child(value_label)
	update_card_value_label(card)

	# Подключаем сигналы
	card.connect("mouse_entered", Callable(self, "_on_card_hover_entered").bind(card))
	card.connect("mouse_exited", Callable(self, "_on_card_hover_exited").bind(card))
	card.connect("input_event", Callable(self, "_on_card_input").bind(card))
	
	card.visible = false
	
	return card


# Создание карты Fireball
func create_fireball_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	
	# Отключаем фильтрацию для пиксель-арта
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Сохраняем исходные параметры карты
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	# Устанавливаем текстуры
	sprite.set_meta("front_texture", fireball_texture)
	sprite.texture = fireball_texture
	
	# Обратная сторона - случайная
	var back_effect_type = randi() % 3
	match back_effect_type:
		0:
			sprite.set_meta("back_texture", defense_texture)
			card.set_meta("back_effect_type", CardEffect.DEFENSE)
			card.set_meta("back_effect_value", randi_range(10, 20))
		1:
			sprite.set_meta("back_texture", heal_texture)
			card.set_meta("back_effect_type", CardEffect.HEAL)
			card.set_meta("back_effect_value", randi_range(10, 20))
		2:
			sprite.set_meta("back_texture", flip_texture)
			card.set_meta("back_effect_type", CardEffect.FLIP)
			card.set_meta("back_effect_value", 0)
	
	# Фиксированные параметры для Fireball
	card.set_meta("front_effect_type", CardEffect.FIREBALL)
	card.set_meta("front_effect_value", 10)
	card.set_meta("burn_value", 10)
	card.set_meta("cost", 1)
	card.set_meta("flipped", false)
	
	# Добавляем RichTextLabel
	var value_label = RichTextLabel.new()
	value_label.name = "ValueLabel"
	value_label.position = Vector2(10, 70)
	value_label.size = Vector2(80, 40)
	value_label.bbcode_enabled = true
	value_label.scroll_active = false
	value_label.fit_content = true
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.focus_mode = Control.FOCUS_NONE
	
	card.add_child(value_label)
	update_card_value_label(card)
	
	# Подключаем сигналы
	card.connect("mouse_entered", Callable(self, "_on_card_hover_entered").bind(card))
	card.connect("mouse_exited", Callable(self, "_on_card_hover_exited").bind(card))
	card.connect("input_event", Callable(self, "_on_card_input").bind(card))
	
	card.visible = false
	
	return card


# Создание специальной карты
func create_specific_card() -> Area2D:
	var card = card_manager.get_card("CustomcardTest")
	if card:
		setup_card(card)
		card.visible = false
	return card


func setup_card(card: Area2D):
	$CanvasLayer.add_child(card)
	
	var sprite = card.get_node("Sprite2D")
	
	# НОВОЕ: Автоматически подгоняем размер
	fit_texture_to_card(sprite, 50.0)
	
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	card.connect("mouse_entered", Callable(self, "_on_card_hover_entered").bind(card))
	card.connect("mouse_exited", Callable(self, "_on_card_hover_exited").bind(card))
	card.connect("input_event", Callable(self, "_on_card_input").bind(card))


func shuffle_draw_pile():
	draw_pile.shuffle()


# Взятие карт из стопки добора
func draw_cards(count: int):
	for i in range(count):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			shuffle_draw_pile()
		
		var card = draw_pile.pop_front()
		
		# ИСПРАВЛЕНО: Полностью сбрасываем состояние карты
		var sprite = card.get_node("Sprite2D")
		var shape = card.get_node("CollisionShape2D")
		if sprite:
			sprite.position = Vector2.ZERO
			# ВАЖНО: Восстанавливаем исходный масштаб из сохраненного
			if original_card_scales.has(card):
				sprite.scale = original_card_scales[card]
			else:
				# Если масштаб не сохранен, используем стандартный
				sprite.scale = Vector2(3, 3)  # Или ваш стандартный масштаб
			sprite.modulate = Color(1, 1, 1)
		if shape:
			shape.position = Vector2.ZERO
		
		sub_cards.append(card)
		card.visible = true
	
	update_pile_counts()


# Сброс карты в стопку сброса
func discard_card(card: Area2D):
	if card in sub_cards:
		sub_cards.erase(card)
	
	if not card in discard_pile:
		discard_pile.append(card)
	
	# Сбрасываем позицию спрайта и коллизии
	var sprite = card.get_node("Sprite2D")
	var shape = card.get_node("CollisionShape2D")
	if sprite:
		sprite.position = Vector2.ZERO
	if shape:
		shape.position = Vector2.ZERO
	
	card.visible = false
	update_pile_counts()
	layout_subcards()


# Обновление счетчиков стопок
func update_pile_counts():
	if draw_pile_label:
		draw_pile_label.text = "Draw: %d" % draw_pile.size()
	if discard_pile_label:
		discard_pile_label.text = "Discard: %d" % discard_pile.size()


func spawn_enemy():
	enemy_instance = enemy_scene.instantiate()
	add_child(enemy_instance)
	enemy_instance.position = Vector2(600, 200)
	
	# Подключаем сигнал смерти
	enemy_instance.connect("enemy_died", Callable(self, "on_enemy_died"))
	
	# Загружаем данные врага из EnemyManager
	var enemy_data = enemy_manager.get_random_enemy()
	enemy_instance.current_hp = enemy_data["hp"]
	enemy_instance.max_hp = enemy_data["hp"]
	enemy_instance.attack_damage = enemy_data.get("attack_damage", 20)
	enemy_instance.block = 0  # НОВОЕ
	enemy_instance.possible_actions = enemy_data.get("actions", [  # НОВОЕ
		{"type": EnemyAction.ATTACK_PLAYER, "weight": 100}
	])
	enemy_instance.set_meta("reward_gold", enemy_data["reward_gold"])
	enemy_instance.set_meta("enemy_name", enemy_data.get("name", "Enemy"))
	
	# Устанавливаем текстуру врага
	var enemy_sprite = enemy_instance.get_node("Sprite2D")
	if ResourceLoader.exists(enemy_data["texture"]):
		enemy_sprite.texture = load(enemy_data["texture"])
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Сохраняем исходный размер врага ПОСЛЕ загрузки текстуры
	original_enemy_scale = enemy_sprite.scale
	original_enemy_position = enemy_instance.position
	original_enemy_modulate = enemy_sprite.modulate
	
	# Инициализируем Burn
	if not enemy_instance.has_meta("burn"):
		enemy_instance.set_meta("burn", 0)
	
	# Создаём отображение Burn
	create_enemy_burn_display()
	
	# Подключаем сигналы врага
	if enemy_instance.has_method("connect"):
		enemy_instance.connect("input_event", Callable(self, "_on_enemy_input"))
		enemy_instance.connect("mouse_entered", Callable(self, "_on_enemy_mouse_entered"))
		enemy_instance.connect("mouse_exited", Callable(self, "_on_enemy_mouse_exited"))
	
	# НОВОЕ: Выбираем первое действие
	if enemy_instance.has_method("choose_next_action"):
		enemy_instance.choose_next_action()
	
	# Обновляем UI врага после установки HP
	await get_tree().process_frame
	if enemy_instance and enemy_instance.has_method("update_ui"):
		enemy_instance.update_ui()
	
	update_ui()


# Создание отображения Burn (спрайт иконки + число)
func create_enemy_burn_display():
	if not enemy_instance:
		return
	
	# Удаляем старые элементы
	if enemy_burn_label:
		enemy_burn_label.queue_free()
	if enemy_burn_sprite:
		enemy_burn_sprite.queue_free()
	
	# Создаем спрайт для иконки Burn.png
	enemy_burn_sprite = Sprite2D.new()
	enemy_burn_sprite.texture = burn_texture
	enemy_burn_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy_burn_sprite.scale = Vector2(3, 3)
	# НОВОЕ: Сохраняем исходный размер Burn спрайта
	enemy_burn_sprite.set_meta("original_scale", Vector2(3, 3))
	enemy_burn_sprite.visible = false
	enemy_instance.add_child(enemy_burn_sprite)
	
	# Создаем метку для числа
	enemy_burn_label = Label.new()
	enemy_burn_label.name = "BurnLabel"
	enemy_burn_label.add_theme_font_size_override("font_size", 20)
	enemy_burn_label.add_theme_color_override("font_color", Color(1, 1, 1))
	enemy_burn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	enemy_burn_label.add_theme_constant_override("outline_size", 2)
	enemy_burn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_burn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enemy_burn_label.visible = false
	enemy_burn_label.z_index = 1
	enemy_instance.add_child(enemy_burn_label)
	
	update_enemy_burn_display()


# Обновление отображения Burn
func update_enemy_burn_display():
	# НОВОЕ: Проверяем валидность
	if not enemy_instance or not is_instance_valid(enemy_instance) or not enemy_burn_label or not enemy_burn_sprite:
		return

	var burn = enemy_instance.get_meta("burn", 0)

	if burn > 0:
		enemy_burn_label.text = str(burn)
		enemy_burn_label.visible = true
		enemy_burn_sprite.visible = true
		
		var enemy_sprite = enemy_instance.get_node_or_null("Sprite2D")
		if not enemy_sprite:
			return
			
		var enemy_sprite_height = enemy_sprite.texture.get_height() * enemy_sprite.scale.y
		
		var offset_y = enemy_sprite_height / 2 + 60
		enemy_burn_sprite.position = Vector2(0, offset_y)
		
		enemy_burn_label.position = Vector2(-10, offset_y - 10)
		enemy_burn_label.size = Vector2(20, 20)
	else:
		enemy_burn_label.visible = false
		enemy_burn_sprite.visible = false


func layout_subcards():
	if is_animation_locked:
		return
		
	var screen_size = get_viewport().get_visible_rect().size
	var available_width = screen_size.x - 2 * card_area_margin
	var target_y = screen_size.y - 100 if selected else screen_size.y + 200
	var total_cards = sub_cards.size()

	if total_cards == 0:
		return

	var start_x: float
	var spacing: float

	if total_cards == 1:
		start_x = card_area_margin + (available_width - card_width) / 2.0
	else:
		var total_width_needed = card_width + (total_cards - 1) * card_max_spacing
		if total_width_needed <= available_width:
			spacing = card_max_spacing
			start_x = card_area_margin + (available_width - total_width_needed) / 2.0
		else:
			spacing = (available_width - card_width) / (total_cards - 1)
			start_x = card_area_margin

	for i in range(total_cards):
		var card = sub_cards[i]
		var target_x = start_x + i * spacing
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position", Vector2(target_x, target_y), (0.4 + i * 0.02) / animation_speed)

func _process(delta):
	# Удаляем мертвых саммонов из массива
	summons = summons.filter(func(s): return is_instance_valid(s))

func _on_main_card_input(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		toggle_selection()

func _on_main_card_mouse_entered():
	if not is_animation_locked:
		var tween = create_tween()
		tween.tween_property(main_card_sprite, "scale", original_main_card_scale * 1.1, 0.2)

func _on_main_card_mouse_exited():
	if not is_animation_locked:
		var tween = create_tween()
		tween.tween_property(main_card_sprite, "scale", original_main_card_scale, 0.2)

func toggle_selection():
	if is_animation_locked:
		return
		
	selected = !selected
	layout_subcards()

func _on_flip_button_pressed():
	if is_flipping or game_state != GameState.PLAYER_TURN or is_animation_locked:
		return
		
	is_animation_locked = true
	await flip_all_cards_in_deck()
	
	# НОВОЕ: Синхронизируем состояние трансформации
	player_transformed = flipped
	transformation_progress = 0
	
	var new_threshold = transformation_threshold_return if flipped else transformation_threshold
	transformation_bar.max_value = new_threshold
	update_transformation_ui()
	
	is_animation_locked = false
	layout_subcards()

func flip_card(card_node: Node, to_back: bool) -> void:
	var sprite: Sprite2D
	
	if card_node is Sprite2D:
		sprite = card_node
		await flip_card_sprite(sprite, to_back)
		sprite.set_meta("flipped", to_back)
	elif card_node is Area2D:
		sprite = card_node.get_node("Sprite2D") as Sprite2D
		if sprite:
			await flip_card_sprite(sprite, to_back)
			card_node.set_meta("flipped", to_back)

func flip_card_sprite(sprite: Sprite2D, to_back: bool) -> void:
	var start_scale_x = sprite.scale.x
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "scale:x", 0.01, 0.15 / animation_speed)
	tween.tween_callback(func():
		var tex = sprite.get_meta("back_texture") if to_back else sprite.get_meta("front_texture")
		if tex:
			sprite.texture = tex
	)
	tween.tween_property(sprite, "scale:x", start_scale_x, 0.1 / animation_speed)
	await tween.finished

func _on_card_hover_entered(card: Area2D) -> void:
	if selected_card == card || attack_mode || game_state != GameState.PLAYER_TURN || is_animation_locked:
		return
	
	if not original_card_scales.has(card):
		return
	
	# НОВОЕ: Если уже есть наведенная карта, сбрасываем её
	if hovered_card and hovered_card != card:
		_on_card_hover_exited(hovered_card)
	
	hovered_card = card
	
	var sprite := card.get_node("Sprite2D")
	var original_scale = original_card_scales[card]
	var tween = create_tween()
	tween.tween_property(sprite, "scale", original_scale * 1.2, 0.2 / animation_speed)
	tween.tween_property(sprite, "modulate", Color(1, 1, 0.8), 0.2 / animation_speed)
	
	# НОВОЕ: Показываем tooltip только для наведенной карты
	show_card_tooltip(card)

func _on_card_hover_exited(card: Area2D) -> void:
	if selected_card == card || attack_mode || game_state != GameState.PLAYER_TURN || is_animation_locked:
		return
	
	if not original_card_scales.has(card):
		return
	
	# НОВОЕ: Сбрасываем только если это текущая наведенная карта
	if hovered_card == card:
		hovered_card = null
	
	var sprite := card.get_node("Sprite2D")
	var original_scale = original_card_scales[card]
	var tween = create_tween()
	tween.tween_property(sprite, "scale", original_scale, 0.2 / animation_speed)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2 / animation_speed)
	
	# НОВОЕ: Скрываем tooltip только если это была наведенная карта
	if card == hovered_card or hovered_card == null:
		hide_card_tooltip()

# Показать tooltip карты
func show_card_tooltip(card: Area2D):
	if not card_tooltip or not tooltip_label:
		return
	
	# НОВОЕ: Проверяем что это действительно наведенная карта
	if hovered_card != card:
		return
	
	tooltip_label.text = get_card_description(card)
	
	# НОВОЕ: Принудительно обновляем размер tooltip
	await get_tree().process_frame
	tooltip_label.reset_size()
	card_tooltip.reset_size()
	
	card_tooltip.visible = true
	
	# Позиционируем tooltip
	var card_pos = card.global_position
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = card_tooltip.size
	
	# ИСПРАВЛЕНО: Умная позиция tooltip
	var tooltip_pos = Vector2()
	
	# Пробуем справа от карты
	tooltip_pos.x = card_pos.x + 120
	tooltip_pos.y = card_pos.y - tooltip_size.y / 2
	
	# Если не влезает справа, ставим слева
	if tooltip_pos.x + tooltip_size.x > screen_size.x - 20:
		tooltip_pos.x = card_pos.x - tooltip_size.x - 20
	
	# Если не влезает слева, центрируем по горизонтали
	if tooltip_pos.x < 20:
		tooltip_pos.x = (screen_size.x - tooltip_size.x) / 2
	
	# Проверяем вертикальные границы
	if tooltip_pos.y < 20:
		tooltip_pos.y = 20
	elif tooltip_pos.y + tooltip_size.y > screen_size.y - 20:
		tooltip_pos.y = screen_size.y - tooltip_size.y - 20
	
	card_tooltip.global_position = tooltip_pos

# Скрыть tooltip карты
func hide_card_tooltip():
	if card_tooltip:
		card_tooltip.visible = false

func _on_card_input(viewport, event, shape_idx, card: Area2D) -> void:
	if game_state != GameState.PLAYER_TURN or is_animation_locked or is_flipping:
		return
		
	if event is InputEventMouseButton and event.pressed:
		hide_card_tooltip()
		hovered_card = null
		
		var sprite = card.get_node("Sprite2D")
		var shape = card.get_node("CollisionShape2D")
		var card_cost = card.get_meta("cost", 1)
		
		if energy < card_cost:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
			tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
			return
		
		var effect = get_current_card_effect(card)
		
		# ОБНОВЛЕНО: Карты силы и уязвимости не требуют цели для силы, требуют для уязвимости
		if effect["type"] in [CardEffect.SUMMON, CardEffect.DEFENSE, CardEffect.HEAL, CardEffect.FLIP, CardEffect.STRENGTH]:
			match effect["type"]:
				CardEffect.SUMMON:
					await apply_summon_effect(effect, card_cost, card)
				CardEffect.DEFENSE:
					await apply_defense_effect(effect, card_cost, card)
				CardEffect.HEAL:
					await apply_heal_effect(effect, card_cost, card)
				CardEffect.FLIP:
					await apply_flip_effect(effect, card_cost, card)
				CardEffect.STRENGTH:  # НОВОЕ
					await apply_strength_effect(effect, card_cost, card)
			return
		
		# Остальные карты требуют выбора цели (включая VULNERABLE)
		if current_attack_card and current_attack_card != card:
			reset_card_highlight(current_attack_card)
			layout_subcards()
		
		if current_attack_card == card:
			reset_card_highlight(card)
			current_attack_card = null
			attack_mode = false
			reset_enemy_highlight()
			layout_subcards()
		else:
			current_attack_card = card
			attack_mode = true
			
			if not original_card_scales.has(card):
				return
			
			var original_scale = original_card_scales[card]
			var tween = create_tween()
			tween.tween_property(sprite, "position:y", sprite.position.y - 30, 0.2 / animation_speed)
			tween.tween_property(shape, "position:y", shape.position.y - 30, 0.2 / animation_speed)
			tween.tween_property(sprite, "scale", original_scale * 1.3, 0.2 / animation_speed)
			tween.tween_property(sprite, "modulate", Color(1, 0.8, 0.8), 0.2 / animation_speed)
			
			highlight_enemy()

func apply_summon_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	var summon_type = card.get_meta("summon_type", "basic")
	var summon = spawn_summon(summon_type)
	
	if summon:
		var summon_sprite = summon.get_node("Sprite2D")
		summon_sprite.scale = Vector2(0.01, 0.01)
		var tween = create_tween()
		tween.tween_property(summon_sprite, "scale", Vector2(3, 3), 0.3)
	
	discard_card(card)
	
	# НОВОЕ: Увеличиваем прогресс и проверяем трансформацию
	add_transformation_progress()
	await check_and_transform()

func end_player_turn():
	game_state = GameState.ENEMY_TURN
	turn_label.text = "Enemy Turn"
	end_turn_button.disabled = true
	
	# НОВОЕ: Саммоны атакуют перед ходом врага
	await summons_attack()
	
	enemy_attack()

# Атака саммонов
func summons_attack():
	if summons.is_empty() or not enemy_instance:
		return
	
	is_animation_locked = true
	
	for summon in summons:
		if not is_instance_valid(summon) or not enemy_instance or not is_instance_valid(enemy_instance):
			continue
		
		# Анимация атаки саммона БЕЗ ожидания завершения
		var summon_sprite = summon.get_node_or_null("Sprite2D")
		if summon_sprite:
			var original_pos = summon.position
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(summon, "position", summon.position + Vector2(100, 0), 0.15)
			tween.tween_property(summon, "position", original_pos, 0.15)
			# УБРАНО: await tween.finished
		
		# Наносим урон сразу
		var damage = summon.attack_enemy(enemy_instance)
		if enemy_instance and is_instance_valid(enemy_instance) and enemy_instance.has_method("take_damage"):
			enemy_instance.take_damage(damage)
			# Можно убрать shake_enemy() для еще большей скорости
			# await shake_enemy()
		
		# Если враг умер, прерываем атаки
		if not enemy_instance or not is_instance_valid(enemy_instance):
			break
		
		# Небольшая задержка перед следующим саммоном
		await get_tree().create_timer(0.15).timeout  # Время между атаками саммонов
	
	# Ждем чтобы последняя анимация завершилась
	await get_tree().create_timer(0.3).timeout
	
	is_animation_locked = false

func reset_card_highlight(card: Area2D):
	if is_animation_locked:
		return
	
	if not original_card_scales.has(card):
		return
		
	var sprite = card.get_node("Sprite2D")
	var shape = card.get_node("CollisionShape2D")
	var original_scale = original_card_scales[card]
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.2 / animation_speed)
	tween.tween_property(shape, "position", Vector2.ZERO, 0.2 / animation_speed)
	tween.tween_property(sprite, "scale", original_scale, 0.2 / animation_speed)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2 / animation_speed)

func highlight_enemy():
	if enemy_instance:
		if enemy_highlight_tween and enemy_highlight_tween.is_valid():
			enemy_highlight_tween.kill()
		
		var enemy_sprite = enemy_instance.get_node("Sprite2D")
		enemy_highlight_tween = create_tween()
		enemy_highlight_tween.tween_property(enemy_sprite, "modulate", Color(1, 0.5, 0.5), 0.3)
		enemy_highlight_tween.set_loops()

func reset_enemy_highlight():
	if enemy_instance:
		if enemy_highlight_tween and enemy_highlight_tween.is_valid():
			enemy_highlight_tween.kill()
		
		var enemy_sprite = enemy_instance.get_node("Sprite2D")
		var tween = create_tween()
		tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.3)

func _on_enemy_input(viewport, event, shape_idx):
	if game_state != GameState.PLAYER_TURN or is_animation_locked or is_flipping:
		return
		
	if event is InputEventMouseButton and event.pressed and attack_mode and current_attack_card:
		# НОВОЕ: Скрываем tooltip при клике
		hide_enemy_tooltip()
		var card_cost = current_attack_card.get_meta("cost", 1)
		
		if energy < card_cost:
			var sprite = current_attack_card.get_node("Sprite2D")
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
			tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
			return
		
		var used_card = current_attack_card
		
		reset_card_highlight(used_card)
		attack_mode = false
		current_attack_card = null
		reset_enemy_highlight()
		
		var effect = get_current_card_effect(used_card)
		
		match effect["type"]:
			CardEffect.ATTACK:
				await apply_attack_effect(effect, card_cost, used_card)
			CardEffect.DEFENSE:
				await apply_defense_effect(effect, card_cost, used_card)
			CardEffect.HEAL:
				await apply_heal_effect(effect, card_cost, used_card)
			CardEffect.FLIP:
				await apply_flip_effect(effect, card_cost, used_card)
			CardEffect.FIREBALL:
				await apply_fireball_effect(effect, card_cost, used_card)
			CardEffect.VULNERABLE:  # НОВОЕ
				await apply_vulnerable_effect(effect, card_cost, used_card)
			_:
				discard_card(used_card)

func shake_enemy() -> void:
	# НОВОЕ: Проверяем что враг существует
	if not enemy_instance or not is_instance_valid(enemy_instance):
		print("Cannot shake - enemy doesn't exist")
		return
	
	is_animation_locked = true
	var enemy_sprite = enemy_instance.get_node_or_null("Sprite2D")
	
	if not enemy_sprite:
		is_animation_locked = false
		return
	
	var current_modulate = enemy_sprite.modulate
	var current_scale = enemy_sprite.scale
	
	enemy_sprite.modulate = Color(1.5, 0.5, 0.5)
	
	var shake_count = 8
	var shake_intensity = 15.0
	var shake_duration = 0.3
	
	for i in range(shake_count):
		# НОВОЕ: Проверяем на каждой итерации
		if not enemy_instance or not is_instance_valid(enemy_instance):
			is_animation_locked = false
			return
		
		var progress = float(i) / shake_count
		var intensity = shake_intensity * (1.0 - progress)
		
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(enemy_instance, "position", original_enemy_position + offset, shake_duration / shake_count / 2)
		tween.tween_property(enemy_instance, "position", original_enemy_position, shake_duration / shake_count / 2)
		
		await tween.finished
	
	# НОВОЕ: Финальная проверка
	if not enemy_instance or not is_instance_valid(enemy_instance):
		is_animation_locked = false
		return
	
	enemy_instance.position = original_enemy_position
	
	var pulse_tween = create_tween()
	pulse_tween.tween_property(enemy_sprite, "scale", original_enemy_scale * 1.1, 0.1)
	pulse_tween.tween_property(enemy_sprite, "scale", original_enemy_scale, 0.1)
	pulse_tween.parallel().tween_property(enemy_sprite, "modulate", current_modulate, 0.2)
	
	await pulse_tween.finished
	is_animation_locked = false

func _on_enemy_mouse_entered():
	if enemy_instance and is_instance_valid(enemy_instance):
		var enemy_sprite = enemy_instance.get_node("Sprite2D")
		var tween = create_tween()
		tween.tween_property(enemy_sprite, "scale", original_enemy_scale * 1.1, 0.15)
		
		# НОВОЕ: Показываем tooltip
		show_enemy_tooltip()

func _on_enemy_mouse_exited():
	if enemy_instance and is_instance_valid(enemy_instance):
		var enemy_sprite = enemy_instance.get_node("Sprite2D")
		var tween = create_tween()
		tween.tween_property(enemy_sprite, "scale", original_enemy_scale, 0.15)
	
	# НОВОЕ: Скрываем tooltip
	hide_enemy_tooltip()

func remove_card(card: Area2D):
	discard_card(card)
	layout_subcards()

func apply_attack_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	# ИЗМЕНЕНО: Добавляем бонус силы к урону
	var base_damage = effect["value"]
	var damage = base_damage + player_strength
	if player_strength > 0:
		print("Attack: %d base + %d strength = %d total" % [base_damage, player_strength, damage])
	await shake_enemy()
	
	if enemy_instance and enemy_instance.has_method("take_damage"):
		enemy_instance.take_damage(damage)
	
	# Добор карт если есть
	var draw_amount = card.get_meta("front_draw_cards" if not card.get_meta("flipped", false) else "back_draw_cards", 0)
	if draw_amount > 0:
		draw_cards(draw_amount)
	
	discard_card(card)
	
	# Раскладываем карты
	if draw_amount > 0:
		await get_tree().process_frame
		layout_subcards()
	
	# НОВОЕ: Увеличиваем прогресс и проверяем трансформацию ПОСЛЕ добора карт
	add_transformation_progress()
	await check_and_transform()


func apply_defense_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	player_block += effect["value"]
	
	var tween = create_tween()
	tween.tween_property(main_card_sprite, "modulate", Color(0.2, 0.5, 1), 0.2)
	tween.tween_property(main_card_sprite, "modulate", Color(1, 1, 1), 0.2)
	
	update_ui()
	
	# Добор карт если есть
	var draw_amount = card.get_meta("front_draw_cards" if not card.get_meta("flipped", false) else "back_draw_cards", 0)
	if draw_amount > 0:
		draw_cards(draw_amount)
	
	discard_card(card)
	
	# Раскладываем карты
	if draw_amount > 0:
		await get_tree().process_frame
		layout_subcards()
	
	# НОВОЕ: Увеличиваем прогресс и проверяем трансформацию ПОСЛЕ добора карт
	add_transformation_progress()
	await check_and_transform()


func apply_heal_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	player_hp = min(player_hp + effect["value"], player_max_hp)
	
	var tween = create_tween()
	tween.tween_property(main_card_sprite, "modulate", Color(0.2, 1, 0.2), 0.2)
	tween.tween_property(main_card_sprite, "modulate", Color(1, 1, 1), 0.2)
	
	update_ui()
	discard_card(card)
	
	# НОВОЕ: Увеличиваем прогресс и проверяем трансформацию
	add_transformation_progress()
	await check_and_transform()

func apply_fireball_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	var damage = effect["value"]
	var burn = card.get_meta("burn_value", 10)
	
	await shake_enemy()
	
	if enemy_instance and enemy_instance.has_method("take_damage"):
		enemy_instance.take_damage(damage)
	
	# Накладываем Burn
	if enemy_instance:
		var current_burn = enemy_instance.get_meta("burn", 0)
		enemy_instance.set_meta("burn", current_burn + burn)
		update_enemy_burn_display()
		
		if enemy_burn_sprite:
			var original_scale = enemy_burn_sprite.get_meta("original_scale", Vector2(3, 3))
			var sprite_tween = create_tween()
			sprite_tween.tween_property(enemy_burn_sprite, "scale", original_scale * 1.2, 0.15)
			sprite_tween.tween_property(enemy_burn_sprite, "scale", original_scale, 0.15)
		
		if enemy_burn_label:
			var label_tween = create_tween()
			label_tween.tween_property(enemy_burn_label, "scale", Vector2(1.3, 1.3), 0.15)
			label_tween.tween_property(enemy_burn_label, "scale", Vector2(1.0, 1.0), 0.15)
	
	discard_card(card)
	
	# НОВОЕ: Увеличиваем прогресс и проверяем трансформацию
	add_transformation_progress()
	await check_and_transform()


func apply_flip_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	if card in sub_cards:
		sub_cards.erase(card)
	
	await flip_all_cards_in_deck()
	
	# НОВОЕ: Синхронизируем состояние трансформации с флипом
	player_transformed = flipped
	
	# НОВОЕ: Сбрасываем прогресс после ручного флипа
	transformation_progress = 0
	
	if not card in discard_pile:
		discard_pile.append(card)
	
	var sprite = card.get_node("Sprite2D")
	var shape = card.get_node("CollisionShape2D")
	if sprite:
		sprite.position = Vector2.ZERO
	if shape:
		shape.position = Vector2.ZERO
	
	card.visible = false
	update_pile_counts()
	layout_subcards()
	
	# НОВОЕ: Обновляем UI трансформации
	var new_threshold = transformation_threshold_return if flipped else transformation_threshold
	transformation_bar.max_value = new_threshold
	update_transformation_ui()
	

func flip_all_cards_in_deck() -> void:
	if is_flipping:
		return
		
	is_flipping = true
	flipped = !flipped
	await flip_card(main_card_sprite, flipped)
	main_card_sprite.set_meta("flipped", flipped)
	print("Flipping sub_cards, count: ", sub_cards.size())
	
	for i in range(sub_cards.size()):
		print("Flipping card index: ", i)
		
		if i >= sub_cards.size():
			print("ERROR: Index out of bounds!")
			break
		
		var card = sub_cards[i]
		if not is_instance_valid(card):
			print("WARNING: Invalid card at index ", i)
			continue
		
		await get_tree().create_timer(0.05 / animation_speed).timeout
		await flip_card(card, flipped)
		update_card_value_label(card)
	
	print("Flipping draw_pile, count: ", draw_pile.size())
	for card in draw_pile:
		if is_instance_valid(card):
			flip_card_instantly(card, flipped)
			update_card_value_label(card)
	
	print("Flipping discard_pile, count: ", discard_pile.size())
	for card in discard_pile:
		if is_instance_valid(card):
			flip_card_instantly(card, flipped)
			update_card_value_label(card)
	is_flipping = false
	print("Flip complete!")

func flip_card_instantly(card_node: Node, to_back: bool) -> void:
	var sprite: Sprite2D
	
	if card_node is Sprite2D:
		sprite = card_node
	elif card_node is Area2D:
		sprite = card_node.get_node("Sprite2D") as Sprite2D
	
	if sprite:
		var tex = sprite.get_meta("back_texture") if to_back else sprite.get_meta("front_texture")
		if tex:
			sprite.texture = tex
		
		if card_node is Sprite2D:
			sprite.set_meta("flipped", to_back)
		elif card_node is Area2D:
			card_node.set_meta("flipped", to_back)

func start_player_turn():
	game_state = GameState.PLAYER_TURN
	energy = max_energy
	player_block = 0
	update_ui()
	turn_label.text = "Your Turn"
	end_turn_button.disabled = false
	
	if current_attack_card:
		reset_card_highlight(current_attack_card)
		current_attack_card = null
		attack_mode = false
		reset_enemy_highlight()
	
	reset_hand()
	draw_cards(cards_per_turn)
	
	# ИСПРАВЛЕНО: Вызываем layout_subcards() ПОСЛЕ draw_cards()
	await get_tree().process_frame  # Ждем один кадр чтобы карты успели добавиться
	layout_subcards()

func reset_hand():
	var cards_to_discard = sub_cards.duplicate()
	for card in cards_to_discard:
		if card in sub_cards:
			sub_cards.erase(card)
		
		if not card in discard_pile:
			discard_pile.append(card)
		
		card.visible = false
	
	sub_cards.clear()
	update_pile_counts()

func _on_end_turn_button_pressed():
	if game_state == GameState.PLAYER_TURN and not is_animation_locked:
		end_player_turn()


func enemy_attack():
	print(">>> enemy_attack() START")
	is_animation_locked = true
	
	# Проверяем что враг существует перед началом
	if not enemy_instance or not is_instance_valid(enemy_instance):
		print("No valid enemy at start of turn")
		is_animation_locked = false
		await get_tree().create_timer(0.5).timeout
		start_player_turn()
		return
	
	# Сбрасываем блок врага в начале хода - ИСПРАВЛЕНО
	enemy_instance.block = 0
	enemy_instance.reduce_vulnerable()  # НОВОЕ
	enemy_instance.update_ui()
	
	# Применяем Burn в начале хода врага
	print("Enemy instance exists")
	var burn = enemy_instance.get_meta("burn", 0)
	print("Burn value: ", burn)
	
	if burn > 0:
		print("Applying burn damage...")
		print("Enemy HP BEFORE take_damage: ", enemy_instance.current_hp)
		
		if enemy_instance.has_method("take_damage"):
			enemy_instance.take_damage(burn)
		
		if not enemy_instance or not is_instance_valid(enemy_instance):
			print("Enemy died from burn")
		else:
			print("Enemy HP AFTER take_damage: ", enemy_instance.current_hp)
		
		# Анимация burn
		if enemy_instance and is_instance_valid(enemy_instance):
			var enemy_sprite = enemy_instance.get_node_or_null("Sprite2D")
			if enemy_sprite:
				var burn_tween = create_tween()
				burn_tween.tween_property(enemy_sprite, "modulate", Color(1, 0.4, 0), 0.3)
				burn_tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.3)
				await burn_tween.finished
		else:
			await get_tree().create_timer(0.6).timeout
		
		# Обновляем Burn
		if enemy_instance and is_instance_valid(enemy_instance):
			var new_burn = ceili(burn / 2.0)
			print("Updating burn: ", burn, " -> ", new_burn)
			enemy_instance.set_meta("burn", new_burn)
			update_enemy_burn_display()
	
	# Если враг умер, ждем спавна нового
	if not enemy_instance or not is_instance_valid(enemy_instance):
		print("Enemy is dead, waiting for respawn...")
		is_animation_locked = false
		await get_tree().create_timer(1.0).timeout
		start_player_turn()
		print(">>> enemy_attack() END (enemy died)")
		return
	
	# ИСПРАВЛЕНО: Выполняем действие врага
	var action = enemy_instance.next_action if enemy_instance.next_action != null else EnemyAction.ATTACK_PLAYER
	print("Enemy action: ", action)
	
	match action:
		EnemyAction.ATTACK_PLAYER:
			await enemy_action_attack_player()
		
		EnemyAction.ATTACK_ALL:
			await enemy_action_attack_all()
		
		EnemyAction.DEFEND:
			await enemy_action_defend()
	
	# Выбираем следующее действие для следующего хода
	if enemy_instance and is_instance_valid(enemy_instance) and enemy_instance.has_method("choose_next_action"):
		enemy_instance.choose_next_action()
		print("Next enemy action will be: ", enemy_instance.next_action)
	
	# Проверяем смерть игрока
	if player_hp <= 0:
		print("Player died!")
		game_over()
	else:
		await get_tree().create_timer(1.0).timeout
		start_player_turn()
	
	is_animation_locked = false
	print(">>> enemy_attack() END (normal)")

func update_ui():
	player_hp_label.text = "Mage: %d/%d HP" % [player_hp, player_max_hp]
	energy_label.text = "Energy: %d/%d" % [energy, max_energy]
	block_label.text = "Block: %d" % player_block
	update_gold_display()


func spawn_new_enemy():
	if enemy_instance:
		enemy_instance.queue_free()
	
	enemy_burn_label = null
	enemy_burn_sprite = null
	
	spawn_enemy()


# НОВОЕ: Получение награды за победу над врагом
func reward_player(gold_amount: int):
	player_gold += gold_amount
	update_gold_display()
	
	# Анимация получения золота
	if gold_label:
		var tween = create_tween()
		tween.tween_property(gold_label, "scale", Vector2(1.3, 1.3), 0.3)
		tween.tween_property(gold_label, "scale", Vector2(1.0, 1.0), 0.3)

func game_over():
	game_state = GameState.GAME_OVER
	game_over_screen.visible = true
	end_turn_button.disabled = true
	turn_label.text = "Game Over"

func update_card_value_label(card: Area2D):
	var value_label = card.get_node_or_null("ValueLabel") as RichTextLabel
	if not value_label:
		return
		
	var is_flipped = card.get_meta("flipped", false)
	var effect_type
	var value
	
	if is_flipped:
		effect_type = card.get_meta("back_effect_type", CardEffect.DEFENSE)
		value = card.get_meta("back_effect_value", 0)
	else:
		effect_type = card.get_meta("front_effect_type", CardEffect.ATTACK)
		value = card.get_meta("front_effect_value", 0)
	
	var color_tag
	match effect_type:
		CardEffect.ATTACK:
			color_tag = "[color=#FF3333]"
		CardEffect.DEFENSE:
			color_tag = "[color=#3388FF]"
		CardEffect.HEAL:
			color_tag = "[color=#33FF33]"
		CardEffect.FLIP:
			color_tag = "[color=#DDDD22]"
		CardEffect.FIREBALL:
			color_tag = "[color=#FF6600]"
		_:
			color_tag = "[color=#FFFFFF]"
	
	if effect_type == CardEffect.FLIP:
		value_label.text = ""
	else:
		value_label.text = "[font_size=10][center]%s%d[/color][/center]" % [color_tag, value]

func get_current_card_effect(card: Area2D) -> Dictionary:
	var is_flipped = card.get_meta("flipped", false)
	
	if is_flipped:
		return {
			"type": card.get_meta("back_effect_type", CardEffect.DEFENSE),
			"value": card.get_meta("back_effect_value", 0)
		}
	else:
		return {
			"type": card.get_meta("front_effect_type", CardEffect.ATTACK),
			"value": card.get_meta("front_effect_value", 0)
		}
# Создание tooltip для карт
func create_card_tooltip():
	card_tooltip = PanelContainer.new()
	card_tooltip.name = "CardTooltip"
	card_tooltip.visible = false
	card_tooltip.z_index = 100
	card_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Стилизация панели
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style_box.border_color = Color(0.8, 0.8, 0.9, 1)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	style_box.content_margin_left = 10
	style_box.content_margin_right = 10
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	
	card_tooltip.add_theme_stylebox_override("panel", style_box)
	
	# Текст tooltip
	tooltip_label = RichTextLabel.new()
	tooltip_label.bbcode_enabled = true
	tooltip_label.fit_content = true
	tooltip_label.scroll_active = false
	tooltip_label.custom_minimum_size = Vector2(200, 0)
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	card_tooltip.add_child(tooltip_label)
	$CanvasLayer.add_child(card_tooltip)

# Получение описания карты для tooltip
func get_card_description(card: Area2D) -> String:
	var is_flipped = card.get_meta("flipped", false)
	var effect_type
	var value
	var cost = card.get_meta("cost", 1)
	var draw_amount = 0  # НОВОЕ
	
	if is_flipped:
		effect_type = card.get_meta("back_effect_type", CardEffect.DEFENSE)
		value = card.get_meta("back_effect_value", 0)
		draw_amount = card.get_meta("back_draw_cards", 0)  # НОВОЕ
	else:
		effect_type = card.get_meta("front_effect_type", CardEffect.ATTACK)
		value = card.get_meta("front_effect_value", 0)
		draw_amount = card.get_meta("front_draw_cards", 0)  # НОВОЕ
	
	var description = "[center][b]Cost: [color=#FFD700]%d[/color] Energy[/b][/center]\n\n" % cost
	
	match effect_type:
		CardEffect.ATTACK:
			description += "[color=#FF3333]⚔ Attack[/color]\nDeal [b]%d[/b] damage to the enemy." % value
			# НОВОЕ: Добавляем информацию о доборе
			if draw_amount > 0:
				description += "\n\n[color=#FFAA66]📜 Draw %d card%s.[/color]" % [draw_amount, "s" if draw_amount > 1 else ""]
		
		CardEffect.DEFENSE:
			description += "[color=#3388FF]🛡 Defense[/color]\nGain [b]%d[/b] block.\nBlock absorbs incoming damage." % value
			# НОВОЕ: Добавляем информацию о доборе
			if draw_amount > 0:
				description += "\n\n[color=#FFAA66]📜 Draw %d card%s.[/color]" % [draw_amount, "s" if draw_amount > 1 else ""]
		
		CardEffect.HEAL:
			description += "[color=#33FF33]❤ Heal[/color]\nRestore [b]%d[/b] HP.\nCannot exceed maximum HP." % value
		
		CardEffect.FLIP:
			description += "[color=#DDDD22]🔄 Flip All[/color]\nFlip all cards in your hand and deck.\nReveals the other side of cards."
		
		CardEffect.FIREBALL:
			var burn_value = card.get_meta("burn_value", 10)
			description += "[color=#FF6600]🔥 Fireball[/color]\nDeal [b]%d[/b] damage.\nApply [b]%d Burn[/b] to the enemy.\n\n[color=#888888]Burn deals damage at the start of enemy's turn, then halves.[/color]" % [value, burn_value]
		
		CardEffect.SUMMON:
			var summon_type = card.get_meta("summon_type", "basic")
			var summon_info = ""
			match summon_type:
				"basic":
					summon_info = "Warrior: 30 HP, 10 ATK"
				"tank":
					summon_info = "Guardian: 50 HP, 5 ATK"
				"damage":
					summon_info = "Mage: 20 HP, 15 ATK"
			
			description += "[color=#9933FF]👥 Summon Ally[/color]\nSummon a %s.\nAttacks enemy each turn.\n\n[color=#888888]Max %d summons.[/color]" % [summon_info, max_summons]
		
		CardEffect.STRENGTH:
			description += "[color=#FF6633]⚔ Strength[/color]\nGain [b]+%d[/b] damage to all attacks this combat." % value
		
		CardEffect.VULNERABLE:
			description += "[color=#CC66FF]💔 Vulnerable[/color]\nApply [b]%d[/b] Vulnerable to enemy.\nVulnerable enemies take 50%% more damage per stack.\nDecreases by 1 each turn." % value
			
	return description

# Спавн саммона
func spawn_summon(summon_type: String = "basic"):
	if summons.size() >= max_summons:
		print("Maximum summons reached!")
		return null
	
	var summon = summon_scene.instantiate()
	add_child(summon)
	
	# Позиционируем саммонов слева от игрока
	var summon_x = 200
	var summon_y = 400 + summons.size() * 100
	summon.position = Vector2(summon_x, summon_y)
	
	# Настраиваем параметры в зависимости от типа
	match summon_type:
		"basic":
			summon.summon_name = "Warrior"
			summon.max_hp = 30
			summon.current_hp = 30
			summon.attack_damage = 10
		"tank":
			summon.summon_name = "Guardian"
			summon.max_hp = 50
			summon.current_hp = 50
			summon.attack_damage = 5
		"damage":
			summon.summon_name = "Mage"
			summon.max_hp = 20
			summon.current_hp = 20
			summon.attack_damage = 15
	
	# Устанавливаем текстуру (создайте свою или используйте временную)
	var summon_sprite = summon.get_node("Sprite2D")
	summon_sprite.texture = defense_texture  # Временно
	summon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	summon_sprite.modulate = Color(0.5, 1, 0.5)  # Зеленоватый оттенок
	
	summon.update_ui()
	summons.append(summon)
	
	print("Summoned: ", summon.summon_name)
	return summon

# Создание карты призыва
func create_summon_card(summon_type: String = "basic") -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	# Устанавливаем текстуры
	sprite.set_meta("front_texture", defense_texture)  # Временно
	sprite.texture = defense_texture
	sprite.set_meta("back_texture", heal_texture)
	
	card.set_meta("front_effect_type", CardEffect.SUMMON)
	card.set_meta("front_effect_value", 0)
	card.set_meta("summon_type", summon_type)
	card.set_meta("back_effect_type", CardEffect.HEAL)
	card.set_meta("back_effect_value", 10)
	card.set_meta("cost", 2)
	card.set_meta("flipped", false)
	
	var value_label = RichTextLabel.new()
	value_label.name = "ValueLabel"
	value_label.position = Vector2(10, 70)
	value_label.size = Vector2(80, 40)
	value_label.bbcode_enabled = true
	value_label.scroll_active = false
	value_label.fit_content = true
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.focus_mode = Control.FOCUS_NONE
	
	card.add_child(value_label)
	update_card_value_label(card)
	
	card.connect("mouse_entered", Callable(self, "_on_card_hover_entered").bind(card))
	card.connect("mouse_exited", Callable(self, "_on_card_hover_exited").bind(card))
	card.connect("input_event", Callable(self, "_on_card_input").bind(card))
	
	card.visible = false
	return card

# НОВОЕ: Централизованная обработка смерти врага
func on_enemy_died(reward_gold: int):
	print("Enemy died! Reward: ", reward_gold)
	
	# Даем награду
	reward_player(reward_gold)
	
	# Обнуляем ссылку (враг удалится через queue_free)
	enemy_instance = null
	enemy_burn_label = null
	enemy_burn_sprite = null
	
	# Небольшая задержка перед спавном нового
	await get_tree().create_timer(0.5).timeout
	
	# Спавним нового врага
	await spawn_enemy()
	update_ui()

# НОВОЕ: Враг атакует только игрока
func enemy_action_attack_player():
	if not enemy_instance or not is_instance_valid(enemy_instance):
		return
	
	print("Enemy attacking player...")
	
	# Анимация атаки
	var enemy_sprite = enemy_instance.get_node_or_null("Sprite2D")
	if enemy_sprite:
		var tween = create_tween()
		tween.tween_property(enemy_instance, "position", enemy_instance.position + Vector2(0, -50), 0.2)
		tween.tween_property(enemy_instance, "position", enemy_instance.position, 0.2)
		await tween.finished
	
	if not enemy_instance or not is_instance_valid(enemy_instance):
		return
	
	var base_damage = enemy_instance.attack_damage
	var actual_damage = base_damage
	
	# Блок игрока
	if player_block > 0:
		var blocked = min(player_block, actual_damage)
		actual_damage -= blocked
		player_block -= blocked
	
	if actual_damage > 0:
		player_hp = max(player_hp - actual_damage, 0)
		
		var player_tween = create_tween()
		player_tween.tween_property(main_card_sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
		player_tween.tween_property(main_card_sprite, "modulate", Color(1, 1, 1), 0.1)
	
	print("Enemy dealt %d damage to player" % actual_damage)
	update_ui()


# НОВОЕ: Враг атакует всех (игрока и саммонов)
func enemy_action_attack_all():
	if not enemy_instance or not is_instance_valid(enemy_instance):
		return
	
	print("Enemy attacking ALL targets...")
	
	# Анимация атаки
	var enemy_sprite = enemy_instance.get_node_or_null("Sprite2D")
	if enemy_sprite:
		# Более мощная анимация для AoE атаки
		var tween = create_tween()
		tween.tween_property(enemy_sprite, "scale", original_enemy_scale * 1.3, 0.2)
		tween.tween_property(enemy_sprite, "modulate", Color(1.5, 0.5, 0.5), 0.2)
		tween.parallel().tween_property(enemy_instance, "position", enemy_instance.position + Vector2(0, -30), 0.2)
		tween.tween_property(enemy_sprite, "scale", original_enemy_scale, 0.2)
		tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.2)
		tween.parallel().tween_property(enemy_instance, "position", enemy_instance.position, 0.2)
		await tween.finished
	
	if not enemy_instance or not is_instance_valid(enemy_instance):
		return
	
	var base_damage = enemy_instance.attack_damage
	var aoe_damage = int(base_damage * 0.7)  # AoE атака слабее
	
	# Атакуем игрока
	var player_damage = aoe_damage
	if player_block > 0:
		var blocked = min(player_block, player_damage)
		player_damage -= blocked
		player_block -= blocked
	
	if player_damage > 0:
		player_hp = max(player_hp - player_damage, 0)
		
		var player_tween = create_tween()
		player_tween.tween_property(main_card_sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
		player_tween.tween_property(main_card_sprite, "modulate", Color(1, 1, 1), 0.1)
	
	print("Enemy dealt %d damage to player (AoE)" % player_damage)
	
	# Атакуем всех саммонов
	var summons_to_remove = []
	for summon in summons:
		if not is_instance_valid(summon):
			summons_to_remove.append(summon)
			continue
		
		if summon.has_method("take_damage"):
			summon.take_damage(aoe_damage)
			print("Enemy dealt %d damage to summon" % aoe_damage)
			
			# Анимация урона саммону
			var summon_sprite = summon.get_node_or_null("Sprite2D")
			if summon_sprite:
				var tween = create_tween()
				tween.tween_property(summon_sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
				tween.tween_property(summon_sprite, "modulate", Color(1, 1, 1), 0.1)
	
	# Очищаем мертвых саммонов
	for s in summons_to_remove:
		summons.erase(s)
	
	update_ui()


# НОВОЕ: Враг защищается
func enemy_action_defend():
	if not enemy_instance or not is_instance_valid(enemy_instance):
		return
	
	print("Enemy defending...")
	
	var defense_amount = int(enemy_instance.attack_damage * 1.5)  # Защита = 150% от атаки
	enemy_instance.block = defense_amount
	
	# Анимация защиты
	var enemy_sprite = enemy_instance.get_node_or_null("Sprite2D")
	if enemy_sprite:
		var tween = create_tween()
		tween.tween_property(enemy_sprite, "modulate", Color(0.5, 0.5, 1.5), 0.3)
		tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.3)
		await tween.finished
	
	enemy_instance.update_ui()
	print("Enemy gained %d block" % defense_amount)

# Создание tooltip для врага
func create_enemy_tooltip():
	enemy_tooltip = PanelContainer.new()
	enemy_tooltip.name = "EnemyTooltip"
	enemy_tooltip.visible = false
	enemy_tooltip.z_index = 100
	enemy_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Стилизация панели
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.05, 0.05, 0.95)  # Красноватый фон
	style_box.border_color = Color(1, 0.3, 0.3, 1)  # Красная граница
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	style_box.content_margin_left = 12
	style_box.content_margin_right = 12
	style_box.content_margin_top = 10
	style_box.content_margin_bottom = 10
	
	enemy_tooltip.add_theme_stylebox_override("panel", style_box)
	
	# Текст tooltip
	enemy_tooltip_label = RichTextLabel.new()
	enemy_tooltip_label.bbcode_enabled = true
	enemy_tooltip_label.fit_content = true
	enemy_tooltip_label.scroll_active = false
	enemy_tooltip_label.custom_minimum_size = Vector2(220, 0)
	enemy_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	enemy_tooltip.add_child(enemy_tooltip_label)
	$CanvasLayer.add_child(enemy_tooltip)

# Получение описания следующего действия врага
func get_enemy_action_description() -> String:
	if not enemy_instance or not is_instance_valid(enemy_instance):
		return ""
	
	var enemy_name = enemy_instance.get_meta("enemy_name", "Enemy")
	var hp = enemy_instance.current_hp
	var max_hp = enemy_instance.max_hp
	var damage = enemy_instance.attack_damage
	var block = enemy_instance.block
	var burn = enemy_instance.get_meta("burn", 0)
	
	var description = "[center][b][color=#FF6666]%s[/color][/b][/center]\n" % enemy_name
	description += "[center]HP: %d/%d[/center]\n\n" % [hp, max_hp]
	
	# Показываем текущие эффекты
	if block > 0:
		description += "[color=#6666FF]🛡 Block: %d[/color]\n" % block
	if burn > 0:
		description += "[color=#FF6600]🔥 Burn: %d[/color]\n" % burn
	
	if block > 0 or burn > 0:
		description += "\n"
	
	# Показываем следующее действие
	var action = enemy_instance.next_action if enemy_instance.next_action != null else EnemyAction.ATTACK_PLAYER
	
	description += "[b][color=#FFAA66]Next Action:[/color][/b]\n"
	
	match action:
		EnemyAction.ATTACK_PLAYER:
			description += "[color=#FF3333]⚔ Attack Player[/color]\n"
			description += "Deal [b]%d[/b] damage to you." % damage
		
		EnemyAction.ATTACK_ALL:
			var aoe_damage = int(damage * 0.7)
			description += "[color=#FF6633]💥 Attack All[/color]\n"
			description += "Deal [b]%d[/b] damage to you\nand all your summons." % aoe_damage
		
		EnemyAction.DEFEND:
			var defense_amount = int(damage * 1.5)
			description += "[color=#6666FF]🛡 Defend[/color]\n"
			description += "Gain [b]%d[/b] block." % defense_amount
	
	return description

# Показать tooltip врага
func show_enemy_tooltip():
	if not enemy_tooltip or not enemy_tooltip_label or not enemy_instance:
		return
	
	enemy_tooltip_label.text = get_enemy_action_description()
	
	# НОВОЕ: Принудительно обновляем размер tooltip
	await get_tree().process_frame
	enemy_tooltip_label.reset_size()
	enemy_tooltip.reset_size()
	
	enemy_tooltip.visible = true
	
	# Позиционируем tooltip
	var enemy_pos = enemy_instance.global_position
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = enemy_tooltip.size
	
	# ИСПРАВЛЕНО: Умная позиция tooltip
	var tooltip_pos = Vector2()
	
	# Пробуем слева от врага
	tooltip_pos.x = enemy_pos.x - tooltip_size.x - 20
	tooltip_pos.y = enemy_pos.y - tooltip_size.y / 2
	
	# Если не влезает слева, ставим справа
	if tooltip_pos.x < 20:
		tooltip_pos.x = enemy_pos.x + 100
	
	# Если не влезает справа, центрируем
	if tooltip_pos.x + tooltip_size.x > screen_size.x - 20:
		tooltip_pos.x = (screen_size.x - tooltip_size.x) / 2
	
	# Проверяем вертикальные границы
	if tooltip_pos.y < 20:
		tooltip_pos.y = 20
	elif tooltip_pos.y + tooltip_size.y > screen_size.y - 20:
		tooltip_pos.y = screen_size.y - tooltip_size.y - 20
	
	enemy_tooltip.global_position = tooltip_pos
# Скрыть tooltip врага
func hide_enemy_tooltip():
	if enemy_tooltip:
		enemy_tooltip.visible = false

# Создание карты "Атака + Добор"
func create_attack_draw_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Устанавливаем текстуры
	sprite.set_meta("front_texture", attackfunny_texture)
	sprite.texture = attackfunny_texture
	sprite.set_meta("back_texture", attack_texture)
	# НОВОЕ: Автоматически подгоняем размер текстуры
	fit_texture_to_card(sprite, 50.0)
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	# Эффект атаки + добор карт
	card.set_meta("front_effect_type", CardEffect.ATTACK)
	card.set_meta("front_effect_value", 15)  # 15 урона
	card.set_meta("front_draw_cards", 2)  # НОВОЕ: Количество карт для добора
	
	card.set_meta("back_effect_type", CardEffect.ATTACK)
	card.set_meta("back_effect_value", 20)
	card.set_meta("back_draw_cards", 1)  # На обратной стороне меньше добора
	
	card.set_meta("cost", 2)  # Дороже обычной атаки
	card.set_meta("flipped", false)
	
	var value_label = RichTextLabel.new()
	value_label.name = "ValueLabel"
	value_label.position = Vector2(10, 70)
	value_label.size = Vector2(80, 40)
	value_label.bbcode_enabled = true
	value_label.scroll_active = false
	value_label.fit_content = true
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.focus_mode = Control.FOCUS_NONE
	
	card.add_child(value_label)
	update_card_value_label(card)
	
	card.connect("mouse_entered", Callable(self, "_on_card_hover_entered").bind(card))
	card.connect("mouse_exited", Callable(self, "_on_card_hover_exited").bind(card))
	card.connect("input_event", Callable(self, "_on_card_input").bind(card))
	
	card.visible = false
	return card

# Создание карты "Защита + Добор"
func create_defense_draw_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	# Устанавливаем текстуры
	sprite.set_meta("front_texture", defense_texture)
	sprite.texture = defense_texture
	sprite.set_meta("back_texture", defense_texture)
	
	# Эффект защиты + добор карт
	card.set_meta("front_effect_type", CardEffect.DEFENSE)
	card.set_meta("front_effect_value", 12)  # 12 блока
	card.set_meta("front_draw_cards", 2)  # НОВОЕ: Добор 2 карт
	
	card.set_meta("back_effect_type", CardEffect.DEFENSE)
	card.set_meta("back_effect_value", 15)
	card.set_meta("back_draw_cards", 1)
	
	card.set_meta("cost", 2)
	card.set_meta("flipped", false)
	
	var value_label = RichTextLabel.new()
	value_label.name = "ValueLabel"
	value_label.position = Vector2(10, 70)
	value_label.size = Vector2(80, 40)
	value_label.bbcode_enabled = true
	value_label.scroll_active = false
	value_label.fit_content = true
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.focus_mode = Control.FOCUS_NONE
	
	card.add_child(value_label)
	update_card_value_label(card)
	
	card.connect("mouse_entered", Callable(self, "_on_card_hover_entered").bind(card))
	card.connect("mouse_exited", Callable(self, "_on_card_hover_exited").bind(card))
	card.connect("input_event", Callable(self, "_on_card_input").bind(card))
	
	card.visible = false
	return card

# Функция для автоматического масштабирования текстуры под размер карты
func fit_texture_to_card(sprite: Sprite2D, target_width: float = 50.0):
	if not sprite or not sprite.texture:
		print("ERROR: No sprite or texture!")
		return
	
	var texture_width = sprite.texture.get_size().x
	print("Original texture width: ", texture_width)
	
	var scale_factor = target_width / texture_width
	print("Scale factor: ", scale_factor)
	
	sprite.scale = Vector2(scale_factor, scale_factor)
	print("New sprite scale: ", sprite.scale)

# Создание шкалы трансформации
func create_transformation_bar():
	# Контейнер для шкалы
	var container = VBoxContainer.new()
	container.position = Vector2(650, 700)
	container.custom_minimum_size = Vector2(200, 60)
	
	# Заголовок
	var title = Label.new()
	title.text = "Transformation"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title)
	
	# Прогресс бар
	transformation_bar = ProgressBar.new()
	transformation_bar.custom_minimum_size = Vector2(200, 30)
	transformation_bar.max_value = transformation_threshold
	transformation_bar.value = 0
	transformation_bar.show_percentage = false
	
	# Стилизация прогресс бара
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	style_bg.border_color = Color(0.5, 0.5, 0.6, 1)
	style_bg.border_width_left = 2
	style_bg.border_width_right = 2
	style_bg.border_width_top = 2
	style_bg.border_width_bottom = 2
	style_bg.corner_radius_top_left = 5
	style_bg.corner_radius_top_right = 5
	style_bg.corner_radius_bottom_left = 5
	style_bg.corner_radius_bottom_right = 5
	
	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(1, 0.6, 0.2, 1)  # Оранжевый для формы 1
	style_fg.corner_radius_top_left = 5
	style_fg.corner_radius_top_right = 5
	style_fg.corner_radius_bottom_left = 5
	style_fg.corner_radius_bottom_right = 5
	
	transformation_bar.add_theme_stylebox_override("background", style_bg)
	transformation_bar.add_theme_stylebox_override("fill", style_fg)
	
	container.add_child(transformation_bar)
	
	# Текст на шкале
	transformation_label = Label.new()
	transformation_label.text = "0/5"
	transformation_label.add_theme_font_size_override("font_size", 14)
	transformation_label.add_theme_color_override("font_color", Color(1, 1, 1))
	transformation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transformation_label.position = Vector2(0, -25)
	transformation_bar.add_child(transformation_label)
	
	$CanvasLayer.add_child(container)

# Увеличение прогресса трансформации
func add_transformation_progress():
	transformation_progress += 1
	update_transformation_ui()
	
	# Возвращаем true если достигнут порог
	var current_threshold = transformation_threshold if not flipped else transformation_threshold_return
	return transformation_progress >= current_threshold


# Проверка и выполнение трансформации
func check_and_transform():
	var current_threshold = transformation_threshold if not flipped else transformation_threshold_return
	
	if transformation_progress >= current_threshold:
		transformation_progress = 0
		await toggle_player_transformation()


# Переключение формы игрока
func toggle_player_transformation():
	# ИЗМЕНЕНО: player_transformed теперь следует за flipped
	# (не переключаем вручную, флип сделает это)
	
	print("Transformation! Flipping all cards...")
	
	# Проверяем что не заблокировано
	if is_flipping or is_animation_locked:
		print("Cannot transform - animation in progress")
		transformation_progress = 0
		update_transformation_ui()
		return
	
	# Блокируем действия на время трансформации
	is_animation_locked = true
	
	# Анимация пульсации
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(main_card_sprite, "scale", original_main_card_scale * 1.3, 0.2)
	tween.parallel().tween_property(main_card_sprite, "modulate", Color(1, 0.8, 0.2), 0.2)
	tween.tween_property(main_card_sprite, "scale", original_main_card_scale, 0.2)
	tween.parallel().tween_property(main_card_sprite, "modulate", Color(1, 1, 1), 0.2)
	
	await tween.finished
	
	# Флипаем все карты (это изменит flipped)
	await flip_all_cards_in_deck()
	
	# НОВОЕ: Теперь player_transformed синхронизирован с flipped
	player_transformed = flipped
	
	# Разблокируем действия
	is_animation_locked = false
	
	# Обновляем порог
	var new_threshold = transformation_threshold_return if flipped else transformation_threshold
	transformation_bar.max_value = new_threshold
	
	update_transformation_ui()

# Обновление UI трансформации
func update_transformation_ui():
	if not transformation_bar or not transformation_label:
		return
	
	# ИЗМЕНЕНО: Используем flipped вместо player_transformed
	var current_threshold = transformation_threshold if not flipped else transformation_threshold_return
	
	transformation_bar.value = transformation_progress
	transformation_bar.max_value = current_threshold
	transformation_label.text = "%d/%d" % [transformation_progress, current_threshold]
	
	# Меняем цвет шкалы в зависимости от состояния флипа
	var style_fg = StyleBoxFlat.new()
	if flipped:
		style_fg.bg_color = Color(0.5, 0.3, 1, 1)  # Фиолетовый для flipped
	else:
		style_fg.bg_color = Color(1, 0.6, 0.2, 1)  # Оранжевый для normal
	
	style_fg.corner_radius_top_left = 5
	style_fg.corner_radius_top_right = 5
	style_fg.corner_radius_bottom_left = 5
	style_fg.corner_radius_bottom_right = 5
	
	transformation_bar.add_theme_stylebox_override("fill", style_fg)

# Создание карты "Сила"
func create_strength_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Используем текстуру атаки или создайте свою
	sprite.set_meta("front_texture", attack_texture)
	sprite.texture = attack_texture
	sprite.set_meta("back_texture", defense_texture)
	
	fit_texture_to_card(sprite, 50.0)
	
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	# Эффект силы
	card.set_meta("front_effect_type", CardEffect.STRENGTH)
	card.set_meta("front_effect_value", 3)  # +3 к урону
	
	card.set_meta("back_effect_type", CardEffect.DEFENSE)
	card.set_meta("back_effect_value", 10)
	
	card.set_meta("cost", 1)
	card.set_meta("flipped", false)
	
	var value_label = RichTextLabel.new()
	value_label.name = "ValueLabel"
	value_label.position = Vector2(10, 70)
	value_label.size = Vector2(80, 40)
	value_label.bbcode_enabled = true
	value_label.scroll_active = false
	value_label.fit_content = true
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.focus_mode = Control.FOCUS_NONE
	
	card.add_child(value_label)
	update_card_value_label(card)
	
	card.connect("mouse_entered", Callable(self, "_on_card_hover_entered").bind(card))
	card.connect("mouse_exited", Callable(self, "_on_card_hover_exited").bind(card))
	card.connect("input_event", Callable(self, "_on_card_input").bind(card))
	
	card.visible = false
	return card

# Создание карты "Уязвимость"
func create_vulnerable_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Используем текстуру атаки или создайте свою
	sprite.set_meta("front_texture", attack_texture)
	sprite.texture = attack_texture
	sprite.set_meta("back_texture", heal_texture)
	
	fit_texture_to_card(sprite, 50.0)
	
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	# Эффект уязвимости
	card.set_meta("front_effect_type", CardEffect.VULNERABLE)
	card.set_meta("front_effect_value", 2)  # 2 стака уязвимости
	
	card.set_meta("back_effect_type", CardEffect.HEAL)
	card.set_meta("back_effect_value", 15)
	
	card.set_meta("cost", 1)
	card.set_meta("flipped", false)
	
	var value_label = RichTextLabel.new()
	value_label.name = "ValueLabel"
	value_label.position = Vector2(10, 70)
	value_label.size = Vector2(80, 40)
	value_label.bbcode_enabled = true
	value_label.scroll_active = false
	value_label.fit_content = true
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.focus_mode = Control.FOCUS_NONE
	
	card.add_child(value_label)
	update_card_value_label(card)
	
	card.connect("mouse_entered", Callable(self, "_on_card_hover_entered").bind(card))
	card.connect("mouse_exited", Callable(self, "_on_card_hover_exited").bind(card))
	card.connect("input_event", Callable(self, "_on_card_input").bind(card))
	
	card.visible = false
	return card

# Применение эффекта силы
func apply_strength_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	var strength_gain = effect["value"]
	player_strength += strength_gain
	
	# Анимация получения силы
	var tween = create_tween()
	tween.tween_property(main_card_sprite, "modulate", Color(1.5, 0.5, 0.5), 0.2)
	tween.tween_property(main_card_sprite, "modulate", Color(1, 1, 1), 0.2)
	
	print("Player gained %d strength! Total: %d" % [strength_gain, player_strength])
	update_ui()
	discard_card(card)
	
	add_transformation_progress()
	await check_and_transform()


# Применение эффекта уязвимости
func apply_vulnerable_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	var vulnerable_stacks = effect["value"]
	
	if enemy_instance and is_instance_valid(enemy_instance):
		enemy_instance.vulnerable += vulnerable_stacks
		enemy_instance.update_ui()
		
		# Анимация наложения уязвимости
		var enemy_sprite = enemy_instance.get_node_or_null("Sprite2D")
		if enemy_sprite:
			var tween = create_tween()
			tween.tween_property(enemy_sprite, "modulate", Color(1.5, 0.5, 1.5), 0.2)
			tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.2)
		
		print("Applied %d vulnerable to enemy! Total: %d" % [vulnerable_stacks, enemy_instance.vulnerable])
	
	discard_card(card)
	
	add_transformation_progress()
	await check_and_transform()



# Обновление отображения золота
func update_gold_display():
	if gold_label:
		gold_label.text = "Gold: %d" % player_gold
