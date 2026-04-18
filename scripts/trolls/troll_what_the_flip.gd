extends TrollBase

## "What The Flip" — performs a full 360-degree barrel roll of the entire
## tower and platforms around the midpoint between lava and the highest player
## over 3 seconds.  Players keep their world-space position. Everything ends upright.

var _flip_pivot_y: float = 0.0
var _nodes_to_flip: Array[Node3D] = []
var _start_states: Array[Dictionary] = []

func start() -> void:
	_flip_world()

func _flip_world() -> void:
	## 1.  Determine the vertical pivot — midpoint between lava and highest player.
	var highest_y := -1000.0
	if game._player1 and game._p1_alive:
		highest_y = maxf(highest_y, game._player1.global_position.y)
	if game._player2 and game._p2_alive:
		highest_y = maxf(highest_y, game._player2.global_position.y)
	if highest_y < -500.0:
		return
	
	_flip_pivot_y = (game._lava_y + highest_y) * 0.5

	_nodes_to_flip.clear()
	_start_states.clear()

	## 2.  Collect tower mesh segments
	if game._tower:
		_nodes_to_flip.append(game._tower)
	for child in game.get_children():
		if child is MeshInstance3D and child != game._tower:
			_nodes_to_flip.append(child)

	## 3.  Collect every platform under the generator.
	if game._generator:
		for child in game._generator.get_children():
			if child is StaticBody3D:
				_nodes_to_flip.append(child)

	## 4. Record start states
	for node in _nodes_to_flip:
		var sy = node.global_position.y
		var sr = node.rotation.x
		_start_states.append({"y": sy, "rot_x": sr})

	## 5. Animate a full 360 degree spin over 5 seconds with screen shake
	game.camera_shake_intensity = 3.0
	var tw := game.create_tween()
	tw.tween_method(_animate_flip, 0.0, 1.0, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		game.camera_shake_intensity = 0.0
		
		## Secretly revert the tower to its exact original orientation/position
		## just in case floating point errors accumulated.
		for i in range(_nodes_to_flip.size()):
			var node = _nodes_to_flip[i]
			if is_instance_valid(node) and node is MeshInstance3D:
				node.global_position.y = _start_states[i]["y"]
				node.rotation.x = _start_states[i]["rot_x"]
				
		if game._generator and game._generator.has_method("extend_to"):
			game._generator.extend_to(highest_y)
	)

func _animate_flip(t: float) -> void:
	var angle := t * TAU # 360 degrees (two 180 flips)
	for i in range(_nodes_to_flip.size()):
		var node = _nodes_to_flip[i]
		if is_instance_valid(node):
			var start = _start_states[i]
			node.global_position.y = _flip_pivot_y + cos(angle) * (start["y"] - _flip_pivot_y)
			node.rotation.x = start["rot_x"] + angle

func end() -> void:
	## The world has already done a full 360 spin and is upright again,
	## so no reverse animation is needed!
	pass

func get_troll_name() -> String:
	return "WHAT THE FLIP"
