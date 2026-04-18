extends CharacterBody3D

@export var move_speed: float = 28.0
@export var acceleration: float = 90.0
@export var jump_velocity: float = 18.0
@export var tower_center: Vector3 = Vector3.ZERO
## The player is always clamped to this radius – must match the platform inner edge.
@export var wall_radius: float = 27.0
## Multiplier on top of the project gravity – higher = snappier falls.
@export var gravity_scale: float = 2.2

## Configurable input action names – unique per player to avoid conflicts.
@export var action_move_left: StringName = &"p1_move_left"
@export var action_move_right: StringName = &"p1_move_right"
@export var action_jump: StringName = &"p1_jump"
@export var action_fall: StringName = &"p1_fall"

## Key bindings – registered automatically at runtime.
@export var key_move_left: Key = KEY_A
@export var key_move_right: Key = KEY_D
@export var key_jump: Key = KEY_W
@export var key_fall: Key = KEY_S

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var fall_disabled: bool = false

func _ready() -> void:
	_ensure_input_actions()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * gravity_scale * delta
		if not fall_disabled and Input.is_action_pressed(action_fall):
			velocity.y -= 120.0 * delta

	if Input.is_action_just_pressed(action_jump) and is_on_floor():
		velocity.y = jump_velocity

	var turn_input: float = Input.get_action_strength(action_move_right) - Input.get_action_strength(action_move_left)

	## Tangent direction: perpendicular to the outward radial, so the player
	## always runs along the tower wall rather than toward/away from the centre.
	var radial_dir := Vector3(global_position.x - tower_center.x, 0.0, global_position.z - tower_center.z)
	if radial_dir.length_squared() < 0.0001:
		radial_dir = Vector3.FORWARD
	else:
		radial_dir = radial_dir.normalized()
	var tangent_dir := Vector3(-radial_dir.z, 0.0, radial_dir.x)

	var target_xz := tangent_dir * turn_input * move_speed

	velocity.x = move_toward(velocity.x, target_xz.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_xz.z, acceleration * delta)

	move_and_slide()
	_clamp_inside_tower()

	if is_on_floor():
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			if col.get_normal().y > 0.5:
				var collider = col.get_collider()
				if collider and collider.has_method("on_stepped"):
					collider.on_stepped()

func _clamp_inside_tower() -> void:
	## Pin the player to wall_radius so they are always at a consistent distance
	## from the tower centre (and therefore from the camera).
	var radial := Vector2(global_position.x - tower_center.x, global_position.z - tower_center.z)
	if radial.length_squared() < 0.0001:
		radial = Vector2(0.0, wall_radius)
	else:
		radial = radial.normalized() * wall_radius

	global_position.x = tower_center.x + radial.x
	global_position.z = tower_center.z + radial.y

func _ensure_input_actions() -> void:
	_add_action_key_if_missing(action_move_left, key_move_left)
	_add_action_key_if_missing(action_move_right, key_move_right)
	_add_action_key_if_missing(action_jump, key_jump)
	_add_action_key_if_missing(action_fall, key_fall)

func _add_action_key_if_missing(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)
