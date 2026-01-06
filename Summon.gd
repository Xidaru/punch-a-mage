extends Area2D

var max_hp := 30
var current_hp := 30
var attack_damage := 10
var summon_name := "Ally"

@onready var hp_label := $HPLabel
@onready var sprite := $Sprite2D

func _ready():
	update_ui()

func take_damage(amount: int):
	current_hp = max(current_hp - amount, 0)
	update_ui()
	
	if current_hp <= 0:
		die()

func update_ui():
	hp_label.text = "%s\nHP: %d/%d\nATK: %d" % [summon_name, current_hp, max_hp, attack_damage]

func attack_enemy(enemy: Node2D) -> int:
	return attack_damage

func die():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(sprite, "scale", Vector2(0.01, 0.01), 0.3)
	tween.tween_callback(queue_free)
