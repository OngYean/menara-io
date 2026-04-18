extends Node3D

@export var platform_generator_path: NodePath = ^"Platforms"
@export var tower_path: NodePath = ^"Tower"
@export var player1_path: NodePath = ^"Player"
@export var player2_path: NodePath = ^"Player2"
@export var sun_path: NodePath = ^"Sun"

## The tower CylinderMesh has height 120 and is centered at y=60 (spans 0–120).
## We clone a new segment when the player is within this margin of the top.
@export var tower_height: float = 120.0
@export var tower_clone_margin: float = 40.0

## Camera settings (same as tower_camera.gd, inlined for SubViewport cameras).
@export var camera_distance: float = 35.0
@export var camera_smoothing: float = 12.0
var camera_shake_intensity: float = 0.0

## Lava settings.
@export var grace_period: float = 15.0
@export var lava_rise_speed: float = 6.0
@export var lava_start_y: float = -10.0
@export var lava_radius: float = 29.5
@export var lava_column_height: float = 400.0

## Troll settings
@export var troll_start_time: float = 30.0
@export var troll_interval: float = 15.0
@export var forced_first_troll: GDScript = preload("res://scripts/trolls/troll_what_the_flip.gd")

var _generator: Node3D
var _player1: Node3D
var _player2: Node3D
var _tower: MeshInstance3D
var _sun: DirectionalLight3D
var _sun_offset_y: float = 0.0

## Tracks how high the tower geometry currently extends.
var _tower_top_y: float = 0.0

## Split-screen cameras (created in code inside SubViewports).
var _cam1: Camera3D
var _cam2: Camera3D
var _p1_blur: ColorRect
var _p2_blur: ColorRect
var _p1_clouds: ColorRect
var _p2_clouds: ColorRect
var _p1_film: ColorRect
var _p2_film: ColorRect
var _p1_inventory_ui: VBoxContainer
var _p2_inventory_ui: VBoxContainer

var _p1_fly_ui: HBoxContainer
var _p1_fly_label: Label
var _p2_fly_ui: HBoxContainer
var _p2_fly_label: Label

var _p1_stun_ui: CenterContainer
var _p1_stun_label: Label
var _p2_stun_ui: CenterContainer
var _p2_stun_label: Label

var _p1_pointer: Polygon2D
var _p2_pointer: Polygon2D

## UI State
var _elapsed_time: float = 0.0
var _is_duo: bool = false
var _timer_label: Label
var _winner_label: Label
var _grace_label: Label
var _p1_dist_label: Label
var _p2_dist_label: Label

## Lava state
var _lava_mesh: MeshInstance3D
var _lava_y: float = -10.0
var _lava_active: bool = false
var _game_over: bool = false
var _p1_alive: bool = true
var _p2_alive: bool = true

## Troll state
var _troll_classes: Array[GDScript] = []
var _current_troll: TrollBase = null
var _last_troll_script: GDScript = null
var _next_troll_time: float = 30.0
var _troll_label: Label

func _ready() -> void:
	randomize()
	
	_is_duo = get_node("/root/Global").game_mode == "duo"
	PowerupManager.is_duo_mode = _is_duo
	PowerupManager.register_powerup(preload("res://scripts/powerups/powerup_double_jump.gd"))
	PowerupManager.register_powerup(preload("res://scripts/powerups/powerup_fly.gd"))
	
	var bgm := AudioStreamPlayer.new()
	bgm.stream = preload("res://assets/menara-io-bgm.ogg")
	bgm.stream.loop = true
	bgm.bus = &"Master"
	bgm.volume_linear = 0.5
	bgm.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bgm)
	bgm.play()

	_generator = get_node_or_null(platform_generator_path) as Node3D
	_player1 = get_node_or_null(player1_path) as Node3D
	_player2 = get_node_or_null(player2_path) as Node3D
	
	if _player1:
		_player1.inventory_changed.connect(_update_p1_inventory_ui)
	if _player2:
		_player2.inventory_changed.connect(_update_p2_inventory_ui)
	
	if get_node("/root/Global").game_mode == "singleplayer":
		if _player2:
			_player2.queue_free()
			_player2 = null
		_p2_alive = false

	_tower = get_node_or_null(tower_path) as MeshInstance3D
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if _sun:
		_sun_offset_y = _sun.position.y

	## The original tower mesh spans 0 → tower_height (transform y = 60, height 120).
	if _tower:
		_tower_top_y = _tower.position.y + tower_height * 0.5

	## Disable the old single-player camera if it still exists in the scene.
	var old_pivot := get_node_or_null(^"CameraPivot") as Node3D
	if old_pivot:
		old_pivot.queue_free()

	_setup_screen()
	_setup_lava()
	_load_trolls()

	## Seed platforms.
	if _generator and _generator.has_method("generate_initial"):
		var start_y: float = 1.0
		if _player1:
			start_y = _player1.global_position.y
		_generator.generate_initial(start_y, start_y + 20.0)

	_lava_y = lava_start_y

