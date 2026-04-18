extends TrollBase

var _timer: float = 0.0
var _spawn_interval: float = 0.06
var _tex_cat = preload("res://assets/cat.png")
var _tex_dog = preload("res://assets/dog.png")
var _physics_mat: PhysicsMaterial

func start() -> void:
	_physics_mat = PhysicsMaterial.new()
	_physics_mat.bounce = 1.1
	_physics_mat.friction = 0.1
	
	if game._p1_clouds:
		var mat := game._p1_clouds.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("direction", 0.0) # Straight down
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 0.0, 1.0, 1.0)
	if game._p2_clouds:
		var mat := game._p2_clouds.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("direction", 0.0)
			var tw := game.create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 0.0, 1.0, 1.0)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = _spawn_interval
		_spawn_sphere()

func _spawn_sphere() -> void:
	var highest_y := -1000.0
	if game._player1 and game._p1_alive:
		highest_y = maxf(highest_y, game._player1.global_position.y)
	if game._player2 and game._p2_alive:
		highest_y = maxf(highest_y, game._player2.global_position.y)
		
	if highest_y < -500.0:
		return # No players alive
		
	var rb := RigidBody3D.new()
	rb.set_script(preload("res://scripts/trolls/falling_sphere.gd"))
	rb.mass = 10.0
	rb.physics_material_override = _physics_mat
	rb.linear_damp = 0.0
	rb.angular_damp = 0.0
	
	var is_cat = randf() > 0.5
	var tex = _tex_cat if is_cat else _tex_dog
	
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Scale so the largest dimension is 3.2m (matching the old 2x sphere diameter)
	var max_dim = maxf(tex.get_width(), tex.get_height())
	sprite.pixel_size = 3.2 / max_dim
	rb.add_child(sprite)
	
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var w = tex.get_width() * sprite.pixel_size
	var h = tex.get_height() * sprite.pixel_size
	# Make it a cube-like box so it has volume to bounce on all axes
	shape.size = Vector3(w, h, w)
	col.shape = shape
	rb.add_child(col)
	
	# Spawn randomly around the tower
	var angle := randf() * TAU
	var radius: float = 27.0 # Match player wall radius
	var spawn_pos := Vector3(cos(angle) * radius, highest_y + 40.0, sin(angle) * radius)
	
	# Target a player 40% of the time to make it threatening
	if randf() < 0.4:
		var target: Node3D = null
		if game._player1 and game._p1_alive and game._player2 and game._p2_alive:
			target = game._player1 if randf() > 0.5 else game._player2
		elif game._player1 and game._p1_alive:
			target = game._player1
		elif game._player2 and game._p2_alive:
			target = game._player2
			
		if target:
			spawn_pos.x = target.global_position.x
			spawn_pos.z = target.global_position.z
	
	rb.position = spawn_pos
	game.add_child(rb)

func end() -> void:
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
	return "RAINING CATS AND DOGS"
