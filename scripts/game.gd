extends Node3D

@export var platform_generator_path: NodePath = ^"Platforms"
@export var tower_path: NodePath = ^"Tower"
@export var player1_path: NodePath = ^"Player"
@export var player2_path: NodePath = ^"Player2"
@export var sun_path: NodePath = ^"Sun"

## The tower CylinderMesh has height 120 and is centered at y=60 (spans 0–120).
## We clone a new segment when the player is within this margin of the top.
@export var tower_height: float = 120.0
@export var tower_clone_margin: float = 40.0

## Camera settings (same as tower_camera.gd, inlined for SubViewport cameras).
@export var camera_distance: float = 35.0
@export var camera_smoothing: float = 12.0

var _generator: Node3D
var _player1: Node3D
var _player2: Node3D
var _tower: MeshInstance3D
var _sun: DirectionalLight3D
var _sun_offset_y: float = 0.0

## Tracks how high the tower geometry currently extends.
var _tower_top_y: float = 0.0

## Split-screen cameras (created in code inside SubViewports).
var _cam1: Camera3D
var _cam2: Camera3D

## UI State
var _elapsed_time: float = 0.0
var _timer_label: Label

func _ready() -> void:
	randomize()

	_generator = get_node_or_null(platform_generator_path) as Node3D
	_player1 = get_node_or_null(player1_path) as Node3D
	_player2 = get_node_or_null(player2_path) as Node3D
	_tower = get_node_or_null(tower_path) as MeshInstance3D
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if _sun:
		_sun_offset_y = _sun.position.y

	## The original tower mesh spans 0 → tower_height (transform y = 60, height 120).
	if _tower:
		_tower_top_y = _tower.position.y + tower_height * 0.5

	## Disable the old single-player camera if it still exists in the scene.
	var old_pivot := get_node_or_null(^"CameraPivot") as Node3D
	if old_pivot:
		old_pivot.queue_free()

	_setup_split_screen()

	## Seed platforms.
	if _generator and _generator.has_method("generate_initial"):
		var start_y: float = 1.0
		if _player1:
			start_y = _player1.global_position.y
		_generator.generate_initial(start_y, start_y + 20.0)

func _process(delta: float) -> void:
	_elapsed_time += delta
	if _timer_label:
		var mins := int(_elapsed_time) / 60
		var secs := int(_elapsed_time) % 60
		var ms := int((_elapsed_time - int(_elapsed_time)) * 100)
		_timer_label.text = "%02d:%02d.%02d" % [mins, secs, ms]

	## Use the highest player Y for world extension logic.
	var max_y: float = -INF
	if _player1:
		max_y = maxf(max_y, _player1.global_position.y)
	if _player2:
		max_y = maxf(max_y, _player2.global_position.y)
	if max_y == -INF:
		return

	## --- Infinite platforms ------------------------------------------------
	if _generator:
		if _generator.has_method("extend_to"):
			_generator.extend_to(max_y)
		## Culling disabled for now – re-enable when ready.
		#if _generator.has_method("cull_below"):
		#	_generator.cull_below(max_y)

	## --- Keep the sun following the highest player so lighting stays -------
	if _sun:
		_sun.position.y = max_y + _sun_offset_y

	## --- Infinite tower ----------------------------------------------------
	if _tower and max_y + tower_clone_margin > _tower_top_y:
		_extend_tower()

	## --- Update split-screen cameras --------------------------------------
	_update_camera(_cam1, _player1, delta)
	_update_camera(_cam2, _player2, delta)

func _extend_tower() -> void:
	var clone := _tower.duplicate() as MeshInstance3D
	clone.position = Vector3(0.0, _tower_top_y + tower_height * 0.5, 0.0)
	add_child(clone)
	_tower_top_y += tower_height

## -------------------------------------------------------------------------
## Split-screen setup
## -------------------------------------------------------------------------

func _setup_split_screen() -> void:
	var main_world: World3D = get_viewport().world_3d

	## Create a CanvasLayer so the SubViewportContainers fill the screen.
	var canvas := CanvasLayer.new()
	canvas.name = "SplitScreen"
	add_child(canvas)

	## --- Left half (Player 1) ---
	var left_container := SubViewportContainer.new()
	left_container.name = "LeftView"
	left_container.stretch = true
	left_container.anchor_left = 0.0
	left_container.anchor_top = 0.0
	left_container.anchor_right = 0.5
	left_container.anchor_bottom = 1.0
	left_container.offset_left = 0
	left_container.offset_top = 0
	left_container.offset_right = 0
	left_container.offset_bottom = 0
	canvas.add_child(left_container)

	var left_vp := SubViewport.new()
	left_vp.name = "SubViewport"
	left_vp.world_3d = main_world
	left_vp.handle_input_locally = false
	left_container.add_child(left_vp)

	_cam1 = Camera3D.new()
	_cam1.name = "Camera3D"
	_cam1.current = true
	left_vp.add_child(_cam1)

	## --- Right half (Player 2) ---
	var right_container := SubViewportContainer.new()
	right_container.name = "RightView"
	right_container.stretch = true
	right_container.anchor_left = 0.5
	right_container.anchor_top = 0.0
	right_container.anchor_right = 1.0
	right_container.anchor_bottom = 1.0
	right_container.offset_left = 0
	right_container.offset_top = 0
	right_container.offset_right = 0
	right_container.offset_bottom = 0
	canvas.add_child(right_container)

	var right_vp := SubViewport.new()
	right_vp.name = "SubViewport"
	right_vp.world_3d = main_world
	right_vp.handle_input_locally = false
	right_container.add_child(right_vp)

	_cam2 = Camera3D.new()
	_cam2.name = "Camera3D"
	_cam2.current = true
	right_vp.add_child(_cam2)

	## --- UI Overlay ---
	var separator := ColorRect.new()
	separator.color = Color.BLACK
	separator.anchor_left = 0.5
	separator.anchor_right = 0.5
	separator.anchor_bottom = 1.0
	separator.offset_left = -2
	separator.offset_right = 2
	canvas.add_child(separator)
	
	_timer_label = Label.new()
	_timer_label.anchor_left = 0.5
	_timer_label.anchor_right = 0.5
	_timer_label.offset_top = 20
	_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.text = "00:00.00"
	_timer_label.add_theme_font_size_override("font_size", 48)
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_timer_label.add_theme_constant_override("outline_size", 8)
	canvas.add_child(_timer_label)

	## Initialise camera positions so the first frame isn't jarring.
	if _player1:
		_cam1.global_position = _get_desired_cam_pos(_player1)
	if _player2:
		_cam2.global_position = _get_desired_cam_pos(_player2)

func _get_desired_cam_pos(player: Node3D) -> Vector3:
	var p: Vector3 = player.global_position
	var radial_xz := Vector2(p.x, p.z)
	var inward: Vector3
	if radial_xz.length_squared() > 0.0001:
		var n := radial_xz.normalized()
		inward = Vector3(-n.x, 0.0, -n.y)
	else:
		inward = Vector3.FORWARD
	return p + inward * camera_distance

func _update_camera(cam: Camera3D, player: Node3D, delta: float) -> void:
	if cam == null or player == null:
		return
	var desired := _get_desired_cam_pos(player)
	cam.global_position = cam.global_position.lerp(desired, clamp(camera_smoothing * delta, 0.0, 1.0))
	cam.look_at(player.global_position, Vector3.UP)
