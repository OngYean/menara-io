extends Area3D
class_name PowerupPickup

var powerup_script: GDScript

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(script: GDScript) -> void:
	powerup_script = script

func _on_body_entered(body: Node) -> void:
	if body.has_method("pickup_powerup"):
		if powerup_script:
			body.pickup_powerup(powerup_script)
		queue_free()
