extends Node3D

@export var platforms_root_path: NodePath = ^"Platforms"
@export var tower_inner_radius: float = 30.0
@export var wall_inset: float = 1.4
@export var min_ring_height: float = 6.0
@export var ring_count: int = 12
@export var ring_spacing: float = 8.0
@export var ring_height_jitter: float = 1.75
@export var min_platforms_per_ring: int = 4
@export var max_platforms_per_ring: int = 8
@export var platform_arc_degrees: float = 22.0
@export var platform_sector_radius: float = 6.0
@export var platform_thickness: float = 3.0

var _platform_material := StandardMaterial3D.new()

func _ready() -> void:
	randomize()
	_platform_material.albedo_color = Color(0.24, 0.29, 0.36)
	_platform_material.roughness = 0.8
	_generate_platform_rings()

func _generate_platform_rings() -> void:
	var platforms_root := get_node_or_null(platforms_root_path) as Node3D
	if platforms_root == null:
		return

	for child in platforms_root.get_children():
		child.queue_free()

	for ring_index in range(ring_count):
		var ring_y := min_ring_height + float(ring_index) * ring_spacing + randf_range(-ring_height_jitter, ring_height_jitter)
		var platform_count := randi_range(min_platforms_per_ring, max_platforms_per_ring)
		var angle_offset := randf() * TAU
		for platform_index in range(platform_count):
			var base_angle := (float(platform_index) / float(platform_count)) * TAU
			var angle := base_angle + angle_offset + randf_range(-0.15, 0.15)
			_create_platform_arc(platforms_root, ring_index, platform_index, ring_y, angle)

func _create_platform_arc(parent: Node3D, ring_index: int, platform_index: int, y: float, center_angle: float) -> void:
	var platform_body := StaticBody3D.new()
	platform_body.name = "Ring%d_Platform%d" % [ring_index, platform_index]
	var ring_radius: float = maxf(1.0, tower_inner_radius - wall_inset)
	platform_body.position = Vector3(cos(center_angle) * ring_radius, y, sin(center_angle) * ring_radius)
	platform_body.rotation.y = center_angle
	parent.add_child(platform_body)

	var mesh := _create_sector_mesh()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _platform_material
	platform_body.add_child(mesh_instance)

	var collision_shape := CollisionShape3D.new()
	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = platform_sector_radius
	cylinder_shape.height = platform_thickness
	collision_shape.shape = cylinder_shape
	platform_body.add_child(collision_shape)

func _create_sector_mesh() -> Mesh:
	var mesh := ArrayMesh.new()
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var indices: PackedInt32Array = []

	var arc_radians: float = deg_to_rad(platform_arc_degrees)
	var inner_radius: float = platform_sector_radius * 0.35
	var outer_radius: float = platform_sector_radius
	var radial_steps: int = 5
	var angular_steps: int = 8

	for y_idx in range(2):
		var y: float = float(y_idx) * platform_thickness
		var y_normal := Vector3.UP if y_idx == 0 else Vector3.DOWN

		for r in range(radial_steps + 1):
			var r_frac: float = float(r) / float(radial_steps)
			var curr_radius: float = lerpf(inner_radius, outer_radius, r_frac)
			for a in range(angular_steps + 1):
				var a_frac: float = float(a) / float(angular_steps)
				var angle: float = lerpf(-arc_radians * 0.5, arc_radians * 0.5, a_frac)
				var x: float = cos(angle) * curr_radius
				var z: float = sin(angle) * curr_radius
				vertices.append(Vector3(x, y, z))
				normals.append(y_normal)

	var cols: int = angular_steps + 1
	for y_idx in range(2):
		var y_offset: int = y_idx * (radial_steps + 1) * cols
		for r in range(radial_steps):
			for a in range(angular_steps):
				var v0: int = y_offset + r * cols + a
				var v1: int = y_offset + r * cols + a + 1
				var v2: int = y_offset + (r + 1) * cols + a
				var v3: int = y_offset + (r + 1) * cols + a + 1

				if y_idx == 0:
					indices.append_array([v0, v2, v1])
					indices.append_array([v1, v2, v3])
				else:
					indices.append_array([v0, v1, v2])
					indices.append_array([v1, v3, v2])

	for r in range(radial_steps + 1):
		for a in [0, angular_steps]:
			var bottom_idx: int = r * cols + a
			var top_idx: int = (radial_steps + 1) * cols + r * cols + a
			if r < radial_steps:
				var bottom_next: int = (r + 1) * cols + a
				var top_next: int = (radial_steps + 1) * cols + (r + 1) * cols + a
				indices.append_array([bottom_idx, bottom_next, top_idx])
				indices.append_array([top_idx, bottom_next, top_next])

	var arrays := []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arrays[ArrayMesh.ARRAY_NORMAL] = normals
	arrays[ArrayMesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
