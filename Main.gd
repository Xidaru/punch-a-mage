extends Node2D 

# Состояния игры
enum GameState { PLAYER_TURN, ENEMY_TURN, GAME_OVER }

# Эффекты карт
enum CardEffect { 
	ATTACK, 
	DEFENSE, 
	HEAL, 
	FLIP, 
	FIREBALL, 
	SUMMON, 
	DRAW_CARDS, 
	STRENGTH, 
	VULNERABLE,
	POISON,    
	REGEN,    
	WEAK,
	CHAIN_LIGHTNING  
}

enum EnemyAction { ATTACK_PLAYER, ATTACK_ALL, DEFEND, SUMMON_ALLY}

# Параметры игрока
var player_hp := 100
var player_max_hp := 100
var energy := 3
var max_energy := 3
var player_gold := 0
var game_state = GameState.PLAYER_TURN


#Котроль Дрожания
var layout_timer: Timer = null
var layout_pending := false

# Карты и враги
var is_flipping := false
var is_animation_locked := false
var highlighted_card: Area2D = null
var hovered_card: Area2D = null
var selected_card: Area2D = null
var attack_mode := false
var current_attack_card: Area2D = null
@onready var card_manager = preload("res://CardManager.gd").new()
@onready var enemy_manager = preload("res://EnemyManager.gd").new()
@onready var Main_card_area := $MainCardArea as Area2D
@onready var flip_button := $CanvasLayer/FlipButton
@onready var end_turn_button := $CanvasLayer/EndTurnButton
@onready var SubCardScene := preload("res://SubCard.tscn")
@onready var enemy_scene := preload("res://Enemy.tscn")
var main_card_sprite: Sprite2D
var enemies: Array = []
var max_enemies := 3
var selected_enemy: Node2D = null
var enemy_effects_map: Dictionary = {}
var card_area_margin := 100
var card_max_spacing := 150
var card_width := 100
var sub_cards := []
var selected := false
var flipped := false
var animation_speed := 1.0
var enemy_highlight_tween: Tween
var original_main_card_scale: Vector2
const StatusEffectSystem = preload("res://StatusEffectSystem.gd")
var player_effects
# Параметры веера
var fan_spread_angle := 30.0  # УВЕЛИЧЕНО: Максимальный угол разворота веера (градусы)
var fan_curve_height := 60.0  # УВЕЛИЧЕНО: Высота дуги веера (пиксели)
var fan_base_rotation := 0.0  # Базовый поворот веера
var selected_card_lift := 20.0  # УВЕЛИЧЕНО: Насколько поднимается выбранная карта
var base_z_index := 0  # Базовый z-index для карт
var fan_horizontal_spread := 2.0  # НОВОЕ: Множитель горизонтального расстояния между картами

# Улучшенная система карт
var card_push_distance := 100.0  # УВЕЛИЧЕНО
var card_stack_offset := 5.0  # Смещение карт в стаке
var enable_card_stacking := true  # Включить стакирование одинаковых карт
var card_stacks: Dictionary = {}  # Словарь стаков карт
var card_interaction_margin := 20.0  # Увеличенная зона взаимодействия
var max_visible_cards_in_stack := 6  # НОВОЕ: Максимум видимых карт в стаке
var stack_depth_scale := 0.98  # НОВОЕ: Уменьшение размера каждой следующей карты
# Система стопок карт
var draw_pile := []
var discard_pile := []
var cards_per_turn := 6 

# Summons
@onready var summon_scene := preload("res://Summon.tscn")
var summons := []
var max_summons := 3

# Хранилище исходных параметров
var original_enemy_scale: Vector2
var original_enemy_position: Vector2
var original_enemy_modulate: Color
var original_card_scales: Dictionary = {}
var original_card_positions: Dictionary = {}

var transformation_progress := 0
var transformation_threshold := 5
var transformation_threshold_return := 10
var player_transformed := false

#Дебаг тултипов
var tooltip_hide_timer: Timer = null  # Таймер для задержки скрытия tooltip


#Шейдеры 3Д карт
var angle_x_max := 5.0  # Максимальный угол поворота по X
var angle_y_max := 5.0  # Максимальный угол поворота по Y
var card_rotation_speed := 10.0  # Скорость интерполяции
var target_rot_x := 0.0
var target_rot_y := 0.0

var active_card_tweens: Dictionary = {}  # Хранилище активных твинов


# UI элементы
@onready var player_hp_label := $CanvasLayer/PlayerHPLabel
@onready var energy_label := $CanvasLayer/EnergyLabel
@onready var block_label := $CanvasLayer/BlockLabel
@onready var turn_label := $CanvasLayer/TurnLabel
@onready var game_over_screen := $CanvasLayer/GameOverScreen
@onready var draw_pile_label := $CanvasLayer/DrawPileLabel
@onready var discard_pile_label := $CanvasLayer/DiscardPileLabel
@onready var gold_label := $CanvasLayer/GoldLabel
var transformation_bar: ProgressBar
var transformation_label: Label
var card_tooltip: PanelContainer
var tooltip_label: RichTextLabel
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
@onready var burn_texture = preload("res://Burn.png") if ResourceLoader.exists("res://Burn.png") else preload("res://attack_card.png")
@onready var attackfunny_texture = preload("res://Counterattackmeme.png") if ResourceLoader.exists("res://Counterattackmeme.png") else preload("res://attack_card.png")


func _ready():
	add_child(card_manager)
	
	# Создаем таймер для layout
	layout_timer = Timer.new()
	layout_timer.one_shot = true
	layout_timer.wait_time = 0.05  # Небольшая задержка для группировки вызовов
	layout_timer.timeout.connect(_execute_layout)
	add_child(layout_timer)
	
	# Создаем таймер для tooltip
	tooltip_hide_timer = Timer.new()
	tooltip_hide_timer.one_shot = true
	tooltip_hide_timer.wait_time = 0.1
	tooltip_hide_timer.timeout.connect(_on_tooltip_hide_timeout)
	add_child(tooltip_hide_timer)
	
	# Создаем таймер для tooltip
	tooltip_hide_timer = Timer.new()
	tooltip_hide_timer.one_shot = true
	tooltip_hide_timer.wait_time = 0.1
	tooltip_hide_timer.timeout.connect(_on_tooltip_hide_timeout)
	add_child(tooltip_hide_timer)
	
	enable_card_stacking = true  # Включить/выключить стаки
	# НОВОЕ: Создаем отдельный слой для тултипов
	var tooltip_layer = CanvasLayer.new()
	tooltip_layer.name = "TooltipLayer"
	tooltip_layer.layer = 100  # Очень высокий слой
	add_child(tooltip_layer)
	
	create_card_tooltip(tooltip_layer)
	create_enemy_tooltip(tooltip_layer)
	create_transformation_bar()
	
	
	main_card_sprite = Main_card_area.get_node("Sprite2D")
	original_main_card_scale = main_card_sprite.scale
	
	main_card_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	setup_card_3d_shader(main_card_sprite)
	
	main_card_sprite.set_meta("front_texture", front_texture)
	main_card_sprite.set_meta("back_texture", back_texture)
	main_card_sprite.set_meta("flipped", false)
	main_card_sprite.texture = front_texture
	
	Main_card_area.connect("input_event", Callable(self, "_on_main_card_input"))
	Main_card_area.connect("mouse_entered", Callable(self, "_on_main_card_mouse_entered"))
	Main_card_area.connect("mouse_exited", Callable(self, "_on_main_card_mouse_exited"))
	
	flip_button.pressed.connect(_on_flip_button_pressed)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	
	print("=== Initializing player effects ===")
	player_effects = StatusEffectSystem.EffectContainer.new(Main_card_area)
	
	await get_tree().process_frame
	
	player_effects.create_display(Main_card_area, Vector2.ZERO, true, false)
	
	player_effects.set_damage_callback(func(amount: int, damage_type: String):
		var is_heal = (damage_type == "heal" or damage_type == "regen")
		create_damage_number(Main_card_area, amount, is_heal)
	)
	
	player_effects.add_effect(StatusEffectSystem.EffectType.STRENGTH, 3)
	player_effects.add_effect(StatusEffectSystem.EffectType.BLOCK, 10)
	player_effects.update_display()
	
	update_ui()
	game_over_screen.visible = false
	
	initialize_card_system()
	
	print("=== SPAWNING FIRST ENEMY ===")
	await spawn_enemies(2)
	print("=== FIRST ENEMY SPAWNED ===")
	
	await get_tree().process_frame
	update_ui()
	
	start_player_turn()


func initialize_card_system():
	for i in range(15):
		var card = create_random_card()
		draw_pile.append(card)
	
	for i in range(5):
		var fireball_card = create_fireball_card()
		draw_pile.append(fireball_card)
	
	for i in range(10):
		var summon_card = create_summon_card("damage")
		draw_pile.append(summon_card)
	
	for i in range(3):
		var attack_draw = create_attack_draw_card()
		draw_pile.append(attack_draw)
	
	for i in range(3):
		var defense_draw = create_defense_draw_card()
		draw_pile.append(defense_draw)
	
	for i in range(3):
		var strength_card = create_strength_card()
		draw_pile.append(strength_card)
	
	for i in range(3):
		var vulnerable_card = create_vulnerable_card()
		draw_pile.append(vulnerable_card)
	
	var attack_heal_card = create_specific_card()
	if attack_heal_card:
		draw_pile.append(attack_heal_card)
	
	for i in range(3):
		var poison_card = create_poison_card()
		draw_pile.append(poison_card)
	
	for i in range(3):
		var regen_card = create_regen_card()
		draw_pile.append(regen_card)
	
	for i in range(3):
		var weak_card = create_weak_card()
		draw_pile.append(weak_card)
	
	for i in range(5):
		var chain_lightning_card = create_chain_lightning_card()
		draw_pile.append(chain_lightning_card)
	
	shuffle_draw_pile()
	update_pile_counts()


