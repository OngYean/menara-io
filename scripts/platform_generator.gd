extends Node3D
class_name PlatformGenerator

## Tower's fixed radius (player moves on circumference at this distance from center)
@export var tower_radius: float = 30.0

## Minimum arc length in degrees for a platform
@export var min_spin_degrees: float = 15.0

## Maximum arc length in degrees for a platform
@export var max_spin_degrees: float = 45.0

## Minimum vertical distance between platforms
@export var min_height_interval: float = 4.0

## Maximum vertical distance between platforms
@export var max_height_interval: float = 8.0

## Radial depth of each platform (how far from inner wall to outer wall)
@export var platform_depth: float = 3.0

## Vertical thickness of each platform (how tall it is on the Y axis)
@export var platform_thickness: float = 1.0

## Total number of platforms to generate
@export var total_platforms: int = 50

var _platform_material: StandardMaterial3D


func _ready() -> void:
	_platform_material = StandardMaterial3D.new()
	_platform_material.albedo_color = Color(0.24, 0.29, 0.36)
	_platform_material.roughness = 0.8
	_platform_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	generate_platforms()


func generate_platforms() -> void:
	## Clear any existing platforms
	for child in get_children():
		child.queue_free()

	randomize()
	var current_y: float = 0.0
	
	for i in range(total_platforms):
		## Random vertical spacing between platforms
		current_y += randf_range(min_height_interval, max_height_interval)
		
		## Constraint 1: Cylindrical Coordinates for Placement
		## Generate random angle theta (0 to TAU)
		var theta: float = randf() * TAU
		
		## Convert cylindrical to Cartesian coordinates
		var x: float = tower_radius * cos(theta)
		var z: float = tower_radius * sin(theta)
		var y: float = current_y
		
		## Create platform root node at this position
		var platform_root := Node3D.new()
		platform_root.position = Vector3(x, y, z)
		platform_root.name = "Platform_%d" % i
		add_child(platform_root)
		
		## Constraint 2: Orientation - Platform faces the center of the tower
		## look_at() makes the platform "face" the tower center
		var tower_center := Vector3(0, y, 0)
		platform_root.look_at(tower_center, Vector3.UP)
		
		## Constraint 3: Shape Generation using procedural mesh with SurfaceTool
		## This ensures all faces are rendered (top, bottom, inner, outer, and end caps)
		
		## Random platform arc length in degrees
		var spin_degrees: float = randf_range(min_spin_degrees, max_spin_degrees)
		var spin_radians: float = deg_to_rad(spin_degrees)
		
		## Calculate inner and outer radii for the platform's cross-section
		var inner_radius: float = tower_radius - platform_depth
		var outer_radius: float = tower_radius
		
		## Generate the mesh using SurfaceTool with full control over all faces
		var mesh := _create_spun_platform_mesh(spin_radians, inner_radius, outer_radius)
		
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _platform_material
		platform_root.add_child(mesh_instance)
		
		## Add collision shape using the generated mesh
		var collision_shape := CollisionShape3D.new()
		var concave_shape := ConcavePolygonShape3D.new()
		concave_shape.set_faces(mesh.get_faces())
		collision_shape.shape = concave_shape
		platform_root.add_child(collision_shape)


func _create_spun_platform_mesh(spin_radians: float, inner_radius: float, outer_radius: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var half_spin: float = spin_radians * 0.5
	var angular_steps: int = max(8, int(spin_radians * 15.0))  ## More detail for better rendering
	
	## Build vertices array: [angle_step][height_level][radius_level]
	## height_level: 0=bottom, 1=top
	## radius_level: 0=inner, 1=outer
	var verts: Array = []
	
	for angle_idx in range(angular_steps + 1):
		var angle = lerpf(-half_spin, half_spin, float(angle_idx) / float(angular_steps))
		verts.append([])
		
		for height in range(2):
			verts[angle_idx].append([])
			var y = float(height) * platform_thickness
			
			for radial in range(2):
				var r = lerpf(inner_radius, outer_radius, float(radial))
				var x = r * cos(angle)
				var z = r * sin(angle)
				verts[angle_idx][height].append(Vector3(x, y, z))
	
	## Top face (height=1)
	for i in range(angular_steps):
		var a = verts[i]
		var b = verts[i + 1]
		st.add_vertex(a[1][0])
		st.add_vertex(b[1][0])
		st.add_vertex(b[1][1])
		st.add_vertex(a[1][0])
		st.add_vertex(b[1][1])
		st.add_vertex(a[1][1])
	
	## Bottom face (height=0)
	for i in range(angular_steps):
		var a = verts[i]
		var b = verts[i + 1]
		st.add_vertex(a[0][0])
		st.add_vertex(a[0][1])
		st.add_vertex(b[0][1])
		st.add_vertex(a[0][0])
		st.add_vertex(b[0][1])
		st.add_vertex(b[0][0])
	
	## Outer surface (radial=1)
	for i in range(angular_steps):
		var a = verts[i]
		var b = verts[i + 1]
		st.add_vertex(a[0][1])
		st.add_vertex(a[1][1])
		st.add_vertex(b[1][1])
		st.add_vertex(a[0][1])
		st.add_vertex(b[1][1])
		st.add_vertex(b[0][1])
	
	## Inner surface (radial=0)
	for i in range(angular_steps):
		var a = verts[i]
		var b = verts[i + 1]
		st.add_vertex(a[0][0])
		st.add_vertex(b[1][0])
		st.add_vertex(a[1][0])
		st.add_vertex(a[0][0])
		st.add_vertex(b[0][0])
		st.add_vertex(b[1][0])
	
	## Start cap (angle=-half_spin)
	var start = verts[0]
	st.add_vertex(start[0][0])
	st.add_vertex(start[0][1])
	st.add_vertex(start[1][1])
	st.add_vertex(start[0][0])
	st.add_vertex(start[1][1])
	st.add_vertex(start[1][0])
	
	## End cap (angle=+half_spin)
	var end = verts[angular_steps]
	st.add_vertex(end[0][0])
	st.add_vertex(end[1][1])
	st.add_vertex(end[0][1])
	st.add_vertex(end[0][0])
	st.add_vertex(end[1][0])
	st.add_vertex(end[1][1])
	
	st.generate_normals()
	return st.commit()