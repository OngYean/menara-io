extends Area3D
class_name PowerupPickup

var powerup_script: GDScript

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(script: GDScript) -> void:
	powerup_script = script
	if not is_inside_tree(): await ready
	
	var inst = powerup_script.new()
	if inst.has_method("get_icon"):
		var icon = inst.get_icon()
		if icon:
			var sprite = get_node_or_null("Sprite3D")
			if not sprite:
				sprite = Sprite3D.new()
				sprite.name = "Sprite3D"
				sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				sprite.pixel_size = 0.02
				add_child(sprite)
			sprite.texture = icon
			
			var mesh = get_node_or_null("MeshInstance3D")
			if mesh: mesh.hide()
	# inst is RefCounted, will be freed automatically

func _on_body_entered(body: Node) -> void:
	if body.has_method("pickup_powerup"):
		if powerup_script:
			body.pickup_powerup(powerup_script)
		queue_free()
