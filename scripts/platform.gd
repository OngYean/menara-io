extends StaticBody3D

var _stepped := false
var _crumble_timer := 2.0
var _original_material: Material
var _crumble_material: StandardMaterial3D

func on_stepped() -> void:
	if not get_node("/root/Global").earthquake_active:
		return
	if not _stepped:
		_stepped = true
		if get_child_count() > 0:
			var mesh := get_child(0) as MeshInstance3D
			if mesh:
				_original_material = mesh.get_active_material(0)
				_crumble_material = StandardMaterial3D.new()
				_crumble_material.albedo_color = Color.WHITE
				mesh.set_surface_override_material(0, _crumble_material)

func _process(delta: float) -> void:
	if not get_node("/root/Global").earthquake_active:
		if _stepped:
			_stepped = false
			_crumble_timer = 2.0
			if get_child_count() > 0:
				var mesh := get_child(0) as MeshInstance3D
				if mesh:
					mesh.position = Vector3.ZERO
					mesh.scale = Vector3.ONE
					mesh.set_surface_override_material(0, _original_material)
		return

	if _stepped:
		_crumble_timer -= delta
		var progress := 1.0 - maxf(0.0, _crumble_timer / 2.0)
		
		if get_child_count() > 0:
			var mesh := get_child(0) as MeshInstance3D
			if mesh:
				# Jitter increases as timer runs out
				var jitter := lerpf(0.05, 0.25, progress)
				mesh.position = Vector3(randf_range(-jitter, jitter), randf_range(-jitter, jitter), randf_range(-jitter, jitter))
				
				# Flash red and turn dark
				if _crumble_material:
					var blink := (sin(progress * 25.0) + 1.0) * 0.5
					var base_color := Color.WHITE.lerp(Color(0.2, 0.2, 0.2), progress)
					var flash_color := Color(1.0, 0.2, 0.2)
					_crumble_material.albedo_color = base_color.lerp(flash_color, blink)
				
				# Flatten the platform at the very end
				mesh.scale.y = lerpf(1.0, 0.1, pow(progress, 4.0))
				
		if _crumble_timer <= 0.0:
			queue_free()