func create_random_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	var shape := card.get_node("CollisionShape2D") 
	if shape and shape.shape is RectangleShape2D:
		shape.set_meta("true_original_size", shape.shape.size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fit_texture_to_card(sprite, 100.0)

	setup_card_3d_shader(sprite)
	
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	var back_effect_type = randi() % 3
	
	sprite.set_meta("front_texture", attack_texture)
	sprite.texture = attack_texture
	
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
	
	var front_effect_value = randi_range(15, 30)
	var back_effect_value = randi_range(10, 20)
	
	if back_effect_type == 2:
		back_effect_value = 0
	
	card.set_meta("front_effect_type", CardEffect.ATTACK)
	card.set_meta("front_effect_value", front_effect_value)
	card.set_meta("back_effect_value", back_effect_value)
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


func create_fireball_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	var shape := card.get_node("CollisionShape2D") 
	if shape and shape.shape is RectangleShape2D:
		shape.set_meta("true_original_size", shape.shape.size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	setup_card_3d_shader(sprite)
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	sprite.set_meta("front_texture", fireball_texture)
	sprite.texture = fireball_texture
	
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
	
	card.set_meta("front_effect_type", CardEffect.FIREBALL)
	card.set_meta("front_effect_value", 10)
	card.set_meta("burn_value", 10)
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


func create_specific_card() -> Area2D:
	var card = card_manager.get_card("CustomcardTest")
	if card:
		setup_card(card)
		card.visible = false
	return card


func setup_card(card: Area2D):
	$CanvasLayer.add_child(card)
	
	var sprite = card.get_node("Sprite2D")
	fit_texture_to_card(sprite, 50.0)
	
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	card.connect("mouse_entered", Callable(self, "_on_card_hover_entered").bind(card))
	card.connect("mouse_exited", Callable(self, "_on_card_hover_exited").bind(card))
	card.connect("input_event", Callable(self, "_on_card_input").bind(card))


func shuffle_draw_pile():
	draw_pile.shuffle()


func draw_cards(count: int):
	for i in range(count):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			shuffle_draw_pile()
		
		var card = draw_pile.pop_front()
		
		var sprite = card.get_node("Sprite2D")
		var shape = card.get_node("CollisionShape2D")
		if sprite:
			sprite.position = Vector2.ZERO
			if original_card_scales.has(card):
				sprite.scale = original_card_scales[card]
			else:
				sprite.scale = Vector2(3, 3)
			sprite.modulate = Color(1, 1, 1, 1)
		if shape:
			shape.position = Vector2.ZERO
		
		sub_cards.append(card)
		card.visible = true
	
	update_pile_counts()
	
	# Организуем стаки
	organize_card_stacks()
	
	# УДАЛЕНО: Цикл обновления счетчиков
	
	await get_tree().process_frame
	layout_subcards()

func discard_card(card: Area2D):
	if card in sub_cards:
		sub_cards.erase(card)
	
	if not card in discard_pile:
		discard_pile.append(card)
	
	var sprite = card.get_node("Sprite2D")
	var shape = card.get_node("CollisionShape2D")
	
	# ✅ СБРОС ПОЗИЦИЙ И РАЗМЕРОВ
	if sprite:
		sprite.position = Vector2.ZERO
		var original_scale = original_card_scales.get(card, Vector2(3, 3))
		sprite.scale = original_scale
		sprite.modulate = Color(1, 1, 1, 1)
	if shape:
		shape.position = Vector2.ZERO
		# ВОССТАНАВЛИВАЕМ ОРИГИНАЛЬНЫЙ РАЗМЕР КОЛЛИЗИИ
		if shape.shape is RectangleShape2D:
			var true_original = shape.get_meta("true_original_size", Vector2(100, 100))
			shape.shape.size = true_original
	
	# СБРОС МЕТАДАННЫХ
	card.set_meta("push_offset", Vector2.ZERO)
	card.set_meta("track_mouse", false)
	card.set_meta("temp_input_disabled", false)
	card.z_index = 0
	card.input_pickable = false
	card.monitorable = false
	card.monitoring = false
	
	card.visible = false
	update_pile_counts()
	
	# Пересчитываем стаки и обновляем интерактивность
	organize_card_stacks()
	update_all_cards_interactivity()
	
	auto_adjust_fan()
	request_layout()


func update_pile_counts():
	if draw_pile_label:
		draw_pile_label.text = "Draw: %d" % draw_pile.size()
	if discard_pile_label:
		discard_pile_label.text = "Discard: %d" % discard_pile.size()


func spawn_enemies(count: int = 1):
	print("=== SPAWNING %d ENEMIES ===" % count)
	
	for i in range(count):
		if enemies.size() >= max_enemies:
			print("Max enemies reached!")
			break
		
		var enemy = enemy_scene.instantiate()
		add_child(enemy)
		
		# ИСПРАВЛЕНО: используем актуальный размер массива врагов
		var enemy_index = enemies.size()
		var enemy_x = 500 + (enemy_index * 150)
		var enemy_y = 150 + (enemy_index % 2) * 100
		enemy.position = Vector2(enemy_x, enemy_y)
		
		enemy.connect("enemy_died", Callable(self, "on_enemy_died"))
		
		var enemy_data = enemy_manager.get_random_enemy()
		enemy.current_hp = enemy_data["hp"]
		enemy.max_hp = enemy_data["hp"]
		enemy.attack_damage = enemy_data.get("attack_damage", 20)
		enemy.block = 0
		
		var actions = enemy_data.get("actions", [])
		enemy.possible_actions = actions
		
		enemy.set_meta("reward_gold", enemy_data["reward_gold"])
		enemy.set_meta("enemy_name", enemy_data.get("name", "Enemy"))
		enemy.set_meta("enemy_index", enemy_index)
		
		var enemy_sprite = enemy.get_node("Sprite2D")
		if ResourceLoader.exists(enemy_data["texture"]):
			enemy_sprite.texture = load(enemy_data["texture"])
		enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		
		setup_card_3d_shader(enemy_sprite)		
		
		enemy.set_meta("original_scale", enemy_sprite.scale)
		enemy.set_meta("original_position", enemy.position)
		enemy.set_meta("original_modulate", enemy_sprite.modulate)
		
		enemy.connect("input_event", Callable(self, "_on_enemy_input").bind(enemy))
		enemy.connect("mouse_entered", Callable(self, "_on_enemy_mouse_entered").bind(enemy))
		enemy.connect("mouse_exited", Callable(self, "_on_enemy_mouse_exited").bind(enemy))
		
		if enemy.has_method("choose_next_action"):
			enemy.choose_next_action()
		
		# ВАЖНО: добавляем врага в массив СРАЗУ после создания
		enemies.append(enemy)
		
		await get_tree().process_frame
		if enemy.has_method("update_ui"):
			enemy.update_ui()
		
		print("=== Creating effects for enemy %d ===" % enemy_index)
		var effects = StatusEffectSystem.EffectContainer.new(enemy)
		
		await get_tree().process_frame
		
		effects.create_display(enemy, Vector2.ZERO, true, true)
		
		effects.set_damage_callback(func(amount: int, damage_type: String):
			if enemy and is_instance_valid(enemy):
				var is_heal = (damage_type == "heal" or damage_type == "regen")
				create_damage_number(enemy, amount, is_heal)
		)
		
		enemy_effects_map[enemy] = effects
		
		print("✓ Enemy %d created at position %s" % [enemy_index, enemy.position])
	
	print("=== %d ENEMIES SPAWNED ===" % enemies.size())
	await get_tree().process_frame
	update_ui()


func layout_subcards():
	if is_animation_locked:
		return
	
	var screen_size = get_viewport().get_visible_rect().size
	var target_y = screen_size.y - 60 if selected else screen_size.y + 200  # расположение веера в зависимости от экрана
	
	if sub_cards.is_empty():
		return
	
	var sorted_stacks = organize_card_stacks()
	var visible_cards = get_visible_cards_from_stacks()
	var total_visible = visible_cards.size()
	
	if total_visible == 0:
		return
	
	var center_x = screen_size.x / 2.0
	var base_y = target_y
	
	if total_visible == 1:
		var card = visible_cards[0]
		var stack_id = get_card_stack_id(card)
		var stack = card_stacks[stack_id]
		layout_single_stack(stack, Vector2(center_x - card_width / 2, target_y), 0.0, base_z_index)
		return
	
	# Автоматический расчет с защитой от выхода за экран
	var adjusted_spread = fan_spread_angle
	var adjusted_horizontal = fan_horizontal_spread
	
	var card_spacing = card_width * 0.7 * adjusted_horizontal
	var estimated_width = (total_visible - 1) * card_spacing
	var max_width = screen_size.x * 0.75  # ИЗМЕНЕНО: 3/4 экрана
	
	if estimated_width > max_width:
		var scale_factor = max_width / estimated_width
		adjusted_horizontal *= scale_factor
		adjusted_spread *= scale_factor
		card_spacing = card_width * 0.7 * adjusted_horizontal
	
	if total_visible > 8:
		adjusted_spread = min(adjusted_spread, 25.0)  
		adjusted_horizontal = min(adjusted_horizontal, 1.2)  
	if total_visible > 12:
		adjusted_spread = min(adjusted_spread, 20.0)  
		adjusted_horizontal = min(adjusted_horizontal, 0.9)  
	if total_visible > 16:
		adjusted_spread = min(adjusted_spread, 18.0)  
		adjusted_horizontal = min(adjusted_horizontal, 0.7)  
	
	var angle_step = adjusted_spread / max(total_visible - 1, 1)
	var start_angle = -adjusted_spread / 2.0
	var fan_radius = 600.0 + (total_visible * 10.0)  
	card_spacing = card_width * 0.7 * adjusted_horizontal
	
	# Находим выбранную/наведенную карту
	var hovered_index = -1
	var selected_index = -1
	
	for i in range(total_visible):
		var card = visible_cards[i]
		if card == hovered_card:
			hovered_index = i
		if card == current_attack_card:
			selected_index = i
	
	var special_index = selected_index if selected_index >= 0 else hovered_index
	
	# Расставляем стаки
	for i in range(total_visible):
		var card = visible_cards[i]
		var stack_id = get_card_stack_id(card)
		var stack = card_stacks[stack_id]
		
		var angle = start_angle + (angle_step * i)
		var angle_rad = deg_to_rad(angle)
		
		var horizontal_offset = (i - (total_visible - 1) / 2.0) * card_spacing
		var offset_x = sin(angle_rad) * fan_radius + horizontal_offset
		var offset_y = -cos(angle_rad) * fan_radius + fan_radius - fan_curve_height
		
		var target_pos = Vector2(
			center_x + offset_x - card_width / 2,
			base_y + offset_y
		)
		
		# Применяем разталкивание к target_pos
		var push_offset = card.get_meta("push_offset", Vector2.ZERO)
		target_pos += push_offset
		
		# Защита от выхода за экран
		var margin = 20  # Минимальный отступ от края
		target_pos.x = clamp(target_pos.x, margin, screen_size.x - card_width - margin)
		
		# Z-index
		var distance_from_center = abs(i - total_visible / 2.0)
		var base_z = base_z_index + int(total_visible - distance_from_center) * 10
		
		# Если это выбранная/наведенная карта - поднимаем её
		var is_special = (i == special_index)
		if is_special:
			target_pos.y -= selected_card_lift
			base_z = base_z_index + total_visible * 10 + 50
		
		# Расставляем весь стак на одной позиции
		layout_single_stack(stack, target_pos, angle_rad, base_z, is_special)

# Расстановка одного стака карт - карты СТРОГО друг за другом
func layout_single_stack(stack: Array, base_position: Vector2, rotation: float, base_z: int, is_special: bool = false):
	var stack_size = stack.size()
	
	# Определяем сколько карт показывать (максимум 6)
	var visible_count = min(stack_size, max_visible_cards_in_stack)
	
	for i in range(stack_size):
		var card = stack[i]
		if not is_instance_valid(card):
			continue
		
		# Останавливаем предыдущий твин этой карты
		if active_card_tweens.has(card):
			var old_tween = active_card_tweens[card]
			if old_tween and old_tween.is_valid():
				old_tween.kill()
		
		var is_top_card = (i == stack_size - 1)
		
		# Карты СТРОГО в одной точке с минимальным смещением для визуального эффекта
		var depth_index = stack_size - i - 1  # 0 для верхней карты
		
		# Если карта за пределами видимого лимита - скрываем полностью
		var is_visible = (depth_index < max_visible_cards_in_stack)
		
		# Увеличено смещение для лучшей видимости стака, и смещение только по y координате
		var stack_offset = Vector2(0, -depth_index * card_stack_offset * 1.2)
		var target_pos = base_position + stack_offset
		
		# Z-index: чем глубже в стаке, тем ниже слой
		card.z_index = base_z - depth_index
		
		if is_special and is_top_card:
			card.z_index = base_z + 100  # Высоко над всем
		
		# КРИТИЧНО: Только верхняя карта интерактивна
		card.input_pickable = is_top_card
		card.monitorable = is_top_card
		card.monitoring = is_top_card
		
		# Скрываем ValueLabel у всех карт кроме верхней
		var value_label = card.get_node_or_null("ValueLabel")
		if value_label:
			value_label.visible = is_top_card  # Показываем только на верхней карте
		
		# Все видимые карты показываются без затемнения и уменьшения
		var target_alpha = 1.0
		var target_scale_multiplier = 1.0
		
		if not is_visible:
			# Карты за лимитом полностью скрыты
			target_alpha = 0.0
		
		var target_modulate = Color(1, 1, 1, target_alpha)
		
		# Получаем спрайт и его масштаб
		var sprite = card.get_node_or_null("Sprite2D")
		if not sprite:
			continue
		
		var original_scale = original_card_scales.get(card, Vector2(3, 3))
		var target_scale = original_scale * target_scale_multiplier
		
		# Анимация
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.set_parallel(true)
		
		# ВАЖНО: Позиция карты НЕ меняется при расталкивании
		tween.tween_property(card, "position", target_pos, 0.4 / animation_speed)
		tween.tween_property(card, "rotation", rotation, 0.4 / animation_speed)
		tween.tween_property(sprite, "modulate", target_modulate, 0.3 / animation_speed)
		tween.tween_property(sprite, "scale", target_scale, 0.3 / animation_speed)
		
		# Сохраняем твин
		active_card_tweens[card] = tween
		tween.finished.connect(func(): 
			if active_card_tweens.has(card):
				active_card_tweens.erase(card)
		)
	
	if stack.size() > 0:
		var top_card = stack[-1]
		if is_instance_valid(top_card):
			update_stack_indicator(top_card)

func _process(_delta):
	summons = summons.filter(func(s): return is_instance_valid(s))
	
	# Обновляем 3D для всех карт в наведенном стаке
	if hovered_card and is_instance_valid(hovered_card):
		var mouse_pos = get_viewport().get_mouse_position()
		var stack_id = get_card_stack_id(hovered_card)
		if card_stacks.has(stack_id):
			var stack = card_stacks[stack_id]
			for stack_card in stack:
				if is_instance_valid(stack_card) and stack_card.get_meta("track_mouse", false):
					update_card_3d_rotation(stack_card, mouse_pos)
	
	# Обновляем 3D поворот для главной карты
	if Main_card_area and Main_card_area.get_meta("track_mouse", false):
		var mouse_pos = get_viewport().get_mouse_position()
		update_main_card_3d_rotation(mouse_pos)
	
	# Обновляем 3D поворот для саммонов
	for summon in summons:
		if summon and is_instance_valid(summon):
			if summon.get_meta("track_mouse", false):
				var mouse_pos = get_viewport().get_mouse_position()
				update_summon_3d_rotation(summon, mouse_pos)
	
	# Обновляем 3D поворот для врагов с проверкой
	var valid_enemies = enemies.filter(func(e): return e and is_instance_valid(e))
	for enemy in valid_enemies:
		if enemy.get_meta("track_mouse", false):
			var enemy_sprite = enemy.get_node_or_null("Sprite2D")
			if enemy_sprite and is_instance_valid(enemy_sprite) and enemy_sprite.material:
				var mouse_pos = get_viewport().get_mouse_position()
				update_enemy_3d_rotation(enemy, mouse_pos)

func _on_main_card_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		toggle_selection()


func _on_main_card_mouse_entered():
	if not is_animation_locked:
		var tween = create_tween()
		tween.tween_property(main_card_sprite, "scale", original_main_card_scale * 1.1, 0.2)
		Main_card_area.set_meta("track_mouse", true)


func _on_main_card_mouse_exited():
	if not is_animation_locked:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_parallel(true)
		tween.tween_property(main_card_sprite, "scale", original_main_card_scale, 0.2)
		Main_card_area.set_meta("track_mouse", true)
		reset_card_3d_rotation(main_card_sprite)


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
	
	if not card.input_pickable:
		return
	
	if hovered_card == card:
		return
	
	var stack_id = get_card_stack_id(card)
	if card_stacks.has(stack_id):
		var stack = card_stacks[stack_id]
		if stack[-1] != card:
			return
	
	if tooltip_hide_timer:
		tooltip_hide_timer.stop()
	
	if hovered_card and hovered_card != card:
		_on_card_hover_exited(hovered_card)
	
	hovered_card = card
	is_animation_locked = true
	
	# Поднимаем ВСЕ карты в стаке
	if card_stacks.has(stack_id):
		var stack = card_stacks[stack_id]
		for stack_card in stack:
			if not is_instance_valid(stack_card):
				continue
			
			var sprite = stack_card.get_node("Sprite2D")
			var shape = stack_card.get_node("CollisionShape2D")
			var original_scale = original_card_scales.get(stack_card, Vector2(3, 3))
			
			# Только верхнюю карту увеличиваем
			var target_scale = original_scale * 1.25 if stack_card == card else original_scale
			
			# Поднимаем спрайт
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(sprite, "position:y", -selected_card_lift, 0.2 / animation_speed)
			tween.tween_property(sprite, "scale", target_scale, 0.2 / animation_speed)
			
			# Растягиваем коллизию только у верхней карты
			# Используем TRUE оригинальный размер
			if stack_card == card and shape and shape.shape is RectangleShape2D:
				var true_original = shape.get_meta("true_original_size", Vector2(100, 100))
				var new_size = Vector2(true_original.x, true_original.y + selected_card_lift)
				shape.shape.size = new_size
				shape.position.y = -selected_card_lift / 2
			
			stack_card.z_index = base_z_index + 9999
			stack_card.set_meta("track_mouse", true)
	
	for sub_card in sub_cards:
		if is_instance_valid(sub_card):
			if sub_card == card:
				sub_card.input_pickable = true
			else:
				sub_card.set_meta("temp_input_disabled", true)
	
	push_adjacent_cards(card)
	request_layout()
	
	await get_tree().process_frame
	is_animation_locked = false
	
	show_card_tooltip(card)


func _on_card_hover_exited(card: Area2D) -> void:
	if selected_card == card || attack_mode || game_state != GameState.PLAYER_TURN:
		return
	
	if not original_card_scales.has(card):
		return
	
	if hovered_card != card:
		return
	
	hovered_card = null
	
	for sub_card in sub_cards:
		if is_instance_valid(sub_card):
			sub_card.set_meta("temp_input_disabled", false)
	
	# Опускаем ВСЕ карты в стаке
	var stack_id = get_card_stack_id(card)
	if card_stacks.has(stack_id):
		var stack = card_stacks[stack_id]
		for stack_card in stack:
			if not is_instance_valid(stack_card):
				continue
			
			var sprite = stack_card.get_node("Sprite2D")
			var shape = stack_card.get_node("CollisionShape2D")
			var original_scale = original_card_scales.get(stack_card, Vector2(3, 3))
			
			# Опускаем спрайт обратно
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(sprite, "position", Vector2.ZERO, 0.2 / animation_speed)
			tween.tween_property(sprite, "scale", original_scale, 0.2 / animation_speed)
			
			# Возвращаем коллизию только у верхней карты
			# Используем TRUE оригинальный размер
			if stack_card == card and shape and shape.shape is RectangleShape2D:
				var true_original = shape.get_meta("true_original_size", Vector2(100, 100))
				shape.shape.size = true_original
				shape.position = Vector2.ZERO
			
			stack_card.set_meta("track_mouse", false)
			reset_card_3d_rotation(sprite)
			stack_card.z_index = 0
	
	request_layout()
	reset_card_push()
	if tooltip_hide_timer:
		tooltip_hide_timer.start()

func show_card_tooltip(card: Area2D):
	if not card_tooltip or not tooltip_label:
		return
	
	# Останавливаем таймер скрытия
	if tooltip_hide_timer:
		tooltip_hide_timer.stop()
	
	if hovered_card != card:
		return
	
	tooltip_label.text = get_card_description(card)
	
	await get_tree().process_frame
	tooltip_label.reset_size()
	card_tooltip.reset_size()
	
	card_tooltip.visible = true
	
	var card_pos = card.global_position
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = card_tooltip.size
	
	var tooltip_pos = Vector2()
	
	tooltip_pos.x = card_pos.x + 120
	tooltip_pos.y = card_pos.y - tooltip_size.y / 2
	
	if tooltip_pos.x + tooltip_size.x > screen_size.x - 20:
		tooltip_pos.x = card_pos.x - tooltip_size.x - 20
	
	if tooltip_pos.x < 20:
		tooltip_pos.x = (screen_size.x - tooltip_size.x) / 2
	
	if tooltip_pos.y < 20:
		tooltip_pos.y = 20
	elif tooltip_pos.y + tooltip_size.y > screen_size.y - 20:
		tooltip_pos.y = screen_size.y - tooltip_size.y - 20
	
	card_tooltip.global_position = tooltip_pos


func hide_card_tooltip():
	# Используем таймер для плавного скрытия
	if tooltip_hide_timer and not tooltip_hide_timer.is_stopped():
		return
	
	if card_tooltip:
		card_tooltip.visible = false



func _on_card_input(_viewport, event, _shape_idx, card: Area2D) -> void:
	# Игнорируем временно отключенные карты
	if card.get_meta("temp_input_disabled", false):
		return
	if game_state != GameState.PLAYER_TURN or is_animation_locked or is_flipping:
		return
	#  Игнорируем неинтерактивные карты
	if not card.input_pickable:
		return
	
	if event is InputEventMouseButton and event.pressed:
		# КРИТИЧНО: Сбрасываем hovered_card и tooltip
		if tooltip_hide_timer:
			tooltip_hide_timer.stop()
		
		hide_card_tooltip()
		
		# СБРОС hover состояния ПЕРЕД использованием карты
		if hovered_card == card:
			var stack_id = get_card_stack_id(card)
			if card_stacks.has(stack_id):
				var stack = card_stacks[stack_id]
				for stack_card in stack:
					if not is_instance_valid(stack_card):
						continue
					
					var sprite = stack_card.get_node("Sprite2D")
					var shape = stack_card.get_node("CollisionShape2D")
					var original_scale = original_card_scales.get(stack_card, Vector2(3, 3))
					
					# Мгновенно сбрасываем без твина
					sprite.position = Vector2.ZERO
					sprite.scale = original_scale
					
					if stack_card == card and shape and shape.shape is RectangleShape2D:
						var true_original = shape.get_meta("true_original_size", Vector2(100, 100))
						shape.shape.size = true_original
						shape.position = Vector2.ZERO
					
					stack_card.set_meta("track_mouse", false)
					stack_card.z_index = 0
		
		hovered_card = null
		reset_card_push()
		
		var sprite = card.get_node("Sprite2D")
		var shape = card.get_node("CollisionShape2D")
		var card_cost = card.get_meta("cost", 1)
		
		if energy < card_cost:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
			tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
			return
		
		var effect = get_current_card_effect(card)
		
		if effect["type"] in [CardEffect.SUMMON, CardEffect.DEFENSE, CardEffect.HEAL, CardEffect.FLIP, CardEffect.STRENGTH, CardEffect.REGEN]:
			match effect["type"]:
				CardEffect.SUMMON:
					await apply_summon_effect(effect, card_cost, card)
				CardEffect.DEFENSE:
					await apply_defense_effect(effect, card_cost, card)
				CardEffect.HEAL:
					await apply_heal_effect(effect, card_cost, card)
				CardEffect.FLIP:
					await apply_flip_effect(effect, card_cost, card)
				CardEffect.STRENGTH:
					await apply_strength_effect(effect, card_cost, card)
				CardEffect.REGEN:
					await apply_regen_effect(effect, card_cost, card)
			
			# Обновляем интерактивность после использования
			await get_tree().process_frame
			update_all_cards_interactivity()
			return
		
		if current_attack_card and current_attack_card != card:
			reset_card_highlight(current_attack_card)
			layout_subcards()
		
		if current_attack_card == card:
			reset_card_highlight(card)
			current_attack_card = null
			attack_mode = false
			reset_all_enemy_highlights()
			layout_subcards()
		else:
			current_attack_card = card
			attack_mode = true
			
			if not original_card_scales.has(card):
				return
			
			# Поднимаем выбранную карту поверх всех
			card.z_index = base_z_index + sub_cards.size() + 20
			
			var original_scale = original_card_scales[card]
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(sprite, "position:y", sprite.position.y - 30, 0.2 / animation_speed)
			tween.tween_property(shape, "position:y", shape.position.y - 30, 0.2 / animation_speed)
			tween.tween_property(sprite, "scale", original_scale * 1.3, 0.2 / animation_speed)
			tween.tween_property(sprite, "modulate", Color(1, 0.8, 0.8), 0.2 / animation_speed)
			
			# Перерисовываем с поднятием карты
			layout_subcards()
			
			highlight_all_enemies()


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
	
	add_transformation_progress()
	await check_and_transform()


func end_player_turn():
	game_state = GameState.ENEMY_TURN
	turn_label.text = "Enemy Turn"
	end_turn_button.disabled = true
	
	await summons_attack()
	
	enemy_attack()


func summons_attack():
	if summons.is_empty() or enemies.is_empty():
		return
	
	is_animation_locked = true
	
	for summon in summons:
		if not is_instance_valid(summon):
			continue
		
		var alive_enemies = enemies.filter(func(e): return e and is_instance_valid(e))
		if alive_enemies.is_empty():
			break
		
		var target_enemy = alive_enemies[randi() % alive_enemies.size()]
		
		var summon_sprite = summon.get_node_or_null("Sprite2D")
		if summon_sprite:
			var original_pos = summon.position
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(summon, "position", summon.position + Vector2(100, 0), 0.15)
			tween.tween_property(summon, "position", original_pos, 0.15)
		
		var damage = summon.attack_enemy(target_enemy)
		
		if damage > 0:
			create_damage_number(target_enemy, damage, false)
		
		if target_enemy and is_instance_valid(target_enemy) and target_enemy.has_method("take_damage"):
			target_enemy.take_damage(damage)
		
		await get_tree().create_timer(0.15).timeout
	
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
	await tween.finished
	request_layout() 


func highlight_enemy(enemy: Node2D):
	if not enemy or not is_instance_valid(enemy):
		return
	
	var enemy_sprite = enemy.get_node_or_null("Sprite2D")
	if enemy_sprite:
		var tween = create_tween()
		tween.tween_property(enemy_sprite, "modulate", Color(1, 0.5, 0.5), 0.3)
		tween.set_loops()
		enemy.set_meta("highlight_tween", tween)


func reset_enemy_highlight(enemy: Node2D):
	if not enemy or not is_instance_valid(enemy):
		return
	
	var tween = enemy.get_meta("highlight_tween", null)
	if tween and tween.is_valid():
		tween.kill()
	
	var enemy_sprite = enemy.get_node_or_null("Sprite2D")
	if enemy_sprite:
		var reset_tween = create_tween()
		reset_tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.3)


func _on_enemy_input(_viewport, event, _shape_idx, enemy: Node2D):
	if game_state != GameState.PLAYER_TURN or is_animation_locked or is_flipping:
		return
	
	if event is InputEventMouseButton and event.pressed and attack_mode and current_attack_card:
		hide_enemy_tooltip()
		var card_cost = current_attack_card.get_meta("cost", 1)
		
		if energy < card_cost:
			var sprite = current_attack_card.get_node("Sprite2D")
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
			tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
			return
		
		selected_enemy = enemy
		print("Selected enemy: ", enemy.get_meta("enemy_name"))
		
		var used_card = current_attack_card
		
		reset_card_highlight(used_card)
		attack_mode = false
		current_attack_card = null
		reset_all_enemy_highlights()
		
		var effect = get_current_card_effect(used_card)
		
		match effect["type"]:
			CardEffect.ATTACK:
				await apply_attack_effect(effect, card_cost, used_card)
			CardEffect.FIREBALL:
				await apply_fireball_effect(effect, card_cost, used_card)
			CardEffect.VULNERABLE:
				await apply_vulnerable_effect(effect, card_cost, used_card)
			CardEffect.POISON:
				await apply_poison_effect(effect, card_cost, used_card)
			CardEffect.WEAK:
				await apply_weak_effect(effect, card_cost, used_card)
			CardEffect.CHAIN_LIGHTNING:
				await apply_chain_lightning_effect(effect, card_cost, used_card)
			_:
				discard_card(used_card)
		
		selected_enemy = null


func shake_enemy(enemy: Node2D = null) -> void:
	if enemy == null:
		enemy = selected_enemy
	
	if not enemy or not is_instance_valid(enemy):
		print("Cannot shake - enemy doesn't exist")
		return
	
	is_animation_locked = true
	var enemy_sprite = enemy.get_node_or_null("Sprite2D")
	
	if not enemy_sprite:
		is_animation_locked = false
		return
	
	var current_modulate = enemy_sprite.modulate
	var original_scale = enemy.get_meta("original_scale")
	var original_position = enemy.get_meta("original_position")
	
	enemy_sprite.modulate = Color(1.5, 0.5, 0.5)
	
	var shake_count = 8
	var shake_intensity = 15.0
	var shake_duration = 0.3
	
	for i in range(shake_count):
		if not enemy or not is_instance_valid(enemy):
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
		tween.tween_property(enemy, "position", original_position + offset, shake_duration / shake_count / 2)
		tween.tween_property(enemy, "position", original_position, shake_duration / shake_count / 2)
		
		await tween.finished
	
	if not enemy or not is_instance_valid(enemy):
		is_animation_locked = false
		return
	
	enemy.position = original_position
	
	var pulse_tween = create_tween()
	pulse_tween.tween_property(enemy_sprite, "scale", original_scale * 1.1, 0.1)
	pulse_tween.tween_property(enemy_sprite, "scale", original_scale, 0.1)
	pulse_tween.parallel().tween_property(enemy_sprite, "modulate", current_modulate, 0.2)
	
	await pulse_tween.finished
	is_animation_locked = false


func _on_enemy_mouse_entered(enemy: Node2D):
	if enemy and is_instance_valid(enemy):
		var enemy_sprite = enemy.get_node("Sprite2D")
		var original_scale = enemy.get_meta("original_scale")
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(enemy_sprite, "scale", original_scale * 1.1, 0.5)
		enemy.set_meta("track_mouse", true)
		show_enemy_tooltip(enemy)


func _on_enemy_mouse_exited(enemy: Node2D):
	if not enemy or not is_instance_valid(enemy):
		return
	
	var enemy_sprite = enemy.get_node_or_null("Sprite2D")
	if not enemy_sprite or not is_instance_valid(enemy_sprite):
		return
	
	var original_scale = enemy.get_meta("original_scale", Vector2(1, 1))
	var tween = create_tween()
	tween.tween_property(enemy_sprite, "scale", original_scale, 0.15)
	
	# Выключаем 3D эффект
	enemy.set_meta("track_mouse", false)
	
	# Проверяем материал перед сбросом
	if enemy_sprite.material:
		reset_card_3d_rotation(enemy_sprite)
	
	hide_enemy_tooltip()


func remove_card(card: Area2D):
	discard_card(card)
	layout_subcards()


func apply_attack_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	var base_damage = effect["value"]
	var damage = player_effects.modify_outgoing_damage(base_damage)
	
	var strength = player_effects.get_effect(StatusEffectSystem.EffectType.STRENGTH)
	if strength > 0:
		print("Attack: %d base + %d strength = %d total" % [base_damage, strength, damage])
	
	if not selected_enemy or not is_instance_valid(selected_enemy):
		print("ERROR: No enemy selected!")
		discard_card(card)
		return
	
	await shake_enemy(selected_enemy)
	
	if selected_enemy.has_method("take_damage"):
		var enemy_effects = enemy_effects_map.get(selected_enemy)
		if enemy_effects:
			var damage_result = enemy_effects.modify_incoming_damage(damage)
			
			if damage_result["blocked"] > 0:
				create_damage_number(selected_enemy, damage_result["blocked"], false)
				await get_tree().create_timer(0.3).timeout
			
			if damage_result["damage"] > 0:
				create_damage_number(selected_enemy, damage_result["damage"], false)
			
			selected_enemy.take_damage(damage_result["damage"])
			
			if damage_result["blocked"] > 0:
				print("Blocked %d damage" % damage_result["blocked"])
	
	var draw_amount = card.get_meta("front_draw_cards" if not card.get_meta("flipped", false) else "back_draw_cards", 0)
	if draw_amount > 0:
		draw_cards(draw_amount)
	
	discard_card(card)
	
	if draw_amount > 0:
		await get_tree().process_frame
		layout_subcards()
	
	add_transformation_progress()
	await check_and_transform()


func apply_defense_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	player_effects.add_effect(StatusEffectSystem.EffectType.BLOCK, effect["value"])
	
	var tween = create_tween()
	tween.tween_property(main_card_sprite, "modulate", Color(0.2, 0.5, 1), 0.2)
	tween.tween_property(main_card_sprite, "modulate", Color(1, 1, 1), 0.2)
	
	update_ui()
	
	var draw_amount = card.get_meta("front_draw_cards" if not card.get_meta("flipped", false) else "back_draw_cards", 0)
	if draw_amount > 0:
		draw_cards(draw_amount)
	
	discard_card(card)
	
	if draw_amount > 0:
		await get_tree().process_frame
		layout_subcards()
	
	add_transformation_progress()
	await check_and_transform()


func apply_heal_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	var heal_amount = effect["value"]
	create_damage_number(Main_card_area, heal_amount, true)
	player_hp = min(player_hp + heal_amount, player_max_hp)
	
	var tween = create_tween()
	tween.tween_property(main_card_sprite, "modulate", Color(0.2, 1, 0.2), 0.2)
	tween.tween_property(main_card_sprite, "modulate", Color(1, 1, 1), 0.2)
	
	update_ui()
	discard_card(card)
	
	add_transformation_progress()
	await check_and_transform()


func apply_fireball_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	var base_damage = effect["value"]
	var damage = player_effects.modify_outgoing_damage(base_damage)
	var burn = card.get_meta("burn_value", 10)
	
	if not selected_enemy or not is_instance_valid(selected_enemy):
		print("ERROR: No enemy selected!")
		discard_card(card)
		return
	
	await shake_enemy(selected_enemy)
	
	if selected_enemy and selected_enemy.has_method("take_damage"):
		var enemy_effects = enemy_effects_map.get(selected_enemy)
		if enemy_effects:
			var damage_result = enemy_effects.modify_incoming_damage(damage)
			selected_enemy.take_damage(damage_result["damage"])
			
			enemy_effects.add_effect(StatusEffectSystem.EffectType.BURN, burn)
			update_ui()
	
	discard_card(card)
	
	add_transformation_progress()
	await check_and_transform()


func apply_flip_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	if card in sub_cards:
		sub_cards.erase(card)
	
	await flip_all_cards_in_deck()
	
	player_transformed = flipped
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
	
	var sorted_stacks = organize_card_stacks()
	
	for stack_data in sorted_stacks:
		var stack = stack_data["cards"]
		
		for card in stack:
			if not is_instance_valid(card):
				continue
			
			# Обновляем метаданные ПЕРЕД update_card_value_label
			card.set_meta("flipped", flipped)
			flip_card(card, flipped)  # Запускаем анимацию
			update_card_value_label(card)  # Теперь метаданные уже правильные
		
		await get_tree().create_timer(0.05 / animation_speed).timeout
	
	print("Flipping draw_pile, count: ", draw_pile.size())
	for card in draw_pile:
		if is_instance_valid(card):
			card.set_meta("flipped", flipped)  # Обновляем метаданные
			flip_card_instantly(card, flipped)
			update_card_value_label(card)
	
	print("Flipping discard_pile, count: ", discard_pile.size())
	for card in discard_pile:
		if is_instance_valid(card):
			card.set_meta("flipped", flipped)  # Обновляем метаданные
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
	
	player_effects.set_effect(StatusEffectSystem.EffectType.BLOCK, 0)
	
	var turn_effects = player_effects.apply_start_of_turn_effects()
	if turn_effects["damage"] > 0:
		player_hp = max(player_hp - turn_effects["damage"], 0)
	if turn_effects["heal"] > 0:
		player_hp = min(player_hp + turn_effects["heal"], player_max_hp)
	
	for msg in turn_effects["messages"]:
		print("Player: ", msg)
	
	update_ui()
	turn_label.text = "Your Turn"
	end_turn_button.disabled = false
	
	if current_attack_card:
		reset_card_highlight(current_attack_card)
		current_attack_card = null
		attack_mode = false
		reset_all_enemy_highlights()
	
	reset_hand()
	draw_cards(cards_per_turn)
	
	await get_tree().process_frame
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
	
	if enemies.is_empty():
		print("No enemies alive")
		is_animation_locked = false
		await get_tree().create_timer(0.5).timeout
		start_player_turn()
		return
	
	enemies = enemies.filter(func(e): return e and is_instance_valid(e))
	
	if enemies.is_empty():
		print("All enemies dead after cleanup")
		is_animation_locked = false
		await get_tree().create_timer(0.5).timeout
		await spawn_enemies(randi_range(1, 3))
		start_player_turn()
		return
	
	var enemies_copy = enemies.duplicate()
	
	for enemy in enemies_copy:
		if not enemy or not is_instance_valid(enemy):
			continue
		
		if not enemy in enemies:
			continue
		
		# ДОБАВЛЕНО: Проверяем что у врага есть спрайт
		var enemy_sprite = enemy.get_node_or_null("Sprite2D")
		if not enemy_sprite:
			continue
		
		print("=== Enemy %s turn ===" % enemy.get_meta("enemy_name"))
		
		var enemy_effects = enemy_effects_map.get(enemy)
		if not enemy_effects:
			continue
		
		if not enemy or not is_instance_valid(enemy):
			continue
		
		enemy_effects.set_effect(StatusEffectSystem.EffectType.BLOCK, 0)
		enemy_effects.reduce_temporary_effects()
		
		if enemy and is_instance_valid(enemy) and enemy.has_method("update_ui"):
			enemy.update_ui()
		
		var turn_effects = {"damage": 0, "heal": 0, "messages": []}
		if enemy and is_instance_valid(enemy):
			turn_effects = enemy_effects.apply_start_of_turn_effects()
		else:
			continue
		
		if turn_effects["damage"] > 0:
			if not enemy or not is_instance_valid(enemy):
				continue
			
			create_damage_number(enemy, turn_effects["damage"], false)
			await get_tree().create_timer(0.3).timeout
			
			if not enemy or not is_instance_valid(enemy):
				continue
			
			if enemy.has_method("take_damage"):
				enemy.take_damage(turn_effects["damage"])
			
			# Проверяем жив ли враг после урона
			if not enemy or not is_instance_valid(enemy):
				print("Enemy died from effects")
				if enemy in enemies:
					enemies.erase(enemy)
				if enemy_effects_map.has(enemy):
					enemy_effects_map.erase(enemy)
				continue
			
			# ИСПРАВЛЕНО: Проверяем существование спрайта перед анимацией
			enemy_sprite = enemy.get_node_or_null("Sprite2D")
			if enemy_sprite and is_instance_valid(enemy_sprite):
				var burn_tween = create_tween()
				burn_tween.tween_property(enemy_sprite, "modulate", Color(1, 0.4, 0), 0.3)
				burn_tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.3)
				await burn_tween.finished
		
		if turn_effects["heal"] > 0:
			if enemy and is_instance_valid(enemy):
				create_damage_number(enemy, turn_effects["heal"], true)
				enemy.current_hp = min(enemy.current_hp + turn_effects["heal"], enemy.max_hp)
				if enemy.has_method("update_ui"):
					enemy.update_ui()
		
		for msg in turn_effects["messages"]:
			if enemy and is_instance_valid(enemy):
				print("Enemy %s: %s" % [enemy.get_meta("enemy_name"), msg])
		
		update_ui()
		
		if not enemy or not is_instance_valid(enemy):
			print("Enemy died, skipping action")
			continue
		
		var action = enemy.next_action if enemy.next_action != null else EnemyAction.ATTACK_PLAYER
		print("Enemy action: ", action)
		
		match action:
			EnemyAction.ATTACK_PLAYER:
				if enemy and is_instance_valid(enemy):
					await enemy_action_attack_player(enemy)
			EnemyAction.ATTACK_ALL:
				if enemy and is_instance_valid(enemy):
					await enemy_action_attack_all(enemy)
			EnemyAction.DEFEND:
				if enemy and is_instance_valid(enemy):
					await enemy_action_defend(enemy)
			EnemyAction.SUMMON_ALLY:
				if enemy and is_instance_valid(enemy):
					await enemy_summon_ally(enemy)
		
		if enemy and is_instance_valid(enemy) and enemy.has_method("choose_next_action"):
			enemy.choose_next_action()
			print("Next enemy action: ", enemy.next_action)
		
		await get_tree().create_timer(0.5).timeout
	
	# Финальная очистка и проверка на спавн новых врагов
	enemies = enemies.filter(func(e): return e and is_instance_valid(e))
	
	if enemies.is_empty():
		print("All enemies died during turn! Spawning new wave...")
		await get_tree().create_timer(0.5).timeout
		await spawn_enemies(randi_range(1, 3))
	
	if player_hp <= 0:
		print("Player died!")
		game_over()
	else:
		await get_tree().create_timer(0.5).timeout
		start_player_turn()
	
	is_animation_locked = false
	print(">>> enemy_attack() END")	

