extends Node3D

@export var tower_radius: float = 30.0
@export var min_spin_degrees: float = 20.0
@export var max_spin_degrees: float = 65.0
@export var platform_depth: float = 3.0
@export var platform_thickness: float = 1.0

## Height gap between consecutive platforms.
## With jump_velocity 18 and gravity_scale 2.2 the max jump height ≈ 7.5 units.
## Keep max well under that so every platform is reachable.
@export var min_height_interval: float = 4.0
@export var max_height_interval: float = 6.0

## Number of platforms to spawn around the tower at each height level.
@export var min_platforms_per_level: int = 2
@export var max_platforms_per_level: int = 4

## How far ahead of the player (in Y units) to keep platforms generated.
@export var generation_lead: float = 80.0

## How far below the player old platforms are culled.
@export var cull_distance: float = 40.0

## Internal state ----------------------------------------------------------
var _next_y: float = 0.0
var _platform_index: int = 0
var _generated_up_to_y: float = 0.0

## -------------------------------------------------------------------------
## Public API
## -------------------------------------------------------------------------

## Called once to seed the initial batch of platforms.
## start_y  : the Y the player is standing on (floor level).
## viewport_top : highest Y visible in the starting camera frame.
func generate_initial(start_y: float, viewport_top: float) -> void:
	## Clear leftovers from a previous run (editor re-entry, etc.)
	for child in get_children():
		child.queue_free()

	_platform_index = 0
	_next_y = start_y + min_height_interval

	## Always generate enough platforms to fill the opening viewport PLUS the
	## normal generation lead so the world feels populated from the start.
	var target_y := maxf(viewport_top, start_y) + generation_lead
	_generate_up_to(target_y)

## Extend the world upward so there are always platforms ahead of the player.
func extend_to(player_y: float) -> void:
	var target_y := player_y + generation_lead
	if target_y > _generated_up_to_y:
		_generate_up_to(target_y)

## Remove platforms that are far below the player to save memory.
func cull_below(player_y: float) -> void:
	var threshold := player_y - cull_distance
	for child in get_children():
		if child is StaticBody3D and child.position.y < threshold:
			child.queue_free()

## -------------------------------------------------------------------------
## Internal generation
## -------------------------------------------------------------------------

func _generate_up_to(target_y: float) -> void:
	while _next_y < target_y:
		var platforms_this_level := randi_range(min_platforms_per_level, max_platforms_per_level)
		var angle_offset := randf() * TAU
		
		for i in range(platforms_this_level):
			var base_angle := (float(i) / float(platforms_this_level)) * TAU
			var angle := fmod(base_angle + angle_offset + randf_range(-0.2, 0.2), TAU)
			var y_jitter := randf_range(-0.5, 0.5)
			_spawn_platform_at(_next_y + y_jitter, angle)

		_next_y += randf_range(min_height_interval, max_height_interval)

	_generated_up_to_y = _next_y

func _spawn_platform_at(y: float, theta: float) -> void:
	var platform_root := StaticBody3D.new()
	platform_root.position = Vector3(0, y, 0)
	platform_root.rotation.y = theta
	platform_root.name = "Platform_%d" % _platform_index
	_platform_index += 1
	add_child(platform_root)

	var spin_degrees: float = randf_range(min_spin_degrees, max_spin_degrees)
	var spin_radians: float = deg_to_rad(spin_degrees)
	var inner_radius: float = tower_radius - platform_depth

	var mesh := _create_spun_platform_mesh(spin_radians, inner_radius, tower_radius)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	platform_root.add_child(mesh_instance)

	## Solid convex collision hull.
	var collision_shape := CollisionShape3D.new()
	var convex_shape := ConvexPolygonShape3D.new()
	convex_shape.points = mesh.get_faces()
	collision_shape.shape = convex_shape
	platform_root.add_child(collision_shape)

## -------------------------------------------------------------------------
## Mesh helpers (unchanged)
## -------------------------------------------------------------------------

func _create_spun_platform_mesh(spin_radians: float, inner_radius: float, outer_radius: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_spin: float = spin_radians * 0.5
	## Ensure enough angular steps for a smooth curve along the wall
	var angular_steps: int = max(8, int(spin_radians * 15.0))

	for i in range(angular_steps):
		var angle_a = lerpf(-half_spin, half_spin, float(i) / float(angular_steps))
		var angle_b = lerpf(-half_spin, half_spin, float(i + 1) / float(angular_steps))

		## Vertices for Angle A (Start of the current segment)
		var ia_b = Vector3(inner_radius * cos(angle_a), 0, inner_radius * sin(angle_a))
		var oa_b = Vector3(outer_radius * cos(angle_a), 0, outer_radius * sin(angle_a))
		var ia_t = Vector3(inner_radius * cos(angle_a), platform_thickness, inner_radius * sin(angle_a))
		var oa_t = Vector3(outer_radius * cos(angle_a), platform_thickness, outer_radius * sin(angle_a))

		## Vertices for Angle B (End of the current segment)
		var ib_b = Vector3(inner_radius * cos(angle_b), 0, inner_radius * sin(angle_b))
		var ob_b = Vector3(outer_radius * cos(angle_b), 0, outer_radius * sin(angle_b))
		var ib_t = Vector3(inner_radius * cos(angle_b), platform_thickness, inner_radius * sin(angle_b))
		var ob_t = Vector3(outer_radius * cos(angle_b), platform_thickness, outer_radius * sin(angle_b))

		## Top Face (Normal forced UP)
		_add_quad(st, oa_t, ob_t, ib_t, ia_t, Vector3.UP)
		
		## Bottom Face (Normal forced DOWN)
		_add_quad(st, oa_b, ia_b, ib_b, ob_b, Vector3.DOWN)
		
		## Outer Face (Calculates outward normal automatically)
		_add_quad(st, oa_b, ob_b, ob_t, oa_t)
		
		## Inner Face (Calculates inward normal automatically)
		_add_quad(st, ia_b, ia_t, ib_t, ib_b)

		## Start Cap (Only generated on the very first step of the arc)
		if i == 0:
			_add_quad(st, oa_b, ia_b, ia_t, oa_t)
		
		## End Cap (Only generated on the very last step of the arc)
		if i == angular_steps - 1:
			_add_quad(st, ib_b, ob_b, ob_t, ib_t)

	return st.commit()

## Helper function to guarantee perfect CCW quads with flat normals
func _add_quad(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3, normal: Vector3 = Vector3.ZERO):
	if normal == Vector3.ZERO:
		## Cross product to calculate a perfectly flat normal for the face
		normal = (p2 - p1).cross(p3 - p1).normalized()
	
	## Triangle 1
	st.set_normal(normal)
	st.add_vertex(p1)
	st.set_normal(normal)
	st.add_vertex(p2)
	st.set_normal(normal)
	st.add_vertex(p3)

	## Triangle 2
	st.set_normal(normal)
	st.add_vertex(p1)
	st.set_normal(normal)
	st.add_vertex(p3)
	st.set_normal(normal)
	st.add_vertex(p4)
