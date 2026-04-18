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
var wind_force: float = 0.0
var acceleration_scale: float = 1.0

## Plunge attack / stun state
var _stun_timer: float = 0.0
var _is_stunned: bool = false
var _plunge_accel: float = 200.0

func _ready() -> void:
	_ensure_input_actions()

signal inventory_changed

var _knockback: Vector3 = Vector3.ZERO
var inventory: Array[GDScript] = []

func apply_knockback(force: Vector3) -> void:
	_knockback += force

func pickup_powerup(powerup_script: GDScript) -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = preload("res://assets/sfx_pickup.ogg")
	sfx.bus = &"Master"
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

	inventory.append(powerup_script)
	inventory_changed.emit()
	print("Picked up powerup! Inventory size: ", inventory.size())

func _physics_process(delta: float) -> void:
	## --- Stun countdown ---
	if _is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_is_stunned = false
			_stun_timer = 0.0

	if not is_on_floor():
		velocity.y -= _gravity * gravity_scale * delta
		if not _is_stunned and not fall_disabled and Input.is_action_pressed(action_fall):
			velocity.y -= 120.0 * delta

	if not _is_stunned:
		if Input.is_action_just_pressed(action_jump):
			if is_on_floor():
				velocity.y = jump_velocity
				_play_jump_sfx()
			else:
				# Check for double jump in inventory
				for i in range(inventory.size()):
					var inst = inventory[i].new()
					if inst.get_powerup_name() == "DOUBLE JUMP":
						velocity.y = jump_velocity
						_play_jump_sfx()
						inventory.remove_at(i)
						inventory_changed.emit()
						break

	var turn_input: float = 0.0
	if not _is_stunned:
		turn_input = Input.get_action_strength(action_move_right) - Input.get_action_strength(action_move_left)

	## Tangent direction: perpendicular to the outward radial, so the player
	## always runs along the tower wall rather than toward/away from the centre.
	var radial_dir := Vector3(global_position.x - tower_center.x, 0.0, global_position.z - tower_center.z)
	if radial_dir.length_squared() < 0.0001:
		radial_dir = Vector3.FORWARD
	else:
		radial_dir = radial_dir.normalized()
	var tangent_dir := Vector3(-radial_dir.z, 0.0, radial_dir.x)

	var target_xz := tangent_dir * (turn_input * move_speed + wind_force)

	velocity.x = move_toward(velocity.x, target_xz.x, acceleration * acceleration_scale * delta)
	velocity.z = move_toward(velocity.z, target_xz.z, acceleration * acceleration_scale * delta)

	if _knockback.length_squared() > 0.001:
		velocity += _knockback
		_knockback = Vector3.ZERO

	move_and_slide()
	_clamp_inside_tower()

	## --- Plunge attack: check collisions with other players ---
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is CharacterBody3D and collider != self and collider.has_method("receive_plunge"):
			# Attacker must be holding the fall key and coming from above
			if not _is_stunned and Input.is_action_pressed(action_fall) and global_position.y > collider.global_position.y:
				collider.receive_plunge()

	if is_on_floor():
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			if col.get_normal().y > 0.5:
				var collider = col.get_collider()
				if collider and collider.has_method("on_stepped"):
					collider.on_stepped()

func receive_plunge() -> void:
	if _is_stunned:
		return  # Already stunned, don't stack
	if is_on_floor():
		# Grounded: stun for 3 seconds
		_is_stunned = true
		_stun_timer = 3.0
		velocity = Vector3.ZERO
	else:
		# Airborne: slam downward
		velocity.y -= _plunge_accel

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

func _play_jump_sfx() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = preload("res://assets/sfx_jump.ogg")
	sfx.bus = &"Master"
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

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