func update_ui():
	player_hp_label.text = "Mage: %d/%d HP" % [player_hp, player_max_hp]
	energy_label.text = "Energy: %d/%d" % [energy, max_energy]
	
	var block = player_effects.get_effect(StatusEffectSystem.EffectType.BLOCK)
	block_label.text = "Block: %d" % block
	
	update_gold_display()
	
	if player_effects:
		player_effects.update_display()
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			var enemy_effects = enemy_effects_map.get(enemy)
			if enemy_effects:
				enemy_effects.update_display()


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


func create_card_tooltip(parent_layer: CanvasLayer):
	card_tooltip = PanelContainer.new()
	card_tooltip.name = "CardTooltip"
	card_tooltip.visible = false
	card_tooltip.z_index = 1000  # Высокий z-index внутри слоя
	card_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
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
	
	tooltip_label = RichTextLabel.new()
	tooltip_label.bbcode_enabled = true
	tooltip_label.fit_content = true
	tooltip_label.scroll_active = false
	tooltip_label.custom_minimum_size = Vector2(200, 0)
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	card_tooltip.add_child(tooltip_label)
	parent_layer.add_child(card_tooltip)  #  добавляем в отдельный слой


func get_card_description(card: Area2D) -> String:
	var is_flipped = card.get_meta("flipped", false)
	var effect_type
	var value
	var cost = card.get_meta("cost", 1)
	var draw_amount = 0
	
	if is_flipped:
		effect_type = card.get_meta("back_effect_type", CardEffect.DEFENSE)
		value = card.get_meta("back_effect_value", 0)
		draw_amount = card.get_meta("back_draw_cards", 0)
	else:
		effect_type = card.get_meta("front_effect_type", CardEffect.ATTACK)
		value = card.get_meta("front_effect_value", 0)
		draw_amount = card.get_meta("front_draw_cards", 0)
	
	var description = "[center][b]Cost: [color=#FFD700]%d[/color] Energy[/b][/center]\n\n" % cost
	
	match effect_type:
		CardEffect.ATTACK:
			description += "[color=#FF3333]⚔ Attack[/color]\nDeal [b]%d[/b] damage to the enemy." % value
			if draw_amount > 0:
				description += "\n\n[color=#FFAA66]📜 Draw %d card%s.[/color]" % [draw_amount, "s" if draw_amount > 1 else ""]
		
		CardEffect.DEFENSE:
			description += "[color=#3388FF]🛡 Defense[/color]\nGain [b]%d[/b] block.\nBlock absorbs incoming damage." % value
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
		
		CardEffect.POISON:
			description += "[color=#66FF66]☠ Poison[/color]\nApply [b]%d[/b] Poison to enemy.\n\n[color=#888888]Poison deals damage at start of turn, reduces by 1.[/color]" % value
		
		CardEffect.REGEN:
			description += "[color=#33FF33]❤ Regeneration[/color]\nGain [b]%d[/b] Regen.\n\n[color=#888888]Heals HP at the start of each turn.[/color]" % value
		
		CardEffect.WEAK:
			description += "[color=#999999]💤 Weaken[/color]\nApply [b]%d[/b] Weak to enemy.\n\n[color=#888888]Weak enemies deal 25%% less damage per stack. Decreases by 1 each turn.[/color]" % value
		
		CardEffect.CHAIN_LIGHTNING:
			description += "[color=#FFFF66]⚡ Chain Lightning[/color]\nDeal [b]%d[/b] damage to ALL enemies." % value
	
	return description


