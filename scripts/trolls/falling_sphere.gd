extends RigidBody3D

var knockback_strength: float = 40.0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	
	# Destroy after 5 seconds to prevent clutter
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(queue_free)

func _physics_process(_delta: float) -> void:
	# Keep the object at the same distance from center as the player
	var radial := Vector2(global_position.x, global_position.z)
	if radial.length_squared() < 0.0001:
		radial = Vector2(0.0, 27.0)
	else:
		radial = radial.normalized() * 27.0
	
	global_position.x = radial.x
	global_position.z = radial.y

func _on_body_entered(body: Node) -> void:
	if body.has_method("apply_knockback"):
		# Calculate knockback direction
		var dir = (body.global_position - global_position).normalized()
		dir.y = 0.2 # Slight upward push to get them off the ground
		
		body.apply_knockback(dir.normalized() * knockback_strength)
