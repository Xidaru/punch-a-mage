extends Node

# Типы эффектов
enum EffectType {
	BURN,      # Урон в начале хода, уменьшается вдвое
	STRENGTH,  # Бонус к урону
	VULNERABLE,# Получаемый урон увеличен
	BLOCK,     # Блокирует урон
	POISON,    # Урон в начале хода, уменьшается на 1
	REGEN,     # Восстановление HP в начале хода
	WEAK       # Наносимый урон уменьшен
}

# Данные одного эффекта
class StatusEffect:
	var type: EffectType
	var stacks: int = 0
	var icon: Texture2D
	var color: Color
	var name: String
	
	func _init(effect_type: EffectType, initial_stacks: int = 0):
		type = effect_type
		stacks = initial_stacks
		setup_visuals()
	
	func setup_visuals():
		match type:
			EffectType.BURN:
				name = "Burn"
				color = Color(1, 0.4, 0)
			EffectType.STRENGTH:
				name = "Strength"
				color = Color(1, 0.3, 0.3)
			EffectType.VULNERABLE:
				name = "Vulnerable"
				color = Color(0.8, 0.4, 1)
			EffectType.BLOCK:
				name = "Block"
				color = Color(0.3, 0.5, 1)
			EffectType.POISON:
				name = "Poison"
				color = Color(0.4, 1, 0.4)
			EffectType.REGEN:
				name = "Regen"
				color = Color(0.2, 1, 0.2)
			EffectType.WEAK:
				name = "Weak"
				color = Color(0.6, 0.6, 0.6)
	
	func get_description() -> String:
		match type:
			EffectType.BURN:
				return "Takes %d damage at start of turn, then halves" % stacks
			EffectType.STRENGTH:
				return "Attacks deal +%d damage" % stacks
			EffectType.VULNERABLE:
				return "Takes +50%% damage per stack (%d)" % stacks
			EffectType.BLOCK:
				return "Blocks %d damage" % stacks
			EffectType.POISON:
				return "Takes %d damage at start of turn, reduces by 1" % stacks
			EffectType.REGEN:
				return "Heals %d HP at start of turn" % stacks
			EffectType.WEAK:
				return "Deals -25%% damage per stack (%d)" % stacks
		return ""