func spawn_summon(summon_type: String = "basic"):
	if summons.size() >= max_summons:
		print("Maximum summons reached!")
		return null
	
	var summon = summon_scene.instantiate()
	add_child(summon)
	
	var summon_x = 200
	var summon_y = 400 + summons.size() * 100
	summon.position = Vector2(summon_x, summon_y)
	
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
	
	var summon_sprite = summon.get_node("Sprite2D")
	summon_sprite.texture = defense_texture
	summon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	summon_sprite.modulate = Color(0.5, 1, 0.5)
	setup_card_3d_shader(summon_sprite)	
	
	summon.connect("mouse_entered", Callable(self, "_on_summon_mouse_entered").bind(summon))
	summon.connect("mouse_exited", Callable(self, "_on_summon_mouse_exited").bind(summon))

	summon.update_ui()
	summons.append(summon)
	
	print("Summoned: ", summon.summon_name)
	return summon


func create_summon_card(summon_type: String = "basic") -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	var shape := card.get_node("CollisionShape2D") 
	if shape and shape.shape is RectangleShape2D:
		shape.set_meta("true_original_size", shape.shape.size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	setup_card_3d_shader(sprite)
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	sprite.set_meta("front_texture", defense_texture)
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


func on_enemy_died(reward_gold: int, dead_enemy: Node2D):
	print("Enemy died! Reward: ", reward_gold)
	
	reward_player(reward_gold)
	
	# Удаляем из массива и словаря эффектов
	if dead_enemy in enemies:
		enemies.erase(dead_enemy)
	
	if enemy_effects_map.has(dead_enemy):
		var effects = enemy_effects_map[dead_enemy]
		if effects and effects.has_method("clear_all_effects"):
			effects.clear_all_effects()
		enemy_effects_map.erase(dead_enemy)
	
	# Очистка мертвых врагов
	enemies = enemies.filter(func(e): return e and is_instance_valid(e))
	
	# Проверяем это во время хода игрока или врага
	if game_state == GameState.PLAYER_TURN:
		# Если это ход игрока и все враги мертвы - спавним сразу
		if enemies.is_empty():
			print("All enemies defeated! Spawning new wave...")
			await get_tree().create_timer(0.5).timeout
			await spawn_enemies(randi_range(1, 3))
	# Если это ход врага - не спавним, это сделает enemy_attack()
	
	update_ui()


func enemy_action_attack_player(enemy: Node2D):
	if not enemy or not is_instance_valid(enemy):
		return
	
	print("Enemy attacking player...")
	
	var enemy_sprite = enemy.get_node_or_null("Sprite2D")
	var original_position = enemy.get_meta("original_position")
	
	if enemy_sprite:
		var tween = create_tween()
		tween.tween_property(enemy, "position", original_position + Vector2(0, -50), 0.2)
		tween.tween_property(enemy, "position", original_position, 0.2)
		await tween.finished
	
	if not enemy or not is_instance_valid(enemy):
		return
	
	var enemy_effects = enemy_effects_map.get(enemy)
	if not enemy_effects:
		return
	
	var base_damage = enemy.attack_damage
	var damage = enemy_effects.modify_outgoing_damage(base_damage)
	var damage_result = player_effects.modify_incoming_damage(damage)
	
	var actual_damage = damage_result["damage"]
	var blocked = damage_result["blocked"]
	
	if blocked > 0:
		print("Player blocked %d damage" % blocked)
		create_damage_number(Main_card_area, blocked, false)
		await get_tree().create_timer(0.3).timeout
	
	if actual_damage > 0:
		create_damage_number(Main_card_area, actual_damage, false)
		player_hp = max(player_hp - actual_damage, 0)
		
		var player_tween = create_tween()
		player_tween.tween_property(main_card_sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
		player_tween.tween_property(main_card_sprite, "modulate", Color(1, 1, 1), 0.1)
	
	print("Enemy dealt %d damage to player" % actual_damage)
	update_ui()


func enemy_action_attack_all(enemy: Node2D):
	if not enemy or not is_instance_valid(enemy):
		return
	
	print("Enemy attacking ALL targets...")
	
	var enemy_sprite = enemy.get_node_or_null("Sprite2D")
	var original_scale = enemy.get_meta("original_scale")
	var original_position = enemy.get_meta("original_position")
	
	if enemy_sprite:
		var tween = create_tween()
		tween.tween_property(enemy_sprite, "scale", original_scale * 1.3, 0.2)
		tween.tween_property(enemy_sprite, "modulate", Color(1.5, 0.5, 0.5), 0.2)
		tween.parallel().tween_property(enemy, "position", original_position + Vector2(0, -30), 0.2)
		tween.tween_property(enemy_sprite, "scale", original_scale, 0.2)
		tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.2)
		tween.parallel().tween_property(enemy, "position", original_position, 0.2)
		await tween.finished
	
	if not enemy or not is_instance_valid(enemy):
		return
	
	var enemy_effects = enemy_effects_map.get(enemy)
	if not enemy_effects:
		return
	
	var base_damage = enemy.attack_damage
	var aoe_damage = int(base_damage * 0.7)
	var damage = enemy_effects.modify_outgoing_damage(aoe_damage)
	
	var damage_result = player_effects.modify_incoming_damage(damage)
	var player_damage = damage_result["damage"]
	var blocked = damage_result["blocked"]
	
	if blocked > 0:
		print("Player blocked %d damage" % blocked)
		create_damage_number(Main_card_area, blocked, false)
		await get_tree().create_timer(0.3).timeout
	
	if player_damage > 0:
		create_damage_number(Main_card_area, player_damage, false)
		player_hp = max(player_hp - player_damage, 0)
		var player_tween = create_tween()
		player_tween.tween_property(main_card_sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
		player_tween.tween_property(main_card_sprite, "modulate", Color(1, 1, 1), 0.1)
	
	print("Enemy dealt %d damage to player (AoE)" % player_damage)
	
	var summons_to_remove = []
	for summon in summons:
		if not is_instance_valid(summon):
			summons_to_remove.append(summon)
			continue
		
		if summon.has_method("take_damage"):
			if damage > 0:
				create_damage_number(summon, damage, false)
			
			summon.take_damage(damage)
			print("Enemy dealt %d damage to summon" % damage)
			
			var summon_sprite = summon.get_node_or_null("Sprite2D")
			if summon_sprite:
				var tween = create_tween()
				tween.tween_property(summon_sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
				tween.tween_property(summon_sprite, "modulate", Color(1, 1, 1), 0.1)
	
	for s in summons_to_remove:
		summons.erase(s)
	
	update_ui()


func enemy_action_defend(enemy: Node2D):
	if not enemy or not is_instance_valid(enemy):
		return
	
	print("Enemy defending...")
	
	var enemy_effects = enemy_effects_map.get(enemy)
	if not enemy_effects:
		return
	
	var defense_amount = int(enemy.attack_damage * 1.5)
	enemy_effects.set_effect(StatusEffectSystem.EffectType.BLOCK, defense_amount)
	
	var enemy_sprite = enemy.get_node_or_null("Sprite2D")
	if enemy_sprite:
		var tween = create_tween()
		tween.tween_property(enemy_sprite, "modulate", Color(0.5, 0.5, 1.5), 0.3)
		tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.3)
		await tween.finished
	
	update_ui()
	print("Enemy gained %d block" % defense_amount)


func create_enemy_tooltip(parent_layer: CanvasLayer):
	enemy_tooltip = PanelContainer.new()
	enemy_tooltip.name = "EnemyTooltip"
	enemy_tooltip.visible = false
	enemy_tooltip.z_index = 1000  # Высокий z-index внутри слоя
	enemy_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.05, 0.05, 0.95)
	style_box.border_color = Color(1, 0.3, 0.3, 1)
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
	
	enemy_tooltip_label = RichTextLabel.new()
	enemy_tooltip_label.bbcode_enabled = true
	enemy_tooltip_label.fit_content = true
	enemy_tooltip_label.scroll_active = false
	enemy_tooltip_label.custom_minimum_size = Vector2(220, 0)
	enemy_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	enemy_tooltip.add_child(enemy_tooltip_label)
	parent_layer.add_child(enemy_tooltip)  # добавляем в отдельный слой


func get_enemy_action_description(enemy: Node2D) -> String:
	if not enemy or not is_instance_valid(enemy):
		return ""
	
	var enemy_name = enemy.get_meta("enemy_name", "Enemy")
	var hp = enemy.current_hp
	var max_hp = enemy.max_hp
	var damage = enemy.attack_damage
	
	var enemy_effects = enemy_effects_map.get(enemy)
	var block = 0
	var burn = 0
	var poison = 0
	var vulnerable = 0
	var weak = 0
	
	if enemy_effects:
		block = enemy_effects.get_effect(StatusEffectSystem.EffectType.BLOCK)
		burn = enemy_effects.get_effect(StatusEffectSystem.EffectType.BURN)
		poison = enemy_effects.get_effect(StatusEffectSystem.EffectType.POISON)
		vulnerable = enemy_effects.get_effect(StatusEffectSystem.EffectType.VULNERABLE)
		weak = enemy_effects.get_effect(StatusEffectSystem.EffectType.WEAK)
	
	var description = "[center][b][color=#FF6666]%s[/color][/b][/center]\n" % enemy_name
	description += "[center]HP: %d/%d[/center]\n\n" % [hp, max_hp]
	
	if block > 0:
		description += "[color=#6666FF]🛡 Block: %d[/color]\n" % block
	if burn > 0:
		description += "[color=#FF6600]🔥 Burn: %d[/color]\n" % burn
	if poison > 0:
		description += "[color=#66FF66]☠ Poison: %d[/color]\n" % poison
	if vulnerable > 0:
		description += "[color=#CC66FF]💔 Vulnerable: %d[/color]\n" % vulnerable
	if weak > 0:
		description += "[color=#999999]💤 Weak: %d[/color]\n" % weak
	
	if block > 0 or burn > 0 or poison > 0 or vulnerable > 0 or weak > 0:
		description += "\n"
	
	var action = enemy.next_action if enemy.next_action != null else EnemyAction.ATTACK_PLAYER
	
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
		
		EnemyAction.SUMMON_ALLY:
			description += "[color=#9933FF]👥 Summon Ally[/color]\n"
			description += "Summon another enemy."
	
	return description


func show_enemy_tooltip(enemy: Node2D):
	if not enemy_tooltip or not enemy_tooltip_label or not enemy:
		return
	
	enemy_tooltip_label.text = get_enemy_action_description(enemy)
	
	await get_tree().process_frame
	enemy_tooltip_label.reset_size()
	enemy_tooltip.reset_size()
	
	enemy_tooltip.visible = true
	
	var enemy_pos = enemy.global_position
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = enemy_tooltip.size
	
	var tooltip_pos = Vector2()
	
	tooltip_pos.x = enemy_pos.x - tooltip_size.x - 20
	tooltip_pos.y = enemy_pos.y - tooltip_size.y / 2
	
	if tooltip_pos.x < 20:
		tooltip_pos.x = enemy_pos.x + 100
	
	if tooltip_pos.x + tooltip_size.x > screen_size.x - 20:
		tooltip_pos.x = (screen_size.x - tooltip_size.x) / 2
	
	if tooltip_pos.y < 20:
		tooltip_pos.y = 20
	elif tooltip_pos.y + tooltip_size.y > screen_size.y - 20:
		tooltip_pos.y = screen_size.y - tooltip_size.y - 20
	
	enemy_tooltip.global_position = tooltip_pos


func hide_enemy_tooltip():
	if enemy_tooltip:
		enemy_tooltip.visible = false


func create_attack_draw_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	var shape := card.get_node("CollisionShape2D") 
	if shape and shape.shape is RectangleShape2D:
		shape.set_meta("true_original_size", shape.shape.size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	setup_card_3d_shader(sprite)	
	sprite.set_meta("front_texture", attackfunny_texture)
	sprite.texture = attackfunny_texture
	sprite.set_meta("back_texture", attack_texture)
	
	fit_texture_to_card(sprite, 50.0)
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	card.set_meta("front_effect_type", CardEffect.ATTACK)
	card.set_meta("front_effect_value", 15)
	card.set_meta("front_draw_cards", 2)
	
	card.set_meta("back_effect_type", CardEffect.ATTACK)
	card.set_meta("back_effect_value", 20)
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


func create_defense_draw_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	var shape := card.get_node("CollisionShape2D") 
	if shape and shape.shape is RectangleShape2D:
		shape.set_meta("true_original_size", shape.shape.size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	setup_card_3d_shader(sprite)	
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	sprite.set_meta("front_texture", defense_texture)
	sprite.texture = defense_texture
	sprite.set_meta("back_texture", defense_texture)
	
	card.set_meta("front_effect_type", CardEffect.DEFENSE)
	card.set_meta("front_effect_value", 12)
	card.set_meta("front_draw_cards", 2)
	
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


func create_transformation_bar():
	var container = VBoxContainer.new()
	container.position = Vector2(650, 700)
	container.custom_minimum_size = Vector2(200, 60)
	
	var title = Label.new()
	title.text = "Transformation"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title)
	
	transformation_bar = ProgressBar.new()
	transformation_bar.custom_minimum_size = Vector2(200, 30)
	transformation_bar.max_value = transformation_threshold
	transformation_bar.value = 0
	transformation_bar.show_percentage = false
	
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
	style_fg.bg_color = Color(1, 0.6, 0.2, 1)
	style_fg.corner_radius_top_left = 5
	style_fg.corner_radius_top_right = 5
	style_fg.corner_radius_bottom_left = 5
	style_fg.corner_radius_bottom_right = 5
	
	transformation_bar.add_theme_stylebox_override("background", style_bg)
	transformation_bar.add_theme_stylebox_override("fill", style_fg)
	
	container.add_child(transformation_bar)
	
	transformation_label = Label.new()
	transformation_label.text = "0/5"
	transformation_label.add_theme_font_size_override("font_size", 14)
	transformation_label.add_theme_color_override("font_color", Color(1, 1, 1))
	transformation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transformation_label.position = Vector2(0, -25)
	transformation_bar.add_child(transformation_label)
	
	$CanvasLayer.add_child(container)


func add_transformation_progress():
	transformation_progress += 1
	update_transformation_ui()
	
	var current_threshold = transformation_threshold if not flipped else transformation_threshold_return
	return transformation_progress >= current_threshold


func check_and_transform():
	var current_threshold = transformation_threshold if not flipped else transformation_threshold_return
	
	if transformation_progress >= current_threshold:
		transformation_progress = 0
		await toggle_player_transformation()


# Переключение формы игрока
func toggle_player_transformation():
	# player_transformed теперь следует за flipped
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
	
	# Используем flipped вместо player_transformed
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
	var shape := card.get_node("CollisionShape2D") 
	if shape and shape.shape is RectangleShape2D:
		shape.set_meta("true_original_size", shape.shape.size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	setup_card_3d_shader(sprite)
	# Используем текстуру атаки или создайте свою
	sprite.set_meta("front_texture", preload("res://defense_card.png"))
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
	var shape := card.get_node("CollisionShape2D") 
	if shape and shape.shape is RectangleShape2D:
		shape.set_meta("true_original_size", shape.shape.size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	setup_card_3d_shader(sprite)
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
	
	# Используем систему эффектов
	player_effects.add_effect(StatusEffectSystem.EffectType.STRENGTH, strength_gain)
	
	var tween = create_tween()
	tween.tween_property(main_card_sprite, "modulate", Color(1.5, 0.5, 0.5), 0.2)
	tween.tween_property(main_card_sprite, "modulate", Color(1, 1, 1), 0.2)
	
	var total_strength = player_effects.get_effect(StatusEffectSystem.EffectType.STRENGTH)
	print("Player gained %d strength! Total: %d" % [strength_gain, total_strength])
	update_ui()
	discard_card(card)
	
	add_transformation_progress()
	await check_and_transform()


# Применение эффекта уязвимости
func apply_vulnerable_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	var vulnerable_stacks = effect["value"]
	
	if selected_enemy and is_instance_valid(selected_enemy):
		var enemy_effects = enemy_effects_map.get(selected_enemy)
		if enemy_effects:
			enemy_effects.add_effect(StatusEffectSystem.EffectType.VULNERABLE, vulnerable_stacks)
			
			var enemy_sprite = selected_enemy.get_node_or_null("Sprite2D")
			if enemy_sprite:
				var tween = create_tween()
				tween.tween_property(enemy_sprite, "modulate", Color(1.5, 0.5, 1.5), 0.2)
				tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.2)
			
			var total_vulnerable = enemy_effects.get_effect(StatusEffectSystem.EffectType.VULNERABLE)
			print("Applied %d vulnerable to enemy! Total: %d" % [vulnerable_stacks, total_vulnerable])
			update_ui()
	
	discard_card(card)
	add_transformation_progress()
	await check_and_transform()

func apply_poison_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	var poison_stacks = effect["value"]
	
	if selected_enemy and is_instance_valid(selected_enemy):
		var enemy_effects = enemy_effects_map.get(selected_enemy)
		if enemy_effects:
			enemy_effects.add_effect(StatusEffectSystem.EffectType.POISON, poison_stacks)
		
		var enemy_sprite = selected_enemy.get_node_or_null("Sprite2D")
		if enemy_sprite:
			var tween = create_tween()
			tween.tween_property(enemy_sprite, "modulate", Color(0.5, 1.5, 0.5), 0.2)
			tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.2)
		
		var total_poison = enemy_effects.get_effect(StatusEffectSystem.EffectType.POISON)
		print("Applied %d poison to enemy! Total: %d" % [poison_stacks, total_poison])
		update_ui()
	
	discard_card(card)
	
	add_transformation_progress()
	await check_and_transform()

# Применение эффекта регенерации
func apply_regen_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	print("=== APPLYING REGEN EFFECT ===")
	print("Effect value: ", effect["value"])
	
	energy -= cost
	update_ui()
	
	var regen_amount = effect["value"]
	print("Adding regen: ", regen_amount)
	
	player_effects.add_effect(StatusEffectSystem.EffectType.REGEN, regen_amount)
	
	var tween = create_tween()
	tween.tween_property(main_card_sprite, "modulate", Color(0.3, 1.5, 0.3), 0.2)
	tween.tween_property(main_card_sprite, "modulate", Color(1, 1, 1), 0.2)
	
	var total_regen = player_effects.get_effect(StatusEffectSystem.EffectType.REGEN)
	print("Total regen after add: ", total_regen)
	
	update_ui()
	discard_card(card)
	
	add_transformation_progress()
	await check_and_transform()

# Применение эффекта ослабления
func apply_weak_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	var weak_stacks = effect["value"]
	
	if selected_enemy and is_instance_valid(selected_enemy):
		var enemy_effects = enemy_effects_map.get(selected_enemy)
		if enemy_effects:
			enemy_effects.add_effect(StatusEffectSystem.EffectType.WEAK, weak_stacks)
		
		var enemy_sprite = selected_enemy.get_node_or_null("Sprite2D")
		if enemy_sprite:
			var tween = create_tween()
			tween.tween_property(enemy_sprite, "modulate", Color(0.7, 0.7, 0.7), 0.2)
			tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.2)
		
		var total_weak = enemy_effects.get_effect(StatusEffectSystem.EffectType.WEAK)
		print("Applied %d weak to enemy! Total: %d" % [weak_stacks, total_weak])
		update_ui()
	
	discard_card(card)
	
	add_transformation_progress()
	await check_and_transform()

# 1. Карта "Яд" - накладывает poison на врага
func create_poison_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	var shape := card.get_node("CollisionShape2D") 
	if shape and shape.shape is RectangleShape2D:
		shape.set_meta("true_original_size", shape.shape.size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	setup_card_3d_shader(sprite)
	sprite.set_meta("front_texture", attack_texture)
	sprite.texture = attack_texture
	sprite.set_meta("back_texture", heal_texture)
	
	fit_texture_to_card(sprite, 50.0)
	
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	# Эффект яда
	card.set_meta("front_effect_type", CardEffect.POISON)
	card.set_meta("front_effect_value", 5)  # 5 стаков яда
	
	card.set_meta("back_effect_type", CardEffect.HEAL)
	card.set_meta("back_effect_value", 12)
	
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
	
	card.add_child(value_label)
	update_card_value_label(card)
	
	card.connect("mouse_entered", Callable(self, "_on_card_hover_entered").bind(card))
	card.connect("mouse_exited", Callable(self, "_on_card_hover_exited").bind(card))
	card.connect("input_event", Callable(self, "_on_card_input").bind(card))
	
	card.visible = false
	return card

# 2. Карта "Регенерация" - дает regen игроку
func create_regen_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)

	var sprite := card.get_node("Sprite2D")
	var shape := card.get_node("CollisionShape2D") 
	if shape and shape.shape is RectangleShape2D:
		shape.set_meta("true_original_size", shape.shape.size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	setup_card_3d_shader(sprite)	
	sprite.set_meta("front_texture", heal_texture)
	sprite.texture = heal_texture
	sprite.set_meta("back_texture", defense_texture)
	
	fit_texture_to_card(sprite, 50.0)
	
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	# Эффект регенерации
	card.set_meta("front_effect_type", CardEffect.REGEN)  
	card.set_meta("front_effect_value", 3)
	
	card.set_meta("back_effect_type", CardEffect.DEFENSE)
	card.set_meta("back_effect_value", 15)
	
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
	
	card.add_child(value_label)
	update_card_value_label(card)
	
	card.connect("mouse_entered", Callable(self, "_on_card_hover_entered").bind(card))
	card.connect("mouse_exited", Callable(self, "_on_card_hover_exited").bind(card))
	card.connect("input_event", Callable(self, "_on_card_input").bind(card))
	
	card.visible = false
	return card

# 3. Карта "Ослабление" - накладывает weak на врага
func create_weak_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	var shape := card.get_node("CollisionShape2D") 
	if shape and shape.shape is RectangleShape2D:
		shape.set_meta("true_original_size", shape.shape.size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	setup_card_3d_shader(sprite)	
	sprite.set_meta("front_texture", defense_texture)
	sprite.texture = defense_texture
	sprite.set_meta("back_texture", attack_texture)
	
	fit_texture_to_card(sprite, 50.0)
	
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	# ффект ослабления
	card.set_meta("front_effect_type", CardEffect.WEAK)
	card.set_meta("front_effect_value", 2)  # 2 стака ослабления
	
	card.set_meta("back_effect_type", CardEffect.ATTACK)
	card.set_meta("back_effect_value", 20)
	
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
	
	card.add_child(value_label)
	update_card_value_label(card)
	
	card.connect("mouse_entered", Callable(self, "_on_card_hover_entered").bind(card))
	card.connect("mouse_exited", Callable(self, "_on_card_hover_exited").bind(card))
	card.connect("input_event", Callable(self, "_on_card_input").bind(card))
	
	card.visible = false
	return card


# Создание плавающего текста урона
func create_damage_number(target: Node2D, damage: int, is_heal: bool = false):
	if not target or not is_instance_valid(target):
		return
	
	# Создаем Label для отображения урона
	var damage_label = Label.new()
	damage_label.text = str(damage)
	damage_label.add_theme_font_size_override("font_size", 32)
	
	# Цвет в зависимости от типа
	if is_heal:
		damage_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))  # Зеленый для лечения
	else:
		damage_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Красный для урона
	
	# Обводка для читаемости
	damage_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	damage_label.add_theme_constant_override("outline_size", 25)
	
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	damage_label.size = Vector2(100, 50)
	
	# Позиция - центр спрайта
	var sprite = target.get_node_or_null("Sprite2D")
	if sprite:
		damage_label.global_position = target.global_position - Vector2(50, 25)
	else:
		damage_label.global_position = target.global_position - Vector2(50, 25)
	
	damage_label.z_index = 100
	
	# Добавляем в сцену (не как дочерний элемент цели)
	add_child(damage_label)
	
	# Анимация: движение вниз с исчезновением
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Движение вниз
	tween.tween_property(damage_label, "position:y", damage_label.position.y + 60, 1.0)
	
	# Масштаб (сначала увеличивается, потом уменьшается)
	#tween.tween_property(damage_label, "scale", Vector2(1.3, 1.3), 0.2)
	#tween.chain().tween_property(damage_label, "scale", Vector2(0.8, 0.8), 0.5)
	
	# Исчезновение
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.8).set_delay(0.4)
	
	# Удаляем после завершения анимации
	tween.finished.connect(func(): damage_label.queue_free())