func _process(delta: float) -> void:
	if _game_over:
		## Keep cameras alive but freeze everything else.
		_update_camera(_cam1, _player1, delta)
		_update_camera(_cam2, _player2, delta)
		return

	_elapsed_time += delta
	if _timer_label:
		var mins := int(_elapsed_time) / 60
		var secs := int(_elapsed_time) % 60
		var ms := int((_elapsed_time - int(_elapsed_time)) * 100)
		_timer_label.text = "%02d:%02d.%02d" % [mins, secs, ms]

	## --- Grace period & Troll countdown -------------------------------------
	if _grace_label:
		if not _lava_active:
			var remaining := grace_period - _elapsed_time
			if remaining <= 0.0:
				_lava_active = true
			else:
				_grace_label.text = "LAVA IN %d" % ceili(remaining)
		
		if _lava_active:
			var remaining_troll := _next_troll_time - _elapsed_time
			_grace_label.text = "NEXT TROLL IN %d" % maxf(0.0, ceili(remaining_troll))

	## --- Lava rising ------------------------------------------------------
	if _lava_active:
		_lava_y += lava_rise_speed * delta
		_update_lava_position()
		_check_lava_kills()

	## --- Distance Overlay ---
	if _p1_dist_label and _p1_alive and _player1 and _lava_active:
		var dist = maxf(0.0, _player1.global_position.y - _lava_y)
		_p1_dist_label.text = "↓ %.1fm" % dist
		_p1_dist_label.visible = true
	elif _p1_dist_label:
		_p1_dist_label.visible = false
		
	if _p1_alive and _player1 and _p1_fly_ui:
		if _player1.fly_timer > 0.0:
			_p1_fly_ui.visible = true
			_p1_fly_label.text = "%.1f" % _player1.fly_timer
		else:
			_p1_fly_ui.visible = false
		
	if _p2_dist_label and _p2_alive and _player2 and _lava_active:
		var dist = maxf(0.0, _player2.global_position.y - _lava_y)
		_p2_dist_label.text = "↓ %.1fm" % dist
		_p2_dist_label.visible = true
	elif _p2_dist_label:
		_p2_dist_label.visible = false
		
	if _is_duo and _p2_alive and _player2 and _p2_fly_ui:
		if _player2.fly_timer > 0.0:
			_p2_fly_ui.visible = true
			_p2_fly_label.text = "%.1f" % _player2.fly_timer
		else:
			_p2_fly_ui.visible = false

	if _is_duo and _p1_alive and _p2_alive and _player1 and _player2:
		var left_cont = get_node_or_null("ScreenCanvas/LeftView") as Control
		var right_cont = get_node_or_null("ScreenCanvas/RightView") as Control
		if left_cont and right_cont:
			_update_player_pointer(_cam1, _player2, _p1_pointer, left_cont.size)
			_update_player_pointer(_cam2, _player1, _p2_pointer, right_cont.size)

	if _player1 and _p1_stun_ui:
		if _player1.is_stunned:
			_p1_stun_ui.visible = true
			_p1_stun_label.text = "STUNNED! %.1fs" % _player1.stun_timer
		else:
			_p1_stun_ui.visible = false

	if _is_duo and _player2 and _p2_stun_ui:
		if _player2.is_stunned:
			_p2_stun_ui.visible = true
			_p2_stun_label.text = "STUNNED! %.1fs" % _player2.stun_timer
		else:
			_p2_stun_ui.visible = false

	## --- Troll Logic ------------------------------------------------------
	if _elapsed_time >= _next_troll_time and not _game_over:
		_trigger_next_troll()
		_next_troll_time = _elapsed_time + troll_interval

	## Use the highest player Y for world extension logic.
	var max_y: float = -INF
	if _player1 and _p1_alive:
		max_y = maxf(max_y, _player1.global_position.y)
	if _player2 and _p2_alive:
		max_y = maxf(max_y, _player2.global_position.y)
	if max_y == -INF:
		return

	## --- Infinite platforms ------------------------------------------------
	if _generator:
		if _generator.has_method("extend_to"):
			_generator.extend_to(max_y)

	## --- Keep the sun following the highest player so lighting stays -------
	if _sun:
		_sun.position.y = max_y + _sun_offset_y

	## --- Infinite tower ----------------------------------------------------
	if _tower and max_y + tower_clone_margin > _tower_top_y:
		_extend_tower()

	## --- Update split-screen cameras --------------------------------------
	_update_camera(_cam1, _player1, delta)
	_update_camera(_cam2, _player2, delta)

