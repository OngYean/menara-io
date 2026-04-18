class_name PowerupManager extends RefCounted

static var common_powerups: Array[GDScript] = []
static var duo_powerups: Array[GDScript] = []
static var is_duo_mode: bool = false

static func register_powerup(script: GDScript) -> void:
	var inst = script.new()
	if inst.has_method("get_category"):
		var cat = inst.get_category()
		if cat == PowerupBase.Category.COMMON:
			common_powerups.append(script)
		elif cat == PowerupBase.Category.DUO_ONLY:
			duo_powerups.append(script)

static func get_random_powerup() -> GDScript:
	var pool = common_powerups.duplicate()
	if is_duo_mode:
		pool.append_array(duo_powerups)
		
	if pool.is_empty():
		return preload("res://scripts/powerups/powerup_base.gd")
		
	return pool.pick_random()