func highlight_all_enemies():
	"""Подсветить всех врагов для выбора цели"""
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			highlight_enemy(enemy)

func reset_all_enemy_highlights():
	"""Сбросить подсветку всех врагов"""
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			reset_enemy_highlight(enemy)

func enemy_summon_ally(summoner: Node2D):
	if not summoner or not is_instance_valid(summoner):
		return
	
	if enemies.size() >= max_enemies:
		print("Cannot summon - max enemies reached!")
		return
	
	print("Enemy summoning ally...")
	
	# Анимация призыва
	var enemy_sprite = summoner.get_node_or_null("Sprite2D")
	if enemy_sprite:
		var tween = create_tween()
		tween.tween_property(enemy_sprite, "modulate", Color(0.5, 1, 0.5), 0.3)
		tween.tween_property(enemy_sprite, "scale", enemy_sprite.scale * 1.2, 0.3)
		tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.3)
		tween.parallel().tween_property(enemy_sprite, "scale", summoner.get_meta("original_scale"), 0.3)
		await tween.finished
	
	# Призывает любого врага
	await spawn_enemies(1)
	
	print("Ally summoned!")
	update_ui()

func create_chain_lightning_card() -> Area2D:
	var card := SubCardScene.instantiate() as Area2D
	$CanvasLayer.add_child(card)
	
	var sprite := card.get_node("Sprite2D")
	var shape := card.get_node("CollisionShape2D") 
	if shape and shape.shape is RectangleShape2D:
		shape.set_meta("true_original_size", shape.shape.size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	setup_card_3d_shader(sprite)	
	sprite.set_meta("front_texture", fireball_texture)
	sprite.texture = fireball_texture
	sprite.set_meta("back_texture", defense_texture)
	
	fit_texture_to_card(sprite, 50.0)
	
	original_card_scales[card] = sprite.scale
	original_card_positions[card] = card.position
	
	# AoE атака
	card.set_meta("front_effect_type", CardEffect.CHAIN_LIGHTNING)  # Новый тип
	card.set_meta("front_effect_value", 8)  # Урон каждому
	
	card.set_meta("back_effect_type", CardEffect.DEFENSE)
	card.set_meta("back_effect_value", 15)
	
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
	
	card.add_child(value_label)
	update_card_value_label(card)
	
	card.connect("mouse_entered", Callable(self, "_on_card_hover_entered").bind(card))
	card.connect("mouse_exited", Callable(self, "_on_card_hover_exited").bind(card))
	card.connect("input_event", Callable(self, "_on_card_input").bind(card))
	
	card.visible = false
	return card

func apply_chain_lightning_effect(effect: Dictionary, cost: int, card: Area2D) -> void:
	energy -= cost
	update_ui()
	
	var base_damage = effect["value"]
	var damage = player_effects.modify_outgoing_damage(base_damage)
	
	print("Chain Lightning hits all enemies for %d damage!" % damage)
	
	# Бьем всех врагов
	for enemy in enemies:
		if not enemy or not is_instance_valid(enemy):
			continue
		
		# Анимация молнии
		var enemy_sprite = enemy.get_node_or_null("Sprite2D")
		if enemy_sprite:
			var tween = create_tween()
			tween.tween_property(enemy_sprite, "modulate", Color(1.5, 1.5, 0.5), 0.1)
			tween.tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.1)
		
		var enemy_effects = enemy_effects_map.get(enemy)
		if enemy_effects:
			var damage_result = enemy_effects.modify_incoming_damage(damage)
			
			if damage_result["damage"] > 0:
				create_damage_number(enemy, damage_result["damage"], false)
			
			enemy.take_damage(damage_result["damage"])
		
		await get_tree().create_timer(0.2).timeout  # Задержка между ударами
	
	discard_card(card)
	add_transformation_progress()
	await check_and_transform()

