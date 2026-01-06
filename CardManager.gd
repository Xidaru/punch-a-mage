extends Node

# Предзагруженные сцены карт
var card_scenes = {}

func _ready():
	# Загрузить все готовые карты
	card_scenes["CustomcardTest"] = preload("res://CustomcardTest.tscn")
	# Добавить другие карты по необходимости

func get_card(card_name: String) -> Area2D:
	if card_name in card_scenes:
		return card_scenes[card_name].instantiate()
	else:
		push_error("Card not found: " + card_name)
		return null
