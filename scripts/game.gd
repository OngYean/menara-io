extends Node3D

@export var platform_generator_path: NodePath = ^"Platforms"
@export var tower_path: NodePath = ^"Tower"
@export var player_path: NodePath = ^"Player"
@export var sun_path: NodePath = ^"Sun"

## The tower CylinderMesh has height 120 and is centered at y=60 (spans 0–120).
## We clone a new segment when the player is within this margin of the top.
@export var tower_height: float = 120.0
@export var tower_clone_margin: float = 40.0

var _generator: Node3D
var _player: Node3D
var _tower: MeshInstance3D
var _sun: DirectionalLight3D
var _sun_offset_y: float = 0.0

## Tracks how high the tower geometry currently extends.
var _tower_top_y: float = 0.0

func _ready() -> void:
	randomize()

	_generator = get_node_or_null(platform_generator_path) as Node3D
	_player = get_node_or_null(player_path) as Node3D
	_tower = get_node_or_null(tower_path) as MeshInstance3D
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if _sun:
		_sun_offset_y = _sun.position.y

	## The original tower mesh spans 0 → tower_height (transform y = 60, height 120).
	if _tower:
		_tower_top_y = _tower.position.y + tower_height * 0.5

	## Seed platforms: fill the opening viewport and beyond.
	## Player starts at roughly y=2 (floor is at y=1).  The initial camera sees
	## roughly ±15 units vertically from the player, so viewport_top ≈ 17.
	if _generator and _generator.has_method("generate_initial"):
		var start_y: float = 1.0
		if _player:
			start_y = _player.global_position.y
		_generator.generate_initial(start_y, start_y + 20.0)

func _process(_delta: float) -> void:
	if _player == null:
		return

	var player_y := _player.global_position.y

	## --- Infinite platforms ------------------------------------------------
	if _generator:
		if _generator.has_method("extend_to"):
			_generator.extend_to(player_y)
		## Culling disabled for now – re-enable when ready.
		#if _generator.has_method("cull_below"):
		#	_generator.cull_below(player_y)

	## --- Keep the sun following the player so lighting never fades --------
	if _sun:
		_sun.position.y = player_y + _sun_offset_y

	## --- Infinite tower ----------------------------------------------------
	if _tower and player_y + tower_clone_margin > _tower_top_y:
		_extend_tower()

func _extend_tower() -> void:
	## Clone the original tower mesh and stack it on top.
	var clone := _tower.duplicate() as MeshInstance3D
	clone.position = Vector3(0.0, _tower_top_y + tower_height * 0.5, 0.0)
	add_child(clone)
	_tower_top_y += tower_height