# Настройка 3D шейдера для карты - дублируем материал!
func setup_card_3d_shader(sprite: Sprite2D):
	if not sprite:
		return
	
	# Если у спрайта уже есть материал - дублируем его
	if sprite.material and sprite.material is ShaderMaterial:
		# КРИТИЧНО: Создаем копию материала
		sprite.material = sprite.material.duplicate()
		
		# Сбрасываем параметры для новой карты
		sprite.material.set_shader_parameter("y_rot", 0.0)
		sprite.material.set_shader_parameter("x_rot", 0.0)
		
		sprite.set_meta("has_unique_material", true)
		print("Duplicated material for card")
	else:
		print("WARNING: Card sprite has no material!")


# Сброс 3D поворота карты
func reset_card_3d_rotation(sprite: Sprite2D):
	if not sprite or not is_instance_valid(sprite):
		return
	
	if not sprite.material or not sprite.material is ShaderMaterial:
		return
	
	# Проверяем что материал валидный
	if not is_instance_valid(sprite.material):
		return
	
	# Проверяем что материал уникален
	if not sprite.get_meta("has_unique_material", false):
		return
	
	var current_x = sprite.material.get_shader_parameter("x_rot")
	var current_y = sprite.material.get_shader_parameter("y_rot")
	
	if current_x == null:
		current_x = 0.0
	if current_y == null:
		current_y = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		func(value): 
			if sprite and is_instance_valid(sprite) and sprite.material and is_instance_valid(sprite.material):
				sprite.material.set_shader_parameter("x_rot", value),
		current_x,
		0.0,
		0.3
	)
	tween.tween_method(
		func(value): 
			if sprite and is_instance_valid(sprite) and sprite.material and is_instance_valid(sprite.material):
				sprite.material.set_shader_parameter("y_rot", value),
		current_y,
		0.0,
		0.3
	)



