@tool
extends PanelContainer

var editor_interface: EditorInterface
var current_generator: Node

var create_btn: Button
var main_content: VBoxContainer
var status_label: Label
var ui_elements: Dictionary = {}

var tabs_config = {
	"3D Models": [
		{"prop": "floor_scene", "label": "Floor", "type": "scene"},
		{"prop": "wall_solid", "label": "Wall (Solid)", "type": "scene"},
		{"prop": "wall_doorway", "label": "Wall (Doorway)", "type": "scene"},
		{"prop": "wall_window", "label": "Wall (Window)", "type": "scene"},
		{"prop": "wall_jail", "label": "Wall (Jail Bars)", "type": "scene"},
		{"prop": "stairs_scene", "label": "Stairs 2x2", "type": "scene"},
		{"prop": "ceiling_straight", "label": "Ceiling (Straight)", "type": "scene"},
		{"prop": "ceiling_corner", "label": "Ceiling (Corner)", "type": "scene"},
		{"prop": "ceiling_3way", "label": "Ceiling (3-Way)", "type": "scene"},
		{"prop": "ceiling_4way", "label": "Ceiling (4-Way)", "type": "scene"},
		{"prop": "ceiling_end", "label": "Ceiling (Dead End)", "type": "scene"},
		{"prop": "pillar_corner", "label": "Pillar (Corner)", "type": "scene"},
		{"prop": "pillar_round_scene", "label": "Pillar (Center)", "type": "scene"},
		{"prop": "torch_scene", "label": "Torch Prop", "type": "scene"},
		{"prop": "chest_scene", "label": "Chest Prop", "type": "scene"},
		{"prop": "debris_scene", "label": "Debris Prop", "type": "scene"}
	],
	"Alternate Deep Theme": [
		{"prop": "alt_theme_start_level", "label": "Start Alternate Theme at Level #", "type": "int", "min": 1, "max": 100},
		{"prop": "alt_floor_scene", "label": "Deep Floor", "type": "scene"},
		{"prop": "alt_wall_solid", "label": "Deep Wall (Solid)", "type": "scene"},
		{"prop": "alt_wall_doorway", "label": "Deep Wall (Doorway)", "type": "scene"}
	],
	"Dimensions & Grid": [
		{"prop": "grid_width", "label": "Grid Width", "type": "int", "min": 5, "max": 200},
		{"prop": "grid_height", "label": "Grid Height", "type": "int", "min": 5, "max": 200},
		{"prop": "num_levels", "label": "Number of Levels", "type": "int", "min": 1, "max": 50},
		{"prop": "level_height", "label": "Y-Height Per Level", "type": "float", "min": 1.0, "max": 50.0},
		{"prop": "tile_size", "label": "Tile Size (Meters)", "type": "float", "min": 1.0, "max": 20.0},
		{"prop": "ceiling_height", "label": "Ceiling Height (Meters)", "type": "float", "min": 1.0, "max": 20.0},
		{"prop": "num_staircases", "label": "Number of Staircases", "type": "int", "min": 1, "max": 15},
		{"prop": "guarantee_tower_access", "label": "Force Tower Connections", "type": "bool"},
		{"prop": "use_fixed_seed", "label": "Use Fixed Seed", "type": "bool"},
		{"prop": "seed_value", "label": "Seed Number", "type": "int", "min": 0, "max": 999999999}
	],
	"Generation Rules": [
		{"prop": "num_rooms", "label": "Total Rooms", "type": "int", "min": 1, "max": 300},
		{"prop": "room_min_size", "label": "Room Min Size (W, H)", "type": "vec2i"},
		{"prop": "room_max_size", "label": "Room Max Size (W, H)", "type": "vec2i"},
		{"prop": "room_padding", "label": "Room Padding", "type": "int", "min": 0, "max": 5},
		{"prop": "alcove_chance", "label": "Alcove Chance", "type": "float", "min": 0.0, "max": 1.0},
		{"prop": "use_mst_connections", "label": "Smart Corridor Connections", "type": "bool"},
		{"prop": "loop_chance", "label": "Extra Loop Chance", "type": "float", "min": 0.0, "max": 1.0},
		{"prop": "dead_end_chance", "label": "Dead End Chance", "type": "float", "min": 0.0, "max": 1.0},
		{"prop": "generate_navmesh", "label": "Bake Navigation Mesh", "type": "bool"},
		{"prop": "spawn_torches", "label": "Spawn Torches (Lights)", "type": "bool"},
		{"prop": "torch_chance", "label": "Torch Spawn Chance", "type": "float", "min": 0.0, "max": 1.0},
		{"prop": "spawn_chests", "label": "Spawn Chests", "type": "bool"},
		{"prop": "spawn_debris", "label": "Spawn Debris", "type": "bool"},
		{"prop": "debris_chance", "label": "Debris Spawn Chance", "type": "float", "min": 0.0, "max": 1.0}
	],
	"Calibration Offsets": [
		{"prop": "floor_offset", "label": "Floor Model Offset", "type": "vec3"},
		{"prop": "wall_offset", "label": "Wall Model Offset", "type": "vec3"},
		{"prop": "ceiling_offset", "label": "Ceiling Model Offset", "type": "vec3"},
		{"prop": "stairs_position_offset", "label": "Stairs Pos Offset", "type": "vec3"},
		{"prop": "stairs_rotation_offset", "label": "Stairs Rot Offset (Deg)", "type": "vec3"},
		{"prop": "wall_rotation_offset_deg", "label": "Global Wall Rot Offset", "type": "float", "min": -360.0, "max": 360.0}
	]
}

