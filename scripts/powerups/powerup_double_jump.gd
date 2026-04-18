extends PowerupBase

func get_powerup_name() -> String:
	return "DOUBLE JUMP"

func get_category() -> Category:
	return Category.COMMON

func get_icon() -> Texture2D:
	return preload("res://assets/powerup_doublejump.png")