func _extend_tower() -> void:
	var clone := _tower.duplicate() as MeshInstance3D
	clone.position = Vector3(0.0, _tower_top_y + tower_height * 0.5, 0.0)
	add_child(clone)
	_tower_top_y += tower_height

## -------------------------------------------------------------------------
## Troll System
## -------------------------------------------------------------------------

func _load_trolls() -> void:
	_next_troll_time = troll_start_time
	var dir = DirAccess.open("res://scripts/trolls")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".gd") and file_name != "troll_base.gd":
				var script = load("res://scripts/trolls/" + file_name) as GDScript
				if script:
					_troll_classes.append(script)
			file_name = dir.get_next()

func _trigger_next_troll() -> void:
	if _current_troll:
		_current_troll.end()
		_current_troll.queue_free()
		_current_troll = null
		
	camera_shake_intensity = 0.0
		
	if _troll_classes.is_empty():
		return
		
	var script: GDScript
	if _last_troll_script == null and forced_first_troll != null:
		script = forced_first_troll
	else:
		var pool := _troll_classes.duplicate()
		if _last_troll_script and pool.size() > 1:
			pool.erase(_last_troll_script)
		script = pool.pick_random() as GDScript
		
	_last_troll_script = script
	var troll := script.new() as TrollBase
	if troll:
		troll.game = self
		add_child(troll)
		troll.start()
		_current_troll = troll
		
		if _troll_label:
			_troll_label.text = "TROLL: " + troll.get_troll_name()
			_troll_label.visible = true
			
			var tw := create_tween()
			_troll_label.modulate = Color(2.0, 0.5, 0.5, 1.0)
			tw.tween_property(_troll_label, "modulate", Color.WHITE, 0.5)

## -------------------------------------------------------------------------
## Lava
## -------------------------------------------------------------------------

func _setup_lava() -> void:
	## Create a tall cylinder that represents the lava column.
	## Its TOP surface sits at _lava_y.  We position it so top = _lava_y.
	var lava_mat := ShaderMaterial.new()
	lava_mat.shader = _create_lava_shader()

	var cyl := CylinderMesh.new()
	cyl.top_radius = lava_radius
	cyl.bottom_radius = lava_radius
	cyl.height = lava_column_height
	cyl.radial_segments = 96
	cyl.rings = 1
	cyl.material = lava_mat

	_lava_mesh = MeshInstance3D.new()
	_lava_mesh.mesh = cyl
	_lava_mesh.name = "Lava"
	add_child(_lava_mesh)

	_update_lava_position()

func _update_lava_position() -> void:
	if _lava_mesh:
		## CylinderMesh is centred on its origin; shift so TOP = _lava_y.
		_lava_mesh.position = Vector3(0.0, _lava_y - lava_column_height * 0.5, 0.0)

