extends PowerupBase

func get_category() -> Category:
	return Category.COMMON

func get_powerup_name() -> String:
	return "FLY"

func get_icon() -> Texture2D:
	return preload("res://assets/powerup_fly.png")