# Контейнер эффектов для одной сущности (игрок/враг)
class EffectContainer:
	var effects: Dictionary = {}  # EffectType -> StatusEffect
	var owner_node: Node
	var display_container: HBoxContainer
	var damage_callback: Callable 
	
	func _init(owner: Node):
		owner_node = owner
	# НОВОЕ: Установка callback для показа урона
	func set_damage_callback(callback: Callable):
		damage_callback = callback
	
	# НОВОЕ: Показать число урона/лечения
	func show_damage_number(amount: int, damage_type: String = "damage"):
		if damage_callback and damage_callback.is_valid():
			damage_callback.call(amount, damage_type)
	
	func add_effect(effect_type: EffectType, amount: int):
		if not effects.has(effect_type):
			effects[effect_type] = StatusEffect.new(effect_type, 0)
		
		effects[effect_type].stacks += amount
		
		if effects[effect_type].stacks <= 0:
			effects.erase(effect_type)
	
	func set_effect(effect_type: EffectType, amount: int):
		if amount <= 0:
			effects.erase(effect_type)
			return
		
		if not effects.has(effect_type):
			effects[effect_type] = StatusEffect.new(effect_type, 0)
		
		effects[effect_type].stacks = amount
	
	func get_effect(effect_type: EffectType) -> int:
		if effects.has(effect_type):
			return effects[effect_type].stacks
		return 0
	
	func has_effect(effect_type: EffectType) -> bool:
		return effects.has(effect_type) and effects[effect_type].stacks > 0
	
	func reduce_effect(effect_type: EffectType, amount: int = 1):
		if effects.has(effect_type):
			effects[effect_type].stacks -= amount
			if effects[effect_type].stacks <= 0:
				effects.erase(effect_type)
	
	func clear_effect(effect_type: EffectType):
		effects.erase(effect_type)
	
	func clear_all():
		effects.clear()
	
	# Применение эффектов в начале хода
	func apply_start_of_turn_effects() -> Dictionary:
		
		if not owner_node or not is_instance_valid(owner_node):
			return {"damage": 0, "heal": 0, "messages": []}
		var results = {
			"damage": 0,
			"heal": 0,
			"messages": []
		}
		
		# Burn
		if has_effect(EffectType.BURN):
			var burn = get_effect(EffectType.BURN)
			results["damage"] += burn
			results["messages"].append("Burn dealt %d damage" % burn)
			show_damage_number(burn, "burn")  
			set_effect(EffectType.BURN, ceili(burn / 2.0))
		
		# Poison
		if has_effect(EffectType.POISON):
			var poison = get_effect(EffectType.POISON)
			results["damage"] += poison
			results["messages"].append("Poison dealt %d damage" % poison)
			show_damage_number(poison, "poison")  
			reduce_effect(EffectType.POISON, 1)
		
		# Regen
		if has_effect(EffectType.REGEN):
			var regen = get_effect(EffectType.REGEN)
			results["heal"] += regen
			results["messages"].append("Regen healed %d HP" % regen)
			show_damage_number(regen, "heal")  
		
		return results
	
	# Модификация урона с учетом эффектов
	func modify_outgoing_damage(base_damage: int) -> int:
		var damage = base_damage
		
		if has_effect(EffectType.STRENGTH):
			damage += get_effect(EffectType.STRENGTH)
		
		if has_effect(EffectType.WEAK):
			var weak_stacks = get_effect(EffectType.WEAK)
			damage = int(damage * (1.0 - 0.25 * weak_stacks))
		
		return max(0, damage)
	
	# Модификация получаемого урона с учетом эффектов
	func modify_incoming_damage(base_damage: int) -> Dictionary:
		var damage = base_damage
		var blocked = 0
		
		if has_effect(EffectType.VULNERABLE):
			var vulnerable_stacks = get_effect(EffectType.VULNERABLE)
			damage = int(damage * (1.0 + 0.5 * vulnerable_stacks))
		
		if has_effect(EffectType.BLOCK):
			var block = get_effect(EffectType.BLOCK)
			blocked = min(block, damage)
			damage -= blocked
			set_effect(EffectType.BLOCK, block - blocked)
			
			#Показываем заблокированный урон
			if blocked > 0:
				show_damage_number(blocked, "blocked")
		
		#Показываем финальный урон
		if damage > 0:
			show_damage_number(damage, "damage")
		
		return {
			"damage": max(0, damage),
			"blocked": blocked
		}
	

	
	# Уменьшение временных эффектов в конце хода
	func reduce_temporary_effects():
		if has_effect(EffectType.VULNERABLE):
			reduce_effect(EffectType.VULNERABLE, 1)
		
		if has_effect(EffectType.WEAK):
			reduce_effect(EffectType.WEAK, 1)
	
	

	# Создание визуального отображения эффектов
	func create_display(parent: Node, position: Vector2 = Vector2.ZERO, auto_position: bool = false, below: bool = false):
		if display_container:
			display_container.queue_free()

		display_container = HBoxContainer.new()
		display_container.add_theme_constant_override("separation", 5)
		display_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		display_container.set_meta("below", below)  # НОВОЕ: Сохраняем параметр


		#Автоматическое позиционирование
		if auto_position:
			# Ищем Sprite2D в родителе
			var sprite = parent.get_node_or_null("Sprite2D")
			if sprite and sprite.texture:
				var sprite_height = sprite.texture.get_height() * sprite.scale.y
				#Используем параметр below
				var offset_y = sprite_height / 2 + 30 if below else -sprite_height / 2 - 70
				display_container.position = Vector2(-60, offset_y)
				print("Effect display positioned at: ", display_container.position, " (below: ", below, ", sprite_height: ", sprite_height, ")")
			else:
				print("WARNING: No sprite found in ", parent.name)
				display_container.position = position
				print("Using manual position: ", position)
		else:
			display_container.position = position

	#z_index чтобы было видно поверх всего
		display_container.z_index = 10

		parent.add_child(display_container)
		var debug_rect = ColorRect.new()
		debug_rect.size = Vector2(120, 40)
		debug_rect.color = Color(1, 0, 0, 0.3)  # Полупрозрачный красный
		display_container.add_child(debug_rect)
		print("Effect display created and added to: ", parent.name)
	# Обновление визуального отображения
	
	func update_display():
		if not display_container:
			return
		
		# Очищаем старые элементы
		for child in display_container.get_children():
			child.queue_free()
		
		# Создаем новые
		for effect_type in effects:
			var effect = effects[effect_type]
			create_effect_icon(effect)
		
		# Обновляем позицию если используется автопозиционирование
		update_position()
	
	# Обновление позиции эффектов
	func update_position():
		if not display_container or not owner_node:
			return
		
		var sprite = owner_node.get_node_or_null("Sprite2D")
		if sprite and sprite.texture:
			var sprite_height = sprite.texture.get_height() * sprite.scale.y
			# Определяем направление из метаданных контейнера
			var is_below = display_container.get_meta("below", false)
			var offset_y = sprite_height / 2 + 30 if is_below else -sprite_height / 2 - 70
			display_container.position = Vector2(-60, offset_y)
	
	func create_effect_icon(effect: StatusEffect):
		var container = PanelContainer.new()
		
		# Стиль иконки
		var style = StyleBoxFlat.new()
		style.bg_color = Color(effect.color.r * 0.3, effect.color.g * 0.3, effect.color.b * 0.3, 0.9)
		style.border_color = effect.color
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		container.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		container.add_child(vbox)
		
		# Название эффекта
		var name_label = Label.new()
		name_label.text = effect.name
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", effect.color)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)
		
		# Количество стаков
		var value_label = Label.new()
		value_label.text = str(effect.stacks)
		value_label.add_theme_font_size_override("font_size", 14)
		value_label.add_theme_color_override("font_color", Color.WHITE)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(value_label)
		
		display_container.add_child(container)
		
		# Tooltip
		container.mouse_entered.connect(func():
			show_effect_tooltip(effect, container.global_position)
		)
		container.mouse_exited.connect(hide_effect_tooltip)
	
	var tooltip: PanelContainer
	var tooltip_label: Label
	
	func show_effect_tooltip(effect: StatusEffect, pos: Vector2):
		if not tooltip:
			create_tooltip()
		
		tooltip_label.text = effect.get_description()
		tooltip.global_position = pos + Vector2(0, -60)
		tooltip.visible = true
	
	func hide_effect_tooltip():
		if tooltip:
			tooltip.visible = false
	
	func create_tooltip():
		tooltip = PanelContainer.new()
		tooltip.visible = false
		tooltip.z_index = 100
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
		style.border_color = Color(0.8, 0.8, 0.9, 1)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 5
		tooltip.add_theme_stylebox_override("panel", style)
		
		tooltip_label = Label.new()
		tooltip_label.add_theme_font_size_override("font_size", 12)
		tooltip_label.add_theme_color_override("font_color", Color.WHITE)
		tooltip.add_child(tooltip_label)
		
		if owner_node:
			owner_node.add_child(tooltip)
