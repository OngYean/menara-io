extends Node
class_name TrollBase

## Reference to the main game scene
var game: Node3D

## Override this to apply the troll effect
func start() -> void:
	pass

## Override this to revert the troll effect
func end() -> void:
	pass

## Override this to provide a user-facing name for the UI
func get_troll_name() -> String:
	return "Abstract Troll"
