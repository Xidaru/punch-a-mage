extends Node
class_name EnemyManager

# Словарь с данными врагов
var enemies_data = {
	"Ravens": {
		"hp": 200,
		"attack_damage": 30,
		"reward_gold": 150,
		"texture": "res://Ravens.png",
		"actions": [
			{"type": 0, "weight": 50},  # 0 = ATTACK_PLAYER
			{"type": 1, "weight": 20},  # 1 = ATTACK_ALL
			{"type": 2, "weight": 30}   # 2 = DEFEND 
		]
	},
	"Skeleton": {
		"hp": 40,
		"attack_damage": 12,
		"reward_gold": 20,
		"texture": "res://Skeleton.png",
		"actions": [
			{"type": 0, "weight": 70},
			{"type": 1, "weight": 10},
			{"type": 3, "weight": 20}
		]
	},
	"Testo": {
		"hp": 100,
		"attack_damage": 20,
		"reward_gold": 40,
		"texture": "res://Enemy.png",
		"actions": [
			{"type": 0, "weight": 50},
			{"type": 1, "weight": 30},
			{"type": 2, "weight": 20}
		]
	}
}

# Получить данные врага по имени
func get_enemy(enemy_name: String) -> Dictionary:
	if enemies_data.has(enemy_name):
		return enemies_data[enemy_name].duplicate(true)
	else:
		return {
			"hp": 50,
			"attack_damage": 15,
			"reward_gold": 25,
			"texture": "res://enemy.png",
			"actions": [
				{"type": 0, "weight": 100}
			]
		}

# Добавить нового врага
func add_enemy(enemy_name: String, hp: int, attack_damage: int, reward_gold: int, texture_path: String, actions: Array = []):
	if actions.is_empty():
		actions = [{"type": 0, "weight": 100}]
	
	enemies_data[enemy_name] = {
		"hp": hp,
		"attack_damage": attack_damage,
		"reward_gold": reward_gold,
		"texture": texture_path,
		"actions": actions
	}

# Получить все имена врагов
func get_all_enemies() -> Array:
	return enemies_data.keys()

# Получить случайного врага
func get_random_enemy() -> Dictionary:
	var enemies = enemies_data.keys()
	if enemies.is_empty():
		return get_enemy("Unknown")
	var random_enemy_name = enemies[randi() % enemies.size()]
	return get_enemy(random_enemy_name)
