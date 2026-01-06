extends Node2D

@onready var title = $RichTextLabel
@onready var black_overlay = $BlackOverlay
@onready var play_button = $Play

var time := 0.0
var pivot := Vector2.ZERO

func _ready():
	# Включаем BBCode и текст
	title.bbcode_enabled = true
	title.text = "[color=gold][wave amp=25 freq=2]PUNCHAMAGE[/wave][/color]"

	# Центрируем текст относительно экрана
	pivot = title.position  # точка вокруг которой будет вращение
	# Например, выставь title.position = экран.center через код или инспектор


func _process(delta):
	# Покачивание влево-вправо
	time += delta
	title.rotation_degrees = sin(time * 2.0) * 5.0  # ±5° вокруг центра (title.position)

func _on_play_pressed():
	var tween = create_tween()
	tween.tween_property(black_overlay, "color:a", 1.0, 1.2)
	await tween.finished
	get_tree().change_scene_to_file("res://Gaming.tscn")