# Обновление 3D поворота карты на основе позиции мыши
func update_card_3d_rotation(card: Area2D, mouse_pos: Vector2):
	if not card or not is_instance_valid(card):
		return
	
	var sprite = card.get_node("Sprite2D")
	if not sprite or not sprite.material or not sprite.material is ShaderMaterial:
		return
	
	if not sprite.texture:
		return
	
	# Используем позицию верхней карты стака для расчёта
	var reference_card = card
	var stack_id = get_card_stack_id(card)
	if card_stacks.has(stack_id):
		var stack = card_stacks[stack_id]
		if stack.size() > 0:
			reference_card = stack[-1]  # Берём верхнюю карту как референс
	
	var card_size = sprite.texture.get_size() * sprite.scale
	var card_pos = reference_card.global_position  
	
	var local_mouse = mouse_pos - card_pos
	
	var lerp_val_x = clamp(local_mouse.x / card_size.x, 0.0, 1.0)
	var lerp_val_y = clamp(local_mouse.y / card_size.y, 0.0, 1.0)
	
	var rot_x = lerp(-angle_x_max, angle_x_max, lerp_val_x)
	var rot_y = lerp(angle_y_max, -angle_y_max, lerp_val_y)
	
	var current_x = sprite.material.get_shader_parameter("x_rot")
	var current_y = sprite.material.get_shader_parameter("y_rot")
	
	var new_x = lerp(current_x, rot_y, 0.3)
	var new_y = lerp(current_y, rot_x, 0.3)
	
	sprite.material.set_shader_parameter("x_rot", new_x)
	sprite.material.set_shader_parameter("y_rot", new_y)
	
# Сброс 3D поворота у всех карт
func reset_all_cards_3d_rotation():
	for card in sub_cards:
		if card and is_instance_valid(card):
			card.set_meta("track_mouse", false)
			var sprite = card.get_node_or_null("Sprite2D")
			if sprite:
				reset_card_3d_rotation(sprite)
# Обновление 3D поворота главной карты
func update_main_card_3d_rotation(mouse_pos: Vector2):
	if not main_card_sprite or not main_card_sprite.material or not main_card_sprite.material is ShaderMaterial:
		return
	
	if not main_card_sprite.texture:
		return
	
	var card_size = main_card_sprite.texture.get_size() * main_card_sprite.scale
	var card_pos = Main_card_area.global_position
	
	var local_mouse = mouse_pos - card_pos
	
	var lerp_val_x = clamp(local_mouse.x / card_size.x, 0.0, 1.0)
	var lerp_val_y = clamp(local_mouse.y / card_size.y, 0.0, 1.0)
	
	var rot_x = lerp(-angle_x_max, angle_x_max, lerp_val_x)
	var rot_y = lerp(angle_y_max, -angle_y_max, lerp_val_y)
	
	var current_x = main_card_sprite.material.get_shader_parameter("x_rot")
	var current_y = main_card_sprite.material.get_shader_parameter("y_rot")
	
	if current_x == null:
		current_x = 0.0
	if current_y == null:
		current_y = 0.0
	
	var new_x = lerp(current_x, rot_y, 0.3)
	var new_y = lerp(current_y, rot_x, 0.3)
	
	main_card_sprite.material.set_shader_parameter("x_rot", new_x)
	main_card_sprite.material.set_shader_parameter("y_rot", new_y)


