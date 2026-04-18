extends Control

@onready var _singleplayer_button: Button = $SingleplayerButton
@onready var _duo_button: Button = $DuoButton
@onready var _tutorial_button: Button = $TutorialButton

func _ready() -> void:
	_singleplayer_button.pressed.connect(_on_singleplayer_pressed)
	_duo_button.pressed.connect(_on_duo_pressed)
	_tutorial_button.pressed.connect(_on_tutorial_pressed)

func _on_tutorial_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")

func _on_singleplayer_pressed() -> void:
	get_node("/root/Global").game_mode = "singleplayer"
	_start_game()

func _on_duo_pressed() -> void:
	get_node("/root/Global").game_mode = "duo"
	_start_game()

func _start_game() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/game.tscn")
	if error != OK:
		push_error("Failed to load game scene. Error code: %d" % error)
