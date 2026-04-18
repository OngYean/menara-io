extends Node3D

@export var player_path: NodePath
## Fixed distance between the camera lens and the player at all times.
@export var camera_distance: float = 35.0
## How quickly the camera interpolates toward its target (lower = smoother but laggier).
@export var camera_smoothing: float = 12.0

@onready var _camera: Camera3D = $Camera3D
var _player: Node3D

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D

func _process(delta: float) -> void:
	if _player == null or _camera == null:
		return

	var player_pos: Vector3 = _player.global_position

	## Compute the inward radial direction from the player toward the tower centre.
	## The camera sits behind the player (between the player and the tower axis)
	## at exactly camera_distance, so the player-to-camera distance is always fixed.
	var radial_xz := Vector2(player_pos.x, player_pos.z)
	var inward_dir: Vector3
	if radial_xz.length_squared() > 0.0001:
		## Normalised direction from player toward tower centre (inward).
		inward_dir = Vector3(-radial_xz.normalized().x, 0.0, -radial_xz.normalized().y)
	else:
		inward_dir = Vector3.FORWARD

	## Desired camera world position: directly inward from the player.
	var desired_pos: Vector3 = player_pos + inward_dir * camera_distance

	## Smooth interpolation so the camera doesn't snap on fast jumps.
	global_position = global_position.lerp(desired_pos, clamp(camera_smoothing * delta, 0.0, 1.0))

	## Always look at the player.
	_camera.look_at(player_pos, Vector3.UP)