# Обновление 3D поворота врага
func update_enemy_3d_rotation(enemy: Node2D, mouse_pos: Vector2):
	if not enemy or not is_instance_valid(enemy):
		return
	
	var enemy_sprite = enemy.get_node_or_null("Sprite2D")
	if not enemy_sprite or not is_instance_valid(enemy_sprite):
		return
	
	# ДОБАВЛЕНО: Проверка материала
	if not enemy_sprite.material or not enemy_sprite.material is ShaderMaterial:
		return
	
	if not enemy_sprite.texture:
		return
	
	var enemy_size = enemy_sprite.texture.get_size() * enemy_sprite.scale
	var enemy_pos = enemy.global_position
	
	var local_mouse = mouse_pos - enemy_pos
	
	var lerp_val_x = clamp(local_mouse.x / enemy_size.x, 0.0, 1.0)
	var lerp_val_y = clamp(local_mouse.y / enemy_size.y, 0.0, 1.0)
	
	var rot_x = lerp(-angle_x_max, angle_x_max, lerp_val_x)
	var rot_y = lerp(angle_y_max, -angle_y_max, lerp_val_y)
	
	var current_x = enemy_sprite.material.get_shader_parameter("x_rot")
	var current_y = enemy_sprite.material.get_shader_parameter("y_rot")
	
	if current_x == null:
		current_x = 0.0
	if current_y == null:
		current_y = 0.0
	
	var new_x = lerp(current_x, rot_y, 0.3)
	var new_y = lerp(current_y, rot_x, 0.3)
	
	enemy_sprite.material.set_shader_parameter("x_rot", new_x)
	enemy_sprite.material.set_shader_parameter("y_rot", new_y)

# Обработка наведения на саммона
func _on_summon_mouse_entered(summon: Node2D):
	if summon and is_instance_valid(summon):
		var summon_sprite = summon.get_node_or_null("Sprite2D")
		if summon_sprite:
			var tween = create_tween()
			tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
			tween.tween_property(summon_sprite, "scale", summon_sprite.scale * 1.1, 0.5)
			
			summon.set_meta("track_mouse", true)


func _on_summon_mouse_exited(summon: Node2D):
	if summon and is_instance_valid(summon):
		var summon_sprite = summon.get_node_or_null("Sprite2D")
		if summon_sprite:
			var tween = create_tween()
			tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_parallel(true)
			tween.tween_property(summon_sprite, "scale", Vector2(3, 3), 0.15)
			
			summon.set_meta("track_mouse", false)
			reset_card_3d_rotation(summon_sprite)


# Обновление 3D поворота саммона
func update_summon_3d_rotation(summon: Node2D, mouse_pos: Vector2):
	if not summon or not is_instance_valid(summon):
		return
	
	var summon_sprite = summon.get_node_or_null("Sprite2D")
	if not summon_sprite or not summon_sprite.material or not summon_sprite.material is ShaderMaterial:
		return
	
	if not summon_sprite.texture:
		return
	
	var summon_size = summon_sprite.texture.get_size() * summon_sprite.scale
	var summon_pos = summon.global_position
	
	var local_mouse = mouse_pos - summon_pos
	
	var lerp_val_x = clamp(local_mouse.x / summon_size.x, 0.0, 1.0)
	var lerp_val_y = clamp(local_mouse.y / summon_size.y, 0.0, 1.0)
	
	var rot_x = lerp(-angle_x_max, angle_x_max, lerp_val_x)
	var rot_y = lerp(angle_y_max, -angle_y_max, lerp_val_y)
	
	var current_x = summon_sprite.material.get_shader_parameter("x_rot")
	var current_y = summon_sprite.material.get_shader_parameter("y_rot")
	
	if current_x == null:
		current_x = 0.0
	if current_y == null:
		current_y = 0.0
	
	var new_x = lerp(current_x, rot_y, 0.3)
	var new_y = lerp(current_y, rot_x, 0.3)
	
	summon_sprite.material.set_shader_parameter("x_rot", new_x)
	summon_sprite.material.set_shader_parameter("y_rot", new_y)

# Автоматическая настройка веера в зависимости от количества карт
func auto_adjust_fan():
	var card_count = sub_cards.size()
	
	if card_count <= 3:
		fan_spread_angle = 20.0
		fan_horizontal_spread = 1.8
		fan_curve_height = 30.0
	elif card_count <= 5:
		fan_spread_angle = 25.0
		fan_horizontal_spread = 1.5
		fan_curve_height = 40.0
	elif card_count <= 7:
		fan_spread_angle = 30.0
		fan_horizontal_spread = 1.3
		fan_curve_height = 50.0
	elif card_count <= 12:
		# Для большого количества карт
		fan_spread_angle = 35.0
		fan_horizontal_spread = 1.2
		fan_curve_height = 60.0
	else:
		fan_spread_angle = 30.0
		fan_horizontal_spread = 0.7
		fan_curve_height = 50.0


func reward_player(gold: int):
	player_gold += gold
	print("Player earned %d gold! Total: %d" % [gold, player_gold])
	update_gold_display()
	
	# Визуальный эффект получения золота
	var tween = create_tween()
	tween.tween_property(main_card_sprite, "modulate", Color(1, 1, 0.5), 0.2)
	tween.tween_property(main_card_sprite, "modulate", Color(1, 1, 1), 0.2)
# Обновление отображения золота
func update_gold_display():
	if gold_label:
		gold_label.text = "Gold: %d" % player_gold

# Получить уникальный ID карты для стакирования
func get_card_stack_id(card: Area2D) -> String:
	var front_effect = card.get_meta("front_effect_type", -1)
	var back_effect = card.get_meta("back_effect_type", -1)
	var front_value = card.get_meta("front_effect_value", 0)
	var back_value = card.get_meta("back_effect_value", 0)
	var cost = card.get_meta("cost", 0)
	var is_flipped = card.get_meta("flipped", false)
	
	return "%d_%d_%d_%d_%d_%s" % [front_effect, back_effect, front_value, back_value, cost, is_flipped]

# Организовать карты в стаки
func organize_card_stacks():
	card_stacks.clear()
	
	if not enable_card_stacking:
		return
	
	for card in sub_cards:
		if not is_instance_valid(card):
			continue
		
		var stack_id = get_card_stack_id(card)
		
		if not card_stacks.has(stack_id):
			card_stacks[stack_id] = []
		
		card_stacks[stack_id].append(card)
	
	# Сортируем стаки по количеству карт (больше карт = приоритетнее)
	var sorted_stacks = []
	for stack_id in card_stacks.keys():
		sorted_stacks.append({
			"id": stack_id,
			"cards": card_stacks[stack_id],
			"count": card_stacks[stack_id].size()
		})
	
	sorted_stacks.sort_custom(func(a, b): return a["count"] > b["count"])
	
	return sorted_stacks


# Получить видимые карты из стаков (только верхние)
func get_visible_cards_from_stacks() -> Array:
	if not enable_card_stacking:
		return sub_cards
	
	var sorted_stacks = organize_card_stacks()
	var visible_cards = []
	
	for stack_data in sorted_stacks:
		if stack_data["cards"].size() > 0:
			# Берем последнюю карту как видимую
			visible_cards.append(stack_data["cards"][-1])
	
	return visible_cards

# Обновить отображение количества карт в стаке
#func update_card_stack_display(card: Area2D):
	#if not enable_card_stacking:
		#return
	#
	#var stack_id = get_card_stack_id(card)
	#if not card_stacks.has(stack_id):
		#return
	#
	#var stack = card_stacks[stack_id]
	#var stack_size = stack.size()
	#
	## ИСПРАВЛЕНО: Показываем счетчик ТОЛЬКО на верхней карте стака
	#var is_top_card = (stack[-1] == card)
	#
	#var count_label = card.get_node_or_null("StackCountLabel")
	#
	#if is_top_card and stack_size > 1:
		#if not count_label:
			#count_label = Label.new()
			#count_label.name = "StackCountLabel"
			#count_label.position = Vector2(70, 5)  # Правый верхний угол
			#count_label.add_theme_font_size_override("font_size", 20)
			#count_label.add_theme_color_override("font_color", Color(1, 1, 0))
			#count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			#count_label.add_theme_constant_override("outline_size", 4)
			#count_label.z_index = 100
			#count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			#card.add_child(count_label)
		#
		#count_label.text = "x%d" % stack_size
		#count_label.visible = true
	#elif count_label:
		#count_label.visible = false

# Переключить режим стакирования
func toggle_card_stacking():
	enable_card_stacking = !enable_card_stacking
	print("Card stacking: ", enable_card_stacking)
	layout_subcards()

func _on_tooltip_hide_timeout():
	if not hovered_card:
		hide_card_tooltip()	

func request_layout():
	if not layout_timer:
		layout_subcards()
		return
	
	layout_pending = true
	if layout_timer.is_stopped():
		layout_timer.start()


func _execute_layout():
	if layout_pending:
		layout_pending = false
		layout_subcards()

# Обновить индикатор количества карт (маленькие точки внизу)
func update_stack_indicator(card: Area2D):
	if not enable_card_stacking:
		return
	
	var stack_id = get_card_stack_id(card)
	if not card_stacks.has(stack_id):
		return
	
	var stack = card_stacks[stack_id]
	var is_top_card = (stack[-1] == card)
	
	# Удаляем индикатор у ВСЕХ карт в стаке сначала
	for stack_card in stack:
		if not is_instance_valid(stack_card):
			continue
		
		var old_indicator = stack_card.get_node_or_null("StackIndicator")
		if old_indicator:
			old_indicator.queue_free()
	
	# Показываем индикатор только верхней карте
	if not is_top_card:
		return
	
	var stack_size = stack.size()
	
	if stack_size <= 1:
		return
	
	# Создаем контейнер для точек ТОЛЬКО на верхней карте
	var indicator = Control.new()
	indicator.name = "StackIndicator"
	indicator.position = Vector2(35, 85)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.z_index = 100
	card.add_child(indicator)
	
	# Рисуем точки (максимум 6)
	var dots_to_show = min(stack_size, max_visible_cards_in_stack)
	var dot_size = 4
	var dot_spacing = 8
	var total_width = (dots_to_show - 1) * dot_spacing
	var start_x = -total_width / 2
	
	for i in range(dots_to_show):
		var dot = ColorRect.new()
		dot.size = Vector2(dot_size, dot_size)
		dot.position = Vector2(start_x + i * dot_spacing, 0)
		dot.color = Color(1, 1, 1, 0.8)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		indicator.add_child(dot)


func push_adjacent_cards(hovered: Area2D):
	"""Оттолкнуть соседние карты от наведенной - СИЛЬНОЕ разталкивание"""
	var visible_cards = get_visible_cards_from_stacks()
	var hovered_index = visible_cards.find(hovered)
	
	if hovered_index == -1:
		return
	
	var card_count = visible_cards.size()
	
	# Базовая сила разталкивания остается высокой
	var base_push = card_push_distance
	
	# Отталкиваем ВСЕ карты слева и справа к краям
	for i in range(visible_cards.size()):
		var card = visible_cards[i]
		if not is_instance_valid(card) or card == hovered:
			card.set_meta("push_offset", Vector2.ZERO)
			continue
		
		# Если карта слева от наведенной - толкаем ВЛЕВО
		if i < hovered_index:
			var distance = hovered_index - i
			var push_strength = base_push / sqrt(distance)  # Квадратный корень для плавного затухания
			card.set_meta("push_offset", Vector2(-push_strength, 0))
		
		# Если карта справа от наведенной - толкаем ВПРАВО
		elif i > hovered_index:
			var distance = i - hovered_index
			var push_strength = base_push / sqrt(distance)
			card.set_meta("push_offset", Vector2(push_strength, 0))

func reset_card_push():
	"""Сбросить разталкивание всех карт"""
	for card in sub_cards:
		if is_instance_valid(card):
			card.set_meta("push_offset", Vector2.ZERO)

# Обновить интерактивность всех карт в стаках
func update_all_cards_interactivity():
	"""Обновляет input_pickable для всех карт - только верхние карты стаков интерактивны"""
	
	# Сначала отключаем интерактивность у ВСЕХ карт
	for card in sub_cards:
		if not is_instance_valid(card):
			continue
		card.input_pickable = false
		card.monitorable = false
		card.monitoring = false
		card.set_meta("temp_input_disabled", false)
	
	# Затем включаем ТОЛЬКО у верхних карт стаков
	for stack_id in card_stacks.keys():
		var stack = card_stacks[stack_id]
		if stack.size() > 0:
			var top_card = stack[-1]
			if is_instance_valid(top_card) and top_card in sub_cards:
				top_card.input_pickable = true
				top_card.monitorable = true
				top_card.monitoring = true
				
				# Обновляем индикатор стака
				update_stack_indicator(top_card)
