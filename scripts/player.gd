extends CharacterBody3D

@export var move_speed: float = 10.0
@export var radial_speed: float = 7.0
@export var acceleration: float = 20.0
@export var jump_velocity: float = 9.0
@export var tower_center: Vector3 = Vector3.ZERO
@export var min_radius: float = 6.0
@export var max_radius: float = 28.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	_ensure_input_actions()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var turn_input: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var vertical_input: float = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")

	var radial_dir := Vector3(global_position.x - tower_center.x, 0.0, global_position.z - tower_center.z)
	if radial_dir.length_squared() < 0.0001:
		radial_dir = Vector3.FORWARD
	else:
		radial_dir = radial_dir.normalized()
	var tangent_dir := Vector3(-radial_dir.z, 0.0, radial_dir.x)

	var target_xz := Vector3.ZERO
	target_xz += tangent_dir * turn_input * move_speed

	velocity.x = move_toward(velocity.x, target_xz.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_xz.z, acceleration * delta)
	velocity.y += vertical_input * radial_speed

	move_and_slide()
	_clamp_inside_tower()

func _clamp_inside_tower() -> void:
	var radial := Vector2(global_position.x - tower_center.x, global_position.z - tower_center.z)
	var radius := radial.length()
	if radius <= max_radius and radius >= min_radius:
		return

	if radius < 0.0001:
		radial = Vector2(0.0, min_radius)
	else:
		radial = radial.normalized() * clamp(radius, min_radius, max_radius)

	global_position.x = tower_center.x + radial.x
	global_position.z = tower_center.z + radial.y

func _ensure_input_actions() -> void:
	_add_action_key_if_missing("move_forward", KEY_W)
	_add_action_key_if_missing("move_backward", KEY_S)
	_add_action_key_if_missing("move_left", KEY_A)
	_add_action_key_if_missing("move_right", KEY_D)
	_add_action_key_if_missing("jump", KEY_SPACE)

func _add_action_key_if_missing(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)