func _check_lava_kills() -> void:
	if _p1_alive and _player1 and _player1.global_position.y < _lava_y:
		_kill_player(1)
	if _p2_alive and _player2 and _player2.global_position.y < _lava_y:
		_kill_player(2)

func _kill_player(player_index: int) -> void:
	if get_node("/root/Global").game_mode == "singleplayer":
		_p1_alive = false
		if _player1:
			_player1.set_physics_process(false)
			_player1.visible = false
		_declare_winner("GAME OVER")
		return

	if player_index == 1:
		_p1_alive = false
		if _player1:
			_player1.set_physics_process(false)
			_player1.visible = false
		if _p2_alive:
			_declare_winner("PLAYER 2 WINS!")
		else:
			_declare_winner("DRAW!")
	elif player_index == 2:
		_p2_alive = false
		if _player2:
			_player2.set_physics_process(false)
			_player2.visible = false
		if _p1_alive:
			_declare_winner("PLAYER 1 WINS!")
		else:
			_declare_winner("DRAW!")

func _declare_winner(text: String) -> void:
	_game_over = true
	if _winner_label:
		_winner_label.text = text
		_winner_label.visible = true

func _create_lava_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, unshaded;

uniform float time_scale : hint_range(0.1, 5.0) = 1.0;

// Simplex-ish hash for noise
vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(dot(hash22(i), f),
			dot(hash22(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(hash22(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
			dot(hash22(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	vec2 shift = vec2(100.0);
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	float t = TIME * time_scale;
	// Wave displacement on the top face (normal pointing up)
	if (NORMAL.y > 0.5) {
		float wave = fbm(VERTEX.xz * 0.15 + t * 0.3) * 1.5;
		wave += sin(VERTEX.x * 0.5 + t * 2.0) * 0.3;
		wave += cos(VERTEX.z * 0.4 + t * 1.5) * 0.3;
		VERTEX.y += wave;
	}
}

void fragment() {
	float t = TIME * time_scale;
	vec2 uv = UV;

	// Only shade the top surface with full lava detail
	if (NORMAL.y > 0.3) {
		float n1 = fbm(uv * 6.0 + vec2(t * 0.2, t * 0.15));
		float n2 = fbm(uv * 4.0 - vec2(t * 0.1, t * 0.25));
		float combined = (n1 + n2) * 0.5 + 0.5;

		vec3 hot = vec3(1.0, 0.85, 0.2);   // bright yellow
		vec3 warm = vec3(1.0, 0.35, 0.05);  // orange
		vec3 cool = vec3(0.6, 0.08, 0.02);  // dark red
		vec3 crust = vec3(0.15, 0.04, 0.02); // near-black crust

		vec3 col;
		if (combined > 0.7) {
			col = mix(warm, hot, (combined - 0.7) / 0.3);
		} else if (combined > 0.4) {
			col = mix(cool, warm, (combined - 0.4) / 0.3);
		} else {
			col = mix(crust, cool, combined / 0.4);
		}

		ALBEDO = col;
		EMISSION = col * 2.5;
	} else {
		// Side walls – glowing orange
		vec3 side_col = vec3(0.9, 0.25, 0.03);
		ALBEDO = side_col;
		EMISSION = side_col * 1.5;
	}
}
"""
	return shader

## -------------------------------------------------------------------------
## Screen setup
## -------------------------------------------------------------------------

func _setup_screen() -> void:
	var main_world: World3D = get_viewport().world_3d

	## Create a CanvasLayer so the SubViewportContainers fill the screen.
	var canvas := CanvasLayer.new()
	canvas.name = "ScreenCanvas"
	add_child(canvas)
	
	var is_duo = get_node("/root/Global").game_mode == "duo"

	## --- Left half (Player 1) or Full Screen ---
	var left_container := SubViewportContainer.new()
	left_container.name = "LeftView"
	left_container.stretch = true
	left_container.anchor_left = 0.0
	left_container.anchor_top = 0.0
	left_container.anchor_right = 0.5 if is_duo else 1.0
	left_container.anchor_bottom = 1.0
	left_container.offset_left = 0
	left_container.offset_top = 0
	left_container.offset_right = 0
	left_container.offset_bottom = 0
	canvas.add_child(left_container)

	var left_vp := SubViewport.new()
	left_vp.name = "SubViewport"
	left_vp.world_3d = main_world
	left_vp.handle_input_locally = false
	left_container.add_child(left_vp)

	_cam1 = Camera3D.new()
	_cam1.name = "Camera3D"
	_cam1.current = true
	left_vp.add_child(_cam1)

	_p1_blur = _create_blur_overlay()
	left_vp.add_child(_p1_blur)
	
	_p1_clouds = _create_cloud_overlay()
	left_vp.add_child(_p1_clouds)
	
	_p1_film = _create_film_overlay()
	left_vp.add_child(_p1_film)

	_p1_inventory_ui = VBoxContainer.new()
	_p1_inventory_ui.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_p1_inventory_ui.offset_left = 20
	_p1_inventory_ui.alignment = BoxContainer.ALIGNMENT_CENTER
	left_container.add_child(_p1_inventory_ui)

	_p1_fly_ui = _create_fly_ui()
	_p1_fly_label = _p1_fly_ui.get_child(1) as Label
	_p1_fly_ui.position = Vector2(20, 120)
	left_container.add_child(_p1_fly_ui)

	_p1_stun_ui = _create_stun_ui()
	_p1_stun_label = _p1_stun_ui.get_node("Label")
	left_container.add_child(_p1_stun_ui)

	if _is_duo:
		_p1_pointer = Polygon2D.new()
		_p1_pointer.polygon = PackedVector2Array([Vector2(-12, -10), Vector2(16, 0), Vector2(-12, 10)])
		_p1_pointer.color = Color(0.95, 0.45, 0.15, 1.0) # Player 2's color (Orange)
		left_container.add_child(_p1_pointer)

		## --- Right half (Player 2) ---
		var right_container := SubViewportContainer.new()
		right_container.name = "RightView"
		right_container.stretch = true
		right_container.anchor_left = 0.5
		right_container.anchor_top = 0.0
		right_container.anchor_right = 1.0
		right_container.anchor_bottom = 1.0
		right_container.offset_left = 0
		right_container.offset_top = 0
		right_container.offset_right = 0
		right_container.offset_bottom = 0
		canvas.add_child(right_container)

		var right_vp := SubViewport.new()
		right_vp.name = "SubViewport"
		right_vp.world_3d = main_world
		right_vp.handle_input_locally = false
		right_container.add_child(right_vp)

		_cam2 = Camera3D.new()
		_cam2.name = "Camera3D"
		_cam2.current = true
		right_vp.add_child(_cam2)

		_p2_blur = _create_blur_overlay()
		right_vp.add_child(_p2_blur)
		
		_p2_clouds = _create_cloud_overlay()
		right_vp.add_child(_p2_clouds)
		
		_p2_film = _create_film_overlay()
		right_vp.add_child(_p2_film)

		_p2_inventory_ui = VBoxContainer.new()
		_p2_inventory_ui.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		_p2_inventory_ui.offset_right = -20
		_p2_inventory_ui.alignment = BoxContainer.ALIGNMENT_CENTER
		right_container.add_child(_p2_inventory_ui)

		_p2_fly_ui = _create_fly_ui()
		_p2_fly_label = _p2_fly_ui.get_child(1) as Label
		_p2_fly_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_p2_fly_ui.position = Vector2(-150, 120)
		right_container.add_child(_p2_fly_ui)

		_p2_stun_ui = _create_stun_ui()
		_p2_stun_label = _p2_stun_ui.get_node("Label")
		right_container.add_child(_p2_stun_ui)

		_p2_pointer = Polygon2D.new()
		_p2_pointer.polygon = PackedVector2Array([Vector2(-12, -10), Vector2(16, 0), Vector2(-12, 10)])
		_p2_pointer.color = Color(0.2, 0.7, 0.95, 1.0) # Player 1's color (Blue)
		right_container.add_child(_p2_pointer)

	## --- UI Overlay (added last so it renders on top) ---
	if _is_duo:
		var separator := ColorRect.new()
		separator.color = Color.BLACK
		separator.anchor_left = 0.5
		separator.anchor_right = 0.5
		separator.anchor_bottom = 1.0
		separator.offset_left = -2
		separator.offset_right = 2
		canvas.add_child(separator)

	_timer_label = Label.new()
	_timer_label.anchor_left = 0.5
	_timer_label.anchor_right = 0.5
	_timer_label.offset_top = 20
	_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.text = "00:00.00"
	_timer_label.add_theme_font_size_override("font_size", 48)
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_timer_label.add_theme_constant_override("outline_size", 8)
	canvas.add_child(_timer_label)

	## In-game logo
	var logo := TextureRect.new()
	logo.texture = preload("res://assets/favicon.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(80, 80)
	logo.offset_left = 20
	logo.offset_top = 20
	canvas.add_child(logo)

	## Grace period countdown label
	_grace_label = Label.new()
	_grace_label.anchor_left = 0.5
	_grace_label.anchor_right = 0.5
	_grace_label.anchor_top = 0.0
	_grace_label.offset_top = 80
	_grace_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_grace_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grace_label.text = "LAVA IN %d" % ceili(grace_period)
	_grace_label.add_theme_font_size_override("font_size", 36)
	_grace_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
	_grace_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_grace_label.add_theme_constant_override("outline_size", 6)
	canvas.add_child(_grace_label)

	## Winner announcement label (hidden until game over)
	_winner_label = Label.new()
	_winner_label.anchor_left = 0.0
	_winner_label.anchor_right = 1.0
	_winner_label.anchor_top = 0.4
	_winner_label.anchor_bottom = 0.6
	_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_winner_label.text = ""
	_winner_label.visible = false
	_winner_label.add_theme_font_size_override("font_size", 72)
	_winner_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_winner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_winner_label.add_theme_constant_override("outline_size", 10)
	canvas.add_child(_winner_label)

	## Troll announcement label
	_troll_label = Label.new()
	_troll_label.anchor_left = 0.0
	_troll_label.anchor_right = 1.0
	_troll_label.anchor_top = 0.2
	_troll_label.anchor_bottom = 0.3
	_troll_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_troll_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_troll_label.text = ""
	_troll_label.visible = false
	_troll_label.add_theme_font_size_override("font_size", 56)
	_troll_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_troll_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_troll_label.add_theme_constant_override("outline_size", 8)
	canvas.add_child(_troll_label)

	## Lava distance labels
	_p1_dist_label = Label.new()
	_p1_dist_label.anchor_top = 1.0
	_p1_dist_label.anchor_bottom = 1.0
	_p1_dist_label.anchor_left = 0.5 if not _is_duo else 0.25
	_p1_dist_label.anchor_right = 0.5 if not _is_duo else 0.25
	_p1_dist_label.offset_top = -60
	_p1_dist_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_p1_dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_p1_dist_label.add_theme_font_size_override("font_size", 32)
	_p1_dist_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
	_p1_dist_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_p1_dist_label.add_theme_constant_override("outline_size", 6)
	canvas.add_child(_p1_dist_label)

	if _is_duo:
		_p2_dist_label = Label.new()
		_p2_dist_label.anchor_top = 1.0
		_p2_dist_label.anchor_bottom = 1.0
		_p2_dist_label.anchor_left = 0.75
		_p2_dist_label.anchor_right = 0.75
		_p2_dist_label.offset_top = -60
		_p2_dist_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_p2_dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_p2_dist_label.add_theme_font_size_override("font_size", 32)
		_p2_dist_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
		_p2_dist_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_p2_dist_label.add_theme_constant_override("outline_size", 6)
		canvas.add_child(_p2_dist_label)

	## Initialise camera positions so the first frame isn't jarring.
	if _player1:
		_cam1.global_position = _get_desired_cam_pos(_player1)
	if _player2:
		_cam2.global_position = _get_desired_cam_pos(_player2)

func _get_desired_cam_pos(player: Node3D) -> Vector3:
	var p: Vector3 = player.global_position
	var radial_xz := Vector2(p.x, p.z)
	var inward: Vector3
	if radial_xz.length_squared() > 0.0001:
		var n := radial_xz.normalized()
		inward = Vector3(-n.x, 0.0, -n.y)
	else:
		inward = Vector3.FORWARD
	return p + inward * camera_distance

func _update_camera(cam: Camera3D, player: Node3D, delta: float) -> void:
	if cam == null or player == null:
		return
	var desired := _get_desired_cam_pos(player)
	cam.global_position = cam.global_position.lerp(desired, clamp(camera_smoothing * delta, 0.0, 1.0))
	cam.look_at(player.global_position, Vector3.UP)
	
	if camera_shake_intensity > 0.0:
		cam.h_offset = randf_range(-0.5, 0.5) * camera_shake_intensity
		cam.v_offset = randf_range(-0.5, 0.5) * camera_shake_intensity
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

func _create_blur_overlay() -> ColorRect:
	var cr := ColorRect.new()
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/vignette_blur.gdshader")
	cr.material = mat
	return cr

func _create_cloud_overlay() -> ColorRect:
	var cr := ColorRect.new()
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/cloud_filter.gdshader")
	cr.material = mat
	return cr

func _create_film_overlay() -> ColorRect:
	var cr := ColorRect.new()
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/moonlanding_film.gdshader")
	cr.material = mat
	return cr
func _update_p1_inventory_ui() -> void:
	_update_inventory_ui(_player1, _p1_inventory_ui)

func _update_p2_inventory_ui() -> void:
	_update_inventory_ui(_player2, _p2_inventory_ui)

func _update_inventory_ui(player: Node3D, container: VBoxContainer) -> void:
	if not player or not container: return
	for child in container.get_children():
		child.queue_free()
	
	for script in player.inventory:
		var inst = script.new()
		var rect = TextureRect.new()
		rect.texture = inst.get_icon()
		rect.custom_minimum_size = Vector2(40, 40)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(rect)

func _create_fly_ui() -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.visible = false
	
	var rect := TextureRect.new()
	rect.texture = preload("res://assets/powerup_fly.png")
	rect.custom_minimum_size = Vector2(30, 30)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(rect)
	
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.text = "7.0"
	hb.add_child(label)
	
	return hb

func _update_player_pointer(cam: Camera3D, target: Node3D, pointer: Polygon2D, vp_size: Vector2) -> void:
	if not cam or not target or not pointer: return
	
	var target_pos = target.global_position
	var is_behind = cam.is_position_behind(target_pos)
	var screen_pos = cam.unproject_position(target_pos)
	
	var center = vp_size * 0.5
	var dir = (screen_pos - center).normalized()
	if is_behind:
		dir = -dir
		screen_pos = center + dir * 10000.0
		
	var margin = 30.0
	
	var clamped_pos = center
	if abs(dir.x) > 0.001:
		var t_x = ((vp_size.x - margin if dir.x > 0 else margin) - center.x) / dir.x
		clamped_pos = center + dir * t_x
		
	if clamped_pos.y < margin or clamped_pos.y > vp_size.y - margin:
		if abs(dir.y) > 0.001:
			var t_y = ((vp_size.y - margin if dir.y > 0 else margin) - center.y) / dir.y
			clamped_pos = center + dir * t_y
			
	var is_on_screen = not is_behind and screen_pos.x >= margin and screen_pos.x <= vp_size.x - margin and screen_pos.y >= margin and screen_pos.y <= vp_size.y - margin
	
	if is_on_screen:
		pointer.position = screen_pos
		pointer.rotation = dir.angle()
		# Add a subtle hover offset above the player so it doesn't cover them entirely
		pointer.position.y -= 40.0
		pointer.rotation = PI/2 # Point straight down
	else:
		pointer.position = clamped_pos
		pointer.rotation = dir.angle()

func _create_stun_ui() -> CenterContainer:
	var cc := CenterContainer.new()
	# Span the full width and center at the top
	cc.anchor_left = 0.0
	cc.anchor_right = 1.0
	cc.anchor_top = 0.0
	cc.anchor_bottom = 0.0
	cc.offset_top = 40
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.visible = false
	
	var label := Label.new()
	label.name = "Label"
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.text = "STUNNED!"
	cc.add_child(label)
	
	return cc