func _ready() -> void:
	custom_minimum_size = Vector2(0, 350)
	
	create_btn = Button.new()
	create_btn.text = "➕ CLICK HERE TO ADD A DUNGEON GENERATOR TO THE SCENE"
	create_btn.add_theme_font_size_override("font_size", 20)
	create_btn.custom_minimum_size = Vector2(500, 100)
	create_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	create_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	create_btn.pressed.connect(_on_create_pressed)
	add_child(create_btn)

	main_content = VBoxContainer.new()
	add_child(main_content)

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 15)
	main_content.add_child(top_hbox)

	var generate_btn = Button.new()
	generate_btn.text = "GENERATE DUNGEON"
	generate_btn.custom_minimum_size = Vector2(250, 40)
	generate_btn.pressed.connect(_on_generate)
	top_hbox.add_child(generate_btn)

	var clear_btn = Button.new()
	clear_btn.text = "CLEAR"
	clear_btn.custom_minimum_size = Vector2(100, 40)
	clear_btn.pressed.connect(_on_clear)
	top_hbox.add_child(clear_btn)

	status_label = Label.new()
	status_label.text = "Ready to generate!"
	status_label.modulate = Color(0.4, 1.0, 0.4)
	top_hbox.add_child(status_label)

	var tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_content.add_child(tabs)

	for tab_name in tabs_config.keys():
		var scroll = ScrollContainer.new()
		scroll.name = tab_name
		tabs.add_child(scroll)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(margin)
		
		var grid = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 10)
		margin.add_child(grid)
		
		for item in tabs_config[tab_name]:
			_create_ui_element(grid, item)

