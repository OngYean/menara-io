extends Node3D

@export var player_path: NodePath
@export var camera_distance: float = 35.0

@onready var _camera: Camera3D = $Camera3D
var _player: Node3D

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	if _camera:
		_camera.position = Vector3(0.0, 0.0, 0.0)

func _process(_delta: float) -> void:
	if _player == null:
		return

	global_position = Vector3(0.0, _player.global_position.y, 0.0)
	_camera.look_at(_player.global_position, Vector3.UP)
