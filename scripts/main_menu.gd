extends Control

@onready var _start_button: Button = $Button

func _ready() -> void:
	_start_button.pressed.connect(_on_start_button_pressed)

func _on_start_button_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/game.tscn")
	if error != OK:
		push_error("Failed to load game scene. Error code: %d" % error)
