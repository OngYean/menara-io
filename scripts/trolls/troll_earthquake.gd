extends TrollBase

func start() -> void:
	get_node("/root/Global").earthquake_active = true
	game.camera_shake_intensity = 0.8

func end() -> void:
	get_node("/root/Global").earthquake_active = false
	game.camera_shake_intensity = 0.0

func get_troll_name() -> String:
	return "EARTHQUAKE"
