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

## Player color – used to tint the Scotty model.
@export var player_color: Color = Color(0.2, 0.7, 0.95, 1.0)

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var fall_disabled: bool = false
var wind_force: float = 0.0
var acceleration_scale: float = 1.0

## Plunge attack / stun state
var stun_timer: float = 0.0
var is_stunned: bool = false
var _plunge_accel: float = 200.0

## Fly state
var fly_timer: float = 0.0
var _fly_sfx: AudioStreamPlayer

## Model references
var _model: Node3D
var _anim_player: AnimationPlayer

func _ready() -> void:
	scale = Vector3(1.5, 1.5, 1.5)
	
	_fly_sfx = AudioStreamPlayer.new()
	_fly_sfx.stream = preload("res://assets/sfx_fly.ogg")
	_fly_sfx.bus = &"Master"
	add_child(_fly_sfx)
	
	_setup_scotty_model()
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

	var inst = powerup_script.new()
	if inst.has_method("get_powerup_name") and inst.get_powerup_name() == "FLY":
		fly_timer = 5.0
		print("Picked up FLY! Timer set to 5.0")
		return

	inventory.append(powerup_script)
	inventory_changed.emit()
	print("Picked up powerup! Inventory size: ", inventory.size())

func _physics_process(delta: float) -> void:
	## --- Stun countdown ---
	if is_stunned:
		stun_timer -= delta
		
		## --- Shake and label logic ---
		if _model:
			var shake_offset := Vector3(
				randf_range(-0.05, 0.05),
				0.0,
				randf_range(-0.05, 0.05)
			)
			_model.position = Vector3(0, -0.6, 0) + shake_offset
		
		if stun_timer <= 0.0:
			is_stunned = false
			stun_timer = 0.0
			if _model: _model.position = Vector3(0, -0.6, 0)

	## --- Fly countdown ---
	if fly_timer > 0.0:
		fly_timer -= delta
		if fly_timer <= 0.0 and _fly_sfx.playing:
			_fly_sfx.stop()

	if not is_on_floor():
		velocity.y -= _gravity * gravity_scale * delta
		if not is_stunned and not fall_disabled and Input.is_action_pressed(action_fall):
			velocity.y -= 120.0 * delta

	if not is_stunned:
		if fly_timer > 0.0:
			if Input.is_action_pressed(action_jump):
				velocity.y += 60.0 * delta
				if not _fly_sfx.playing:
					_fly_sfx.play()
			else:
				if _fly_sfx.playing:
					_fly_sfx.stop()
		else:
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
	if not is_stunned:
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

	## --- Face model toward movement direction ---
	if _model:
		var flat_vel := Vector2(velocity.x, velocity.z)
		if flat_vel.length_squared() > 1.0:
			var target_angle := atan2(flat_vel.x, flat_vel.y)
			_model.rotation.y = lerp_angle(_model.rotation.y, target_angle, 12.0 * delta)
		
		## Play/pause walk animation based on movement
		if _anim_player:
			if flat_vel.length_squared() > 1.0 and is_on_floor():
				if not _anim_player.is_playing():
					_anim_player.play("ArmatureAction")
			elif _anim_player.is_playing() and _anim_player.current_animation == "ArmatureAction" and is_on_floor():
				_anim_player.stop()

	## --- Plunge attack: check collisions with other players ---
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is CharacterBody3D and collider != self and collider.has_method("receive_plunge"):
			# Attacker must be holding the fall key and coming from above
			if not is_stunned and Input.is_action_pressed(action_fall) and global_position.y > collider.global_position.y:
				collider.receive_plunge()

	if is_on_floor():
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			if col.get_normal().y > 0.5:
				var collider = col.get_collider()
				if collider and collider.has_method("on_stepped"):
					collider.on_stepped()

func receive_plunge() -> void:
	if is_stunned:
		return  # Already stunned, don't stack
	if is_on_floor():
		# Grounded: stun for 3 seconds
		is_stunned = true
		stun_timer = 3.0
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

func _setup_scotty_model() -> void:
	## Remove the old capsule MeshInstance3D.
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()
	
	## Instantiate the Scotty model.
	var scotty_scene := preload("res://assets/Scotty.blend")
	_model = scotty_scene.instantiate()
	_model.name = "ScottyModel"
	
	## Remove the camera and lamp from the imported scene – we have our own.
	for child in _model.get_children():
		if child is Camera3D or child.name == "BezierCircle" or child.name == "Lamp":
			child.queue_free()
	
	## Scale the model to fit the player collision shape.
	## The Scotty model is roughly 14 units tall; capsule is 1.2 units.
	_model.scale = Vector3(0.35, 0.15, 0.35)
	_model.position = Vector3(0, -0.6, 0)  ## Offset so feet align with collision bottom
	
	add_child(_model)
	
	## Find the AnimationPlayer in the imported scene.
	_anim_player = _find_node_by_type(_model, "AnimationPlayer") as AnimationPlayer
	if _anim_player:
		_anim_player.active = true
		if _anim_player.has_animation("ArmatureAction"):
			_anim_player.get_animation("ArmatureAction").loop_mode = Animation.LOOP_LINEAR
	
	## Apply player color to the "Bois" (body) material on all mesh instances.
	_apply_color_to_model(_model, player_color)
	
	_setup_collision()

func _setup_collision() -> void:
	var col_shape = get_node_or_null("CollisionShape3D")
	if col_shape:
		var box := BoxShape3D.new()
		# Model is approx 14 units. Scale 0.35x0.15x0.35
		# We want a box that covers the base and height.
		# Note: Player scale is 1.5, so we define local box size.
		box.size = Vector3(1.0, 2.0, 1.0) 
		col_shape.shape = box
		col_shape.position.y = 0.4 # Center it vertically (box is centered)

func _apply_color_to_model(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for surface_idx in mi.mesh.get_surface_count():
			var mat = mi.mesh.surface_get_material(surface_idx)
			if mat and mat is StandardMaterial3D:
				var mat_name = mat.resource_name
				if mat_name == "Bois":
					var new_mat := mat.duplicate() as StandardMaterial3D
					new_mat.albedo_color = color
					mi.set_surface_override_material(surface_idx, new_mat)
	for child in node.get_children():
		_apply_color_to_model(child, color)

func _find_node_by_type(root: Node, type_name: String) -> Node:
	if root.get_class() == type_name:
		return root
	for child in root.get_children():
		var found = _find_node_by_type(child, type_name)
		if found:
			return found
	return null

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
