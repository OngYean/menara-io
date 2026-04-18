extends TrollBase

var _wind_dir: float = 1.0

func start() -> void:
	_wind_dir = 1.0 if randf() > 0.5 else -1.0
	var strength := 15.0 * _wind_dir
	
	if game._player1:
		game._player1.wind_force = strength
	if game._player2:
		game._player2.wind_force = strength
		
	if game._p1_clouds:
		var mat := game._p1_clouds.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("direction", _wind_dir)
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 0.0, 1.0, 1.0)
	
	if game._p2_clouds:
		var mat := game._p2_clouds.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("direction", _wind_dir)
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 0.0, 1.0, 1.0)

func end() -> void:
	if game._player1:
		game._player1.wind_force = 0.0
	if game._player2:
		game._player2.wind_force = 0.0
		
	if game._p1_clouds:
		var mat := game._p1_clouds.material as ShaderMaterial
		if mat:
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 1.0, 0.0, 1.0)
			
	if game._p2_clouds:
		var mat := game._p2_clouds.material as ShaderMaterial
		if mat:
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 1.0, 0.0, 1.0)

func get_troll_name() -> String:
	return "MUST'VE BEEN THE WIND AHH"
