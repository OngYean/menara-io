extends TrollBase

var _original_fov: float = 75.0

func start() -> void:
	if game._cam1:
		_original_fov = game._cam1.fov
		var tw := game.create_tween()
		tw.tween_property(game._cam1, "fov", _original_fov * 0.5, 0.5).set_trans(Tween.TRANS_SINE)
	
	if game._cam2:
		var tw := game.create_tween()
		tw.tween_property(game._cam2, "fov", _original_fov * 0.5, 0.5).set_trans(Tween.TRANS_SINE)
		
	if game._p1_blur:
		var mat := game._p1_blur.material as ShaderMaterial
		if mat:
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("blur_amount", v), 0.0, 6.0, 0.5)
			
	if game._p2_blur:
		var mat := game._p2_blur.material as ShaderMaterial
		if mat:
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("blur_amount", v), 0.0, 6.0, 0.5)

func end() -> void:
	if game._cam1:
		var tw := game.create_tween()
		tw.tween_property(game._cam1, "fov", _original_fov, 0.5).set_trans(Tween.TRANS_SINE)
	
	if game._cam2:
		var tw := game.create_tween()
		tw.tween_property(game._cam2, "fov", _original_fov, 0.5).set_trans(Tween.TRANS_SINE)

	if game._p1_blur:
		var mat := game._p1_blur.material as ShaderMaterial
		if mat:
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("blur_amount", v), 6.0, 0.0, 0.5)
			
	if game._p2_blur:
		var mat := game._p2_blur.material as ShaderMaterial
		if mat:
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("blur_amount", v), 6.0, 0.0, 0.5)

func get_troll_name() -> String:
	return "SHORT-SIGHTEDNESS"
