extends PowerupBase

func get_category() -> Category:
	return Category.DUO_ONLY

func get_powerup_name() -> String:
	return "FLASHBANG"

func get_icon() -> Texture2D:
	return preload("res://assets/powerup_flashbang.png")

func activate(player: CharacterBody3D) -> void:
	var game = player.get_parent()
	if not game.has_method("flashbang_player"):
		return
		
	# Show warning immediately on opponent's screen
	var my_idx = 1 if player.name == "Player" else 2
	var opponent_idx = 2 if my_idx == 1 else 1
	if game.has_method("spawn_flashbang_warning"):
		game.spawn_flashbang_warning(opponent_idx)

	# Plays sfx_flashbang_voice.ogg immediately
	var sfx_voice = AudioStreamPlayer.new()
	sfx_voice.stream = preload("res://assets/sfx_flashbang_voice.ogg")
	game.add_child(sfx_voice)
	sfx_voice.play()
	sfx_voice.finished.connect(sfx_voice.queue_free)
	
	# Wait 2 seconds
	var timer = game.get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		# Play sfx_pop.ogg
		var sfx_pop = AudioStreamPlayer.new()
		sfx_pop.stream = preload("res://assets/sfx_pop.ogg")
		game.add_child(sfx_pop)
		sfx_pop.play()
		sfx_pop.finished.connect(sfx_pop.queue_free)
		
		# Flashbang the opponent
		game.flashbang_player(opponent_idx)
	)