func _create_ui_element(grid: GridContainer, item: Dictionary) -> void:
	var lbl = Label.new()
	lbl.text = item["label"]
	lbl.custom_minimum_size = Vector2(200, 0)
	grid.add_child(lbl)

	var prop = item["prop"]
	
	if item["type"] == "scene":
		var picker = EditorResourcePicker.new()
		picker.base_type = "PackedScene"
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.custom_minimum_size = Vector2(250, 0)
		picker.resource_changed.connect(func(r): if current_generator: current_generator.set(prop, r))
		grid.add_child(picker)
		ui_elements[prop] = picker
		
	elif item["type"] == "int" or item["type"] == "float":
		var spin = SpinBox.new()
		if item["type"] == "float": spin.step = 0.01
		spin.min_value = item.get("min", -9999)
		spin.max_value = item.get("max", 9999)
		spin.value_changed.connect(func(v): if current_generator: current_generator.set(prop, v))
		grid.add_child(spin)
		ui_elements[prop] = spin
		
	elif item["type"] == "bool":
		var chk = CheckBox.new()
		chk.toggled.connect(func(v): if current_generator: current_generator.set(prop, v))
		grid.add_child(chk)
		ui_elements[prop] = chk
		
	elif item["type"] == "vec2i":
		var hbox = HBoxContainer.new()
		var bx = SpinBox.new(); bx.prefix = "X:"; bx.min_value = 0; bx.max_value = 999
		var by = SpinBox.new(); by.prefix = "Z:"; by.min_value = 0; by.max_value = 999
		var update_fn = func(_v): if current_generator: current_generator.set(prop, Vector2i(bx.value, by.value))
		bx.value_changed.connect(update_fn); by.value_changed.connect(update_fn)
		hbox.add_child(bx); hbox.add_child(by)
		grid.add_child(hbox)
		ui_elements[prop] = [bx, by]
		
	elif item["type"] == "vec3":
		var hbox = HBoxContainer.new()
		var bx = SpinBox.new(); bx.prefix = "X:"; bx.step = 0.1; bx.min_value = -999; bx.max_value = 999
		var by = SpinBox.new(); by.prefix = "Y:"; by.step = 0.1; by.min_value = -999; by.max_value = 999
		var bz = SpinBox.new(); bz.prefix = "Z:"; bz.step = 0.1; bz.min_value = -999; bz.max_value = 999
		var update_fn = func(_v): if current_generator: current_generator.set(prop, Vector3(bx.value, by.value, bz.value))
		bx.value_changed.connect(update_fn); by.value_changed.connect(update_fn); bz.value_changed.connect(update_fn)
		hbox.add_child(bx); hbox.add_child(by); hbox.add_child(bz)
		grid.add_child(hbox)
		ui_elements[prop] = [bx, by, bz]

func setup() -> void:
	editor_interface.get_selection().selection_changed.connect(_sync_ui_to_selection)
	_sync_ui_to_selection()

func _on_create_pressed() -> void:
	var root = editor_interface.get_edited_scene_root()
	if not root:
		status_label.text = "Open a 3D Scene first!"
		return

	var script_path = get_script().resource_path.get_base_dir() + "/multilevel_dungeon_generator.gd"
	var dg_script = load(script_path)

	var new_node = NavigationRegion3D.new()
	new_node.name = "DungeonGenerator"
	new_node.set_script(dg_script)
	root.add_child(new_node)
	new_node.owner = root

	editor_interface.get_selection().clear()
	editor_interface.get_selection().add_node(new_node)

func _sync_ui_to_selection() -> void:
	var nodes = editor_interface.get_selection().get_selected_nodes()
	current_generator = null
	for node in nodes:
		if node.has_method("generate_dungeon"):
			current_generator = node
			break
			
	if current_generator:
		create_btn.hide()
		main_content.show()
		status_label.text = "Ready to generate!"
		status_label.modulate = Color(0.4, 1.0, 0.4)
		
		for prop in ui_elements:
			var elem = ui_elements[prop]
			var val = current_generator.get(prop)
			
			if elem is EditorResourcePicker: elem.edited_resource = val
			elif elem is SpinBox: elem.value = val
			elif elem is CheckBox: elem.button_pressed = val
			elif elem is Array and elem.size() == 2:
				elem[0].value = val.x; elem[1].value = val.y
			elif elem is Array and elem.size() == 3:
				elem[0].value = val.x; elem[1].value = val.y; elem[2].value = val.z
	else:
		create_btn.show()
		main_content.hide()

func _on_generate() -> void:
	if current_generator:
		var result = current_generator.generate_dungeon()
		if result == "SUCCESS":
			status_label.text = "Built %d levels successfully!" % current_generator.num_levels
			status_label.modulate = Color(0.4, 1.0, 0.4)
			_sync_ui_to_selection() # <--- Pushes the Random Seed back to the UI!
		else:
			status_label.text = result
			status_label.modulate = Color(1.0, 0.4, 0.4)

func _on_clear() -> void:
	if current_generator:
		for child in current_generator.get_children():
			if child.name != "NavigationMesh": child.free()
		status_label.text = "Dungeon Cleared."
