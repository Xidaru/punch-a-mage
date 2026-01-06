# CustomCard.gd
extends Area2D

@export var front_texture: Texture2D
@export var back_texture: Texture2D
@export var front_effect_type: int  # Используйте enum из главного скрипта
@export var front_effect_value: int
@export var back_effect_type: int
@export var back_effect_value: int
@export var energy_cost: int = 1

func _ready():
	# Установите метаданные для карты
	set_meta("front_texture", front_texture)
	set_meta("back_texture", back_texture)
	set_meta("front_effect_type", front_effect_type)
	set_meta("front_effect_value", front_effect_value)
	set_meta("back_effect_type", back_effect_type)
	set_meta("back_effect_value", back_effect_value)
	set_meta("cost", energy_cost)
	set_meta("flipped", false)
	
	# Установите начальную текстуруcreate_specific_cards()  
	$Sprite2D.texture = front_texture
	var shape := get_node("CollisionShape2D")  # ✅ Получаем коллизию
	
	# ✅ СОХРАНЯЕМ ОРИГИНАЛЬНЫЙ РАЗМЕР КОЛЛИЗИИ СРАЗУ
	if shape and shape.shape is RectangleShape2D:
		shape.set_meta("true_original_size", shape.shape.size)
	# Настройте label для отображения значения
	update_value_label()

func update_value_label():
	var value_label = $ValueLabel
	if value_label:
		if not get_meta("flipped"):
			value_label.text = str(get_meta("front_effect_value"))
		else:
			value_label.text = str(get_meta("back_effect_value"))
