# FloatingText.gd
extends Node2D

var life_time := 1.0
var velocity := Vector2(0, -50)

@onready var label := $Label

func _ready():
	var tween = create_tween()
	tween.tween_property(self, "position", position + velocity, life_time)
	tween.parallel().tween_property(self, "modulate:a", 0.0, life_time)
	tween.tween_callback(queue_free)

func set_text(text: String):
	label.text = text
