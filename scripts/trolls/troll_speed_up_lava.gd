extends TrollBase

var _original_speed: float

func start() -> void:
	_original_speed = game.lava_rise_speed
	game.lava_rise_speed *= 2.0

func end() -> void:
	game.lava_rise_speed = _original_speed

func get_troll_name() -> String:
	return "FAST LAVA!"
