extends TrollBase

func start() -> void:
	if game._player1:
		game._player1.gravity_scale *= 0.5
		game._player1.fall_disabled = true
	if game._player2:
		game._player2.gravity_scale *= 0.5
		game._player2.fall_disabled = true

func end() -> void:
	if game._player1:
		game._player1.gravity_scale *= 2.0
		game._player1.fall_disabled = false
	if game._player2:
		game._player2.gravity_scale *= 2.0
		game._player2.fall_disabled = false

func get_troll_name() -> String:
	return "FEATHER FALLING"
