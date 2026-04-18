class_name PowerupBase extends RefCounted

enum Category {
	COMMON,
	DUO_ONLY
}

func get_category() -> Category:
	return Category.COMMON

func get_powerup_name() -> String:
	return "BASE POWERUP"

func activate(player: CharacterBody3D) -> void:
	pass
