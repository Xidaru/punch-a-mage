extends Area2D

enum EnemyAction { ATTACK_PLAYER, ATTACK_ALL, DEFEND }

signal enemy_died(reward_gold: int)

var max_hp := 100
var current_hp := 100
var attack_damage := 20
var block := 0
var vulnerable := 0  # НОВОЕ: Стаки уязвимости
var possible_actions := []
var next_action = null

@onready var hp_label := $EnemyHPLabel
@onready var sprite := $Sprite2D

var status_effects: Dictionary = {
	"Vulnerable": 0,
	"Burn": 0,
	# Здесь будут добавляться все эффекты врага
}

func take_damage(amount: int):
	var actual_damage = amount
	
	# НОВОЕ: Применяем уязвимость (+50% урона за стак)
	if vulnerable > 0:
		var vulnerability_bonus = int(amount * 0.5 * vulnerable)
		actual_damage += vulnerability_bonus
		print("Vulnerability! +%d damage (stacks: %d)" % [vulnerability_bonus, vulnerable])
	
	# Учитываем блок
	if block > 0:
		var blocked = min(block, actual_damage)
		actual_damage -= blocked
		block -= blocked
		print("Enemy blocked %d damage, %d block remaining" % [blocked, block])
	
	current_hp = max(current_hp - actual_damage, 0)
	update_ui()
	
	if current_hp <= 0:
		die()

func update_ui():
	var status_text = ""
	if block > 0:
		status_text += "🛡 %d " % block
	if vulnerable > 0:
		status_text += "💔 %d " % vulnerable
	
	if status_text != "":
		hp_label.text = "HP: %d/%d\n%s" % [current_hp, max_hp, status_text]
	else:
		hp_label.text = "HP: %d/%d" % [current_hp, max_hp]

func die():
	var reward = get_meta("reward_gold", 25)
	enemy_died.emit(reward)
	
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(sprite, "scale", Vector2(0.01, 0.01), 0.3)
	tween.tween_callback(queue_free)

func choose_next_action():
	if possible_actions.is_empty():
		return 0
	
	var total_weight = 0
	for action in possible_actions:
		total_weight += action["weight"]
	
	var random_value = randi() % total_weight
	var current_weight = 0
	
	for action in possible_actions:
		current_weight += action["weight"]
		if random_value < current_weight:
			next_action = action["type"]
			return action["type"]
	
	return 0

# НОВОЕ: Уменьшение уязвимости в конце хода
func reduce_vulnerable():
	if vulnerable > 0:
		vulnerable = max(vulnerable - 1, 0)
		update_ui()
