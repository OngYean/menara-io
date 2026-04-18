extends TrollBase

func start() -> void:
	if game._player1:
		game._player1.gravity_scale *= 0.5
		game._player1.fall_disabled = true
		game._player1.acceleration_scale = 0.1
	if game._player2:
		game._player2.gravity_scale *= 0.5
		game._player2.fall_disabled = true
		game._player2.acceleration_scale = 0.1
		
	if game._p1_film:
		var mat := game._p1_film.material as ShaderMaterial
		if mat:
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 0.0, 1.0, 1.0)
	if game._p2_film:
		var mat := game._p2_film.material as ShaderMaterial
		if mat:
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 0.0, 1.0, 1.0)

func end() -> void:
	if game._player1:
		game._player1.gravity_scale *= 2.0
		game._player1.fall_disabled = false
		game._player1.acceleration_scale = 1.0
	if game._player2:
		game._player2.gravity_scale *= 2.0
		game._player2.fall_disabled = false
		game._player2.acceleration_scale = 1.0
		
	if game._p1_film:
		var mat := game._p1_film.material as ShaderMaterial
		if mat:
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 1.0, 0.0, 1.0)
	if game._p2_film:
		var mat := game._p2_film.material as ShaderMaterial
		if mat:
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 1.0, 0.0, 1.0)

func get_troll_name() -> String:
	return "MOON-WALKING"
