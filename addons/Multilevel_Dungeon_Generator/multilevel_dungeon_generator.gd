@tool
class_name DungeonGenerator
extends NavigationRegion3D

signal dungeon_generated(levels: Array)

# ==========================================
# EXPORTED VARIABLES (HIDDEN FROM INSPECTOR)
# ==========================================

@export var floor_scene: PackedScene
@export var ceiling_straight: PackedScene
@export var ceiling_corner: PackedScene
@export var ceiling_3way: PackedScene
@export var ceiling_4way: PackedScene
@export var ceiling_end: PackedScene

@export var alt_theme_start_level: int = 5
@export var alt_floor_scene: PackedScene
@export var alt_wall_solid: PackedScene
@export var alt_wall_doorway: PackedScene

@export var ceiling_straight_rot_offset: float = 0.0
@export var ceiling_corner_rot_offset: float = 0.0
@export var ceiling_3way_rot_offset: float = 0.0
@export var ceiling_end_rot_offset: float = 0.0

@export var wall_solid: PackedScene
@export var wall_window: PackedScene
@export var wall_jail: PackedScene
@export var wall_doorway: PackedScene

@export var pillar_corner: PackedScene
@export var pillar_round_scene: PackedScene

@export var torch_scene: PackedScene
@export var chest_scene: PackedScene
@export var debris_scene: PackedScene

@export var tile_size: float = 4.0
@export var ceiling_height: float = 3.0
@export var grid_width: int = 21
@export var grid_height: int = 21

@export var use_fixed_seed: bool = false
@export var seed_value: int = 0
var last_generated_seed: int = 0

@export var num_rooms: int = 12
@export var max_room_placement_attempts: int = 300
@export var room_min_size: Vector2i = Vector2i(3, 3)
@export var room_max_size: Vector2i = Vector2i(7, 7)
@export var room_padding: int = 1
@export var alcove_chance: float = 0.35
@export var alcove_min_size: Vector2i = Vector2i(2, 2)
@export var alcove_max_size: Vector2i = Vector2i(3, 3)

@export var use_mst_connections: bool = true
@export var corridor_axis_flip_chance: float = 0.5
@export var loop_chance: float = 0.12
@export var dead_end_chance: float = 0.04
@export var dead_end_min_length: int = 2
@export var dead_end_max_length: int = 4

@export var generate_navmesh: bool = true
@export var spawn_torches: bool = true
@export var spawn_chests: bool = true
@export var spawn_debris: bool = true

@export var num_levels: int = 1
@export var level_height: float = 5.0
@export var num_staircases: int = 1
@export var stairs_scene: PackedScene

@export var stairs_position_offset: Vector3 = Vector3.ZERO
@export var stairs_rotation_offset: Vector3 = Vector3.ZERO
@export var guarantee_tower_access: bool = true

@export var torch_chance: float = 0.15
@export var debris_chance: float = 0.12

@export var floor_offset: Vector3 = Vector3(-1.0, 0.0, -1.0)
@export var wall_offset: Vector3 = Vector3.ZERO
@export var ceiling_offset: Vector3 = Vector3.ZERO
@export var wall_rotation_offset_deg: float = 90.0

func _validate_property(property: Dictionary) -> void:
	if property.name in ["floor_scene", "ceiling_straight", "ceiling_corner", "ceiling_3way", "ceiling_4way", "ceiling_end", "alt_theme_start_level", "alt_floor_scene", "alt_wall_solid", "alt_wall_doorway", "ceiling_straight_rot_offset", "ceiling_corner_rot_offset", "ceiling_3way_rot_offset", "ceiling_end_rot_offset", "wall_solid", "wall_window", "wall_jail", "wall_doorway", "pillar_corner", "pillar_round_scene", "torch_scene", "chest_scene", "debris_scene", "tile_size", "ceiling_height", "grid_width", "grid_height", "use_fixed_seed", "seed_value", "num_rooms", "max_room_placement_attempts", "room_min_size", "room_max_size", "room_padding", "alcove_chance", "alcove_min_size", "alcove_max_size", "use_mst_connections", "corridor_axis_flip_chance", "loop_chance", "dead_end_chance", "dead_end_min_length", "dead_end_max_length", "generate_navmesh", "spawn_torches", "spawn_chests", "spawn_debris", "num_levels", "level_height", "num_staircases", "stairs_scene", "stairs_position_offset", "stairs_rotation_offset", "guarantee_tower_access", "torch_chance", "debris_chance", "floor_offset", "wall_offset", "ceiling_offset", "wall_rotation_offset_deg"]:
		property.usage = PROPERTY_USAGE_STORAGE

var grid: Array = []
var rooms: Array = []
var used_door_cells: Dictionary = {}
var levels: Array = []

func generate_dungeon() -> String:
	if not floor_scene: return "ERROR: Please assign 'Floor' in 3D Models Tab!"
	if not wall_solid: return "ERROR: Please assign 'Wall (Solid)' in 3D Models Tab!"
	if num_levels > 1 and not stairs_scene: return "ERROR: Multi-Level needs 'Stairs 2x2' assigned!"

	for child in get_children():
		if child.name == "NavigationMesh": continue
		if Engine.is_editor_hint(): child.free()
		else: child.queue_free()

	var rng = RandomNumberGenerator.new()
	if use_fixed_seed: 
		rng.seed = seed_value
	else: 
		rng.randomize()
		seed_value = rng.seed 
	last_generated_seed = rng.seed

	var global_stair_cells: Array = []
	var placement_attempts = 0
	while global_stair_cells.size() < num_staircases and placement_attempts < 1000:
		placement_attempts += 1
		var tx = rng.randi_range(3, grid_width - 6)
		var ty = rng.randi_range(3, grid_height - 6)
		
		var overlap = false
		var padding_rect = Rect2i(tx - 3, ty - 3, 8, 8)
		for sc in global_stair_cells:
			var other_rect = Rect2i(sc.x - 3, sc.y - 3, 8, 8)
			if padding_rect.intersects(other_rect): 
				overlap = true; break
		
		if not overlap: global_stair_cells.append(Vector2i(tx, ty))

	levels.clear()
	for i in range(num_levels):
		var level_dict = generate_labyrinth_grid(rng, global_stair_cells)
		levels.append(level_dict)

	for i in range(num_levels):
		var container = Node3D.new()
		container.name = "Level_%d" % i
		add_child(container)
		if Engine.is_editor_hint(): container.owner = get_tree().edited_scene_root
		container.position = Vector3(0, i * level_height, 0)
		used_door_cells.clear()
		build_level(container, levels[i], i, rng)

	if levels.size() > 0: grid = levels[0].grid

	if generate_navmesh:
		if not self.navigation_mesh:
			var nav = NavigationMesh.new()
			nav.agent_radius = 0.6
			nav.agent_max_climb = 0.35
			nav.agent_max_slope = 50.0
			self.navigation_mesh = nav
		var use_background_thread = not Engine.is_editor_hint()
		self.bake_navigation_mesh(use_background_thread)
	else:
		self.navigation_mesh = null

	dungeon_generated.emit(levels)
	return "SUCCESS"

# --- CORE MATH AND GENERATION ---

func generate_labyrinth_grid(rng: RandomNumberGenerator, stair_cells: Array) -> Dictionary:
	if grid_width  % 2 == 0: grid_width  += 1
	if grid_height % 2 == 0: grid_height += 1

	var g: Array = []
	g.resize(grid_height)
	for r in range(grid_height):
		g[r] = []; g[r].resize(grid_width); g[r].fill(0)

	for sc in stair_cells:
		for tr in range(sc.y, sc.y + 2):
			for tc in range(sc.x, sc.x + 2):
				if tr >= 0 and tr < grid_height and tc >= 0 and tc < grid_width:
					g[tr][tc] = 3

	rooms.clear()
	var placed   = 0
	var attempts = 0

	while placed < num_rooms and attempts < max_room_placement_attempts:
		attempts += 1
		var w = rng.randi_range(room_min_size.x, room_max_size.x)
		var h = rng.randi_range(room_min_size.y, room_max_size.y)
		if w + 2 > grid_width or h + 2 > grid_height: continue

		var x = (rng.randi_range(1, grid_width  - w - 1) / 2) * 2 + 1
		var y = (rng.randi_range(1, grid_height - h - 1) / 2) * 2 + 1
		var nr = Rect2i(x, y, w, h)

		var overlaps = false
		for sc in stair_cells:
			var tower_rect = Rect2i(sc.x - 1, sc.y - 1, 4, 4)
			if nr.intersects(tower_rect): overlaps = true; break
		if overlaps: continue

		for er in rooms:
			if nr.intersects(er.grow(room_padding)): overlaps = true; break
		if overlaps: continue

		rooms.append(nr); placed += 1
		for ry in range(y, y + h):
			for rx in range(x, x + w):
				if ry < grid_height and rx < grid_width: g[ry][rx] = 1

		if rng.randf() < alcove_chance:
			var sw = rng.randi_range(alcove_min_size.x, alcove_max_size.x)
			var sh = rng.randi_range(alcove_min_size.y, alcove_max_size.y)
			var sx = x + rng.randi_range(-1, w - 1)
			var sy = y + rng.randi_range(-1, h - 1)
			for ry in range(sy, sy + sh):
				for rx in range(sx, sx + sw):
					if ry > 0 and ry < grid_height - 1 and rx > 0 and rx < grid_width - 1:
						if g[ry][rx] != 3: g[ry][rx] = 1

	if rooms.size() > 1:
		if use_mst_connections: connect_rooms_mst(g, rng)
		else:
			for i in range(rooms.size() - 1):
				carve_corridor_L(g, rooms[i].get_center(), rooms[i+1].get_center(), rng)
		for i in range(rooms.size()):
			if rng.randf() < loop_chance:
				var t = rng.randi() % rooms.size()
				if t != i: carve_corridor_L(g, rooms[i].get_center(), rooms[t].get_center(), rng)

	if guarantee_tower_access and rooms.size() > 0:
		for sc in stair_cells:
			var tower_center = Vector2i(sc.x + 1, sc.y + 1)
			var best_dist = INF
			var best_room = rooms[0]
			for room in rooms:
				var d = room.get_center().distance_squared_to(tower_center)
				if d < best_dist: best_dist = d; best_room = room
			carve_corridor_L(g, tower_center, best_room.get_center(), rng)
		
		for sc in stair_cells:
			for tr in range(sc.y, sc.y + 2):
				for tc in range(sc.x, sc.x + 2):
					if tr >= 0 and tr < grid_height and tc >= 0 and tc < grid_width: g[tr][tc] = 3

	for r in range(2, grid_height - 2):
		for c in range(2, grid_width - 2):
			if g[r][c] == 2 and rng.randf() < dead_end_chance:
				var dirs = [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]
				var dir  = dirs[rng.randi() % 4]
				var len  = rng.randi_range(dead_end_min_length, dead_end_max_length)
				var cell = Vector2i(c, r); var path: Array = []; var ok = true
				for _s in range(len):
					cell += dir
					if cell.x <= 0 or cell.x >= grid_width - 1 or cell.y <= 0 or cell.y >= grid_height - 1 or g[cell.y][cell.x] != 0:
						ok = false; break
					path.append(cell)
				if ok:
					for p in path: g[p.y][p.x] = 2

	return {"grid": g, "rooms": rooms.duplicate(), "stair_cells": stair_cells}

func carve_corridor_L(grid_ref: Array, start: Vector2i, end: Vector2i, rng: RandomNumberGenerator) -> void:
	var x_first = rng.randf() < corridor_axis_flip_chance
	var corner  = Vector2i(end.x, start.y) if x_first else Vector2i(start.x, end.y)
	_carve_segment(grid_ref, start, corner)
	_carve_segment(grid_ref, corner, end)

func _carve_segment(grid_ref: Array, a: Vector2i, b: Vector2i) -> void:
	var x = a.x; var y = a.y
	var dx = sign(b.x - a.x); var dy = sign(b.y - a.y)
	while Vector2i(x, y) != b:
		if x > 0 and x < grid_width - 1 and y > 0 and y < grid_height - 1:
			if grid_ref[y][x] == 0: grid_ref[y][x] = 2
		x += dx; y += dy
	if b.x > 0 and b.x < grid_width - 1 and b.y > 0 and b.y < grid_height - 1:
		if grid_ref[b.y][b.x] == 0: grid_ref[b.y][b.x] = 2

func connect_rooms_mst(grid_ref: Array, rng: RandomNumberGenerator) -> void:
	var connected = [0]; var remaining: Array = []
	for i in range(1, rooms.size()): remaining.append(i)
	while remaining.size() > 0:
		var bd = INF; var bci = -1; var bri = -1
		for ci in connected:
			for ri in remaining:
				var d = rooms[ci].get_center().distance_squared_to(rooms[ri].get_center())
				if d < bd: bd = d; bci = ci; bri = ri
		carve_corridor_L(grid_ref, rooms[bci].get_center(), rooms[bri].get_center(), rng)
		connected.append(bri); remaining.erase(bri)

# --- LEVEL BUILDING AND WALL LOGIC ---

func build_level(parent: Node3D, level_data: Dictionary, level_index: int, rng: RandomNumberGenerator) -> void:
	var grid_ref             = level_data.grid
	var stair_cells: Array   = level_data.stair_cells
	var half                 = tile_size / 2.0
	var rot_off              = deg_to_rad(wall_rotation_offset_deg)

	var has_stairs_above = (level_index < num_levels - 1) and (stairs_scene != null)
	var has_stairs_below = (level_index > 0)
	var tower_place_ceiling = (not has_stairs_above)

	var tower_cells: Array = []
	for sc in stair_cells:
		for tr in range(sc.y, sc.y + 2):
			for tc in range(sc.x, sc.x + 2):
				tower_cells.append(Vector2i(tc, tr))

	var _f_off = floor_offset if typeof(floor_offset) == TYPE_VECTOR3 else Vector3.ZERO
	
	var cur_floor = floor_scene
	var cur_wall = wall_solid
	var cur_door = wall_doorway
	if (level_index + 1) >= alt_theme_start_level and alt_floor_scene and alt_wall_solid:
		cur_floor = alt_floor_scene
		cur_wall = alt_wall_solid
		if alt_wall_doorway: cur_door = alt_wall_doorway
	
	for r in range(grid_height):
		for c in range(grid_width):
			var v    = grid_ref[r][c]
			if v < 1: continue

			var x_pos    = c * tile_size
			var z_pos    = r * tile_size
			var cell     = Vector2i(c, r)
			var is_tower = (v == 3)

			var spawn_floor = not is_tower
			if is_tower:
				spawn_floor = true 
				if has_stairs_below:
					var hole_local_x = 0; var hole_local_y = 0
					if (level_index - 1) % 2 != 0: hole_local_x = 1; hole_local_y = 1
					for sc in stair_cells:
						if c == sc.x + hole_local_x and r == sc.y + hole_local_y:
							spawn_floor = false
							break

			if spawn_floor:
				var fi = cur_floor.instantiate() as Node3D
				fi.name = "Floor"
				parent.add_child(fi)
				if Engine.is_editor_hint(): fi.owner = get_tree().edited_scene_root
				fi.position = Vector3(x_pos, 0, z_pos) + _f_off

			var spawn_ceil = (not is_tower) or tower_place_ceiling
			if spawn_ceil:
				if is_tower and tower_place_ceiling: spawn_tower_cap_ceiling(parent, x_pos, z_pos)
				else: spawn_vaulted_ceiling(parent, grid_ref, r, c, x_pos, z_pos)

			var wn = (r - 1 < 0 or grid_ref[r-1][c] == 0)
			var ws = (r + 1 >= grid_height or grid_ref[r+1][c] == 0)
			var we = (c + 1 >= grid_width or grid_ref[r][c+1] == 0)
			var ww = (c - 1 < 0 or grid_ref[r][c-1] == 0)

			if v == 1 and not is_tower:
				if r - 1 >= 0 and grid_ref[r-1][c] == 2:
					if _can_place_door(Vector2i(c, r-1), tower_cells, rng):
						spawn_door_model(parent, cur_door, Vector3(x_pos, 0, z_pos - half), deg_to_rad(180) + rot_off)
					else: wn = true
					
				if r + 1 < grid_height and grid_ref[r+1][c] == 2:
					if _can_place_door(Vector2i(c, r+1), tower_cells, rng):
						spawn_door_model(parent, cur_door, Vector3(x_pos, 0, z_pos + half), deg_to_rad(0)   + rot_off)
					else: ws = true
					
				if c + 1 < grid_width  and grid_ref[r][c+1] == 2:
					if _can_place_door(Vector2i(c+1, r), tower_cells, rng):
						spawn_door_model(parent, cur_door, Vector3(x_pos + half, 0, z_pos), deg_to_rad(90)  + rot_off)
					else: we = true
					
				if c - 1 >= 0 and grid_ref[r][c-1] == 2:
					if _can_place_door(Vector2i(c-1, r), tower_cells, rng):
						spawn_door_model(parent, cur_door, Vector3(x_pos - half, 0, z_pos), deg_to_rad(270) + rot_off)
					else: ww = true

			if wn: spawn_boundary_wall(parent, cur_wall, Vector3(x_pos, 0, z_pos - half), deg_to_rad(180) + rot_off, Vector3(0, 0, 1),  rng)
			if ws: spawn_boundary_wall(parent, cur_wall, Vector3(x_pos, 0, z_pos + half), deg_to_rad(0)   + rot_off, Vector3(0, 0,-1),  rng)
			if we: spawn_boundary_wall(parent, cur_wall, Vector3(x_pos + half, 0, z_pos), deg_to_rad(90)  + rot_off, Vector3(-1, 0, 0), rng)
			if ww: spawn_boundary_wall(parent, cur_wall, Vector3(x_pos - half, 0, z_pos), deg_to_rad(270) + rot_off, Vector3(1, 0, 0),  rng)

			if pillar_corner and not is_tower:
				if wn and we: spawn_pillar(parent, Vector3(x_pos + half, 0, z_pos - half), deg_to_rad(0))
				if wn and ww: spawn_pillar(parent, Vector3(x_pos - half, 0, z_pos - half), deg_to_rad(90))
				if ws and we: spawn_pillar(parent, Vector3(x_pos + half, 0, z_pos + half), deg_to_rad(270))
				if ws and ww: spawn_pillar(parent, Vector3(x_pos - half, 0, z_pos + half), deg_to_rad(180))

	if has_stairs_above: 
		for sc in stair_cells:
			spawn_stairs(parent, grid_ref, sc, level_index)
			
	spawn_room_support_pillars(parent, grid_ref, tower_cells)
	place_dungeon_props(parent, grid_ref, rng, tower_cells)

# --- HELPER FUNCTIONS ---

func _can_place_door(corr_coord: Vector2i, tower_cells: Array, rng: RandomNumberGenerator) -> bool:
	if not wall_doorway and not alt_wall_doorway: return false
	if corr_coord in tower_cells: return false
	var blocked = used_door_cells.has(corr_coord) or used_door_cells.has(corr_coord + Vector2i(1,0)) or used_door_cells.has(corr_coord + Vector2i(-1,0)) or used_door_cells.has(corr_coord + Vector2i(0,1)) or used_door_cells.has(corr_coord + Vector2i(0,-1))
	if blocked or rng.randf() < 0.2: return false
	used_door_cells[corr_coord] = true
	return true

func spawn_door_model(parent: Node3D, chosen_wall: PackedScene, pos: Vector3, rot_y: float) -> void:
	if not chosen_wall: return
	var inst = chosen_wall.instantiate() as Node3D
	inst.name = "Doorway"
	parent.add_child(inst)
	if Engine.is_editor_hint(): inst.owner = get_tree().edited_scene_root
	var _w_off = wall_offset if typeof(wall_offset) == TYPE_VECTOR3 else Vector3.ZERO
	inst.position   = pos + _w_off
	inst.rotation.y = rot_y

func spawn_tower_cap_ceiling(parent: Node3D, x_pos: float, z_pos: float) -> void:
	var asset = ceiling_4way if ceiling_4way else (ceiling_straight if ceiling_straight else null)
	if not asset: return
	var inst = asset.instantiate() as Node3D
	inst.name = "Ceiling"
	parent.add_child(inst)
	if Engine.is_editor_hint(): inst.owner = get_tree().edited_scene_root
	var _f_off = floor_offset if typeof(floor_offset) == TYPE_VECTOR3 else Vector3.ZERO
	var _c_off = ceiling_offset if typeof(ceiling_offset) == TYPE_VECTOR3 else Vector3.ZERO
	inst.position = Vector3(x_pos, ceiling_height, z_pos) + _f_off + _c_off

func spawn_stairs(parent: Node3D, grid_ref: Array, stair_cell: Vector2i, level_index: int) -> void:
	var inst = stairs_scene.instantiate() as Node3D
	inst.name = "Stairs"
	parent.add_child(inst)
	if Engine.is_editor_hint(): inst.owner = get_tree().edited_scene_root

	var tx = stair_cell.x; var ty = stair_cell.y
	var local_x = 0; var local_y = 0
	if level_index % 2 != 0: local_x = 1; local_y = 1 

	inst.position = Vector3((tx + local_x) * tile_size, 0.0, (ty + local_y) * tile_size) + stairs_position_offset

	var open_dir = Vector3.ZERO
	var edge_checks = [
		[Vector2i(tx,   ty-1), Vector3( 0, 0,-1)], [Vector2i(tx+1, ty-1), Vector3( 0, 0,-1)], 
		[Vector2i(tx,   ty+2), Vector3( 0, 0, 1)], [Vector2i(tx+1, ty+2), Vector3( 0, 0, 1)], 
		[Vector2i(tx+2, ty  ), Vector3( 1, 0, 0)], [Vector2i(tx+2, ty+1), Vector3( 1, 0, 0)], 
		[Vector2i(tx-1, ty  ), Vector3(-1, 0, 0)], [Vector2i(tx-1, ty+1), Vector3(-1, 0, 0)], 
	]
	for ch in edge_checks:
		var cell: Vector2i = ch[0]
		if cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height:
			if grid_ref[cell.y][cell.x] >= 1:
				open_dir = ch[1]; break

	if open_dir != Vector3.ZERO: inst.rotation.y = atan2(open_dir.x, open_dir.z)
	if level_index % 2 != 0: inst.rotation_degrees.y += 180.0
	inst.rotation_degrees += stairs_rotation_offset

func spawn_boundary_wall(parent: Node3D, chosen_wall: PackedScene, pos: Vector3, rot_y: float, normal: Vector3, rng: RandomNumberGenerator) -> void:
	if not chosen_wall: return
	var scn  = chosen_wall
	var roll = rng.randf()
	if   roll < 0.15 and wall_window: scn = wall_window
	elif roll < 0.30 and wall_jail:   scn = wall_jail

	var inst = scn.instantiate() as Node3D
	inst.name = "Wall"
	parent.add_child(inst)
	if Engine.is_editor_hint(): inst.owner = get_tree().edited_scene_root
	var _w_off = wall_offset if typeof(wall_offset) == TYPE_VECTOR3 else Vector3.ZERO
	inst.position   = pos + _w_off
	inst.rotation.y = rot_y
	
	if spawn_torches and rng.randf() < torch_chance: spawn_torch(parent, pos, normal)

# --- PURE INTEGER CEILING ROTATION ALGORITHM ---

func spawn_vaulted_ceiling(parent: Node3D, grid_ref: Array, r: int, c: int, x_pos: float, z_pos: float) -> void:
	var n  = (r - 1 >= 0         and grid_ref[r-1][c] >= 1)
	var s  = (r + 1 < grid_height and grid_ref[r+1][c] >= 1)
	var e  = (c + 1 < grid_width  and grid_ref[r][c+1] >= 1)
	var w  = (c - 1 >= 0         and grid_ref[r][c-1] >= 1)
	var oc = int(n) + int(s) + int(e) + int(w)

	var asset: PackedScene = null
	var rot_extra          = 0.0
	if   oc == 4: asset = ceiling_4way
	elif oc == 3: asset = ceiling_3way;   rot_extra = ceiling_3way_rot_offset
	elif oc == 2:
		if (n and s) or (e and w): asset = ceiling_straight; rot_extra = ceiling_straight_rot_offset
		else:                       asset = ceiling_corner;   rot_extra = ceiling_corner_rot_offset
	elif oc == 1: asset = ceiling_end;    rot_extra = ceiling_end_rot_offset
	elif oc == 0: asset = ceiling_4way # Fallback to prevent isolated voids
	
	if not asset: return

	var inst = asset.instantiate() as Node3D
	inst.name = "Ceiling"
	parent.add_child(inst)
	if Engine.is_editor_hint(): inst.owner = get_tree().edited_scene_root
	var _f_off = floor_offset if typeof(floor_offset) == TYPE_VECTOR3 else Vector3.ZERO
	var _c_off = ceiling_offset if typeof(ceiling_offset) == TYPE_VECTOR3 else Vector3.ZERO
	inst.position = Vector3(x_pos, ceiling_height, z_pos) + _f_off + _c_off

	# Create a strict 2D Integer Array of the Required Map Openings
	var req: Array[Vector2i] = []
	if n: req.append(Vector2i(0, -1))
	if s: req.append(Vector2i(0, 1))
	if e: req.append(Vector2i(1, 0))
	if w: req.append(Vector2i(-1, 0))

	var local_dirs = _get_roof_marker_dirs(inst)
	inst.rotation.y = _find_best_rotation(local_dirs, req) + deg_to_rad(rot_extra)

func _get_roof_marker_dirs(inst: Node3D) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	var m = inst.find_child("RoofMarkers", true, false)
	if not m: return dirs
	
	# Fetch marker coordinates and map them strictly to pure 2D Integers
	for ch in m.get_children():
		if "position" in ch:
			var p = ch.position
			if abs(p.x) > abs(p.z): dirs.append(Vector2i(sign(p.x), 0))
			else: dirs.append(Vector2i(0, sign(p.z)))
	return dirs

func _find_best_rotation(local_dirs: Array[Vector2i], req: Array[Vector2i]) -> float:
	if local_dirs.is_empty() or req.is_empty(): return 0.0

	var angles = [0.0, 90.0, 180.0, 270.0]
	
	# Loop through all 4 possible 90-degree rotations
	for i in range(4):
		var hits = 0
		for d in local_dirs:
			var rd = d
			
			# Mathematically rotate the integer Vector exactly 90 degrees 'i' times!
			# No Floating Point Math Allowed!
			for step in range(i):
				rd = Vector2i(rd.y, -rd.x)
				
			if req.has(rd):
				hits += 1
				
		# If the markers EXACTLY match every single opening on the map:
		if hits == req.size() and hits == local_dirs.size():
			return deg_to_rad(angles[i])

	return 0.0

# --- PROPS ---

func spawn_room_support_pillars(parent: Node3D, grid_ref: Array, tower_cells: Array) -> void:
	if not pillar_round_scene: return
	for r in range(1, grid_height):
		for c in range(1, grid_width):
			var skip = false
			for sc in tower_cells:
				if Vector2i(c-1,r-1) == sc or Vector2i(c,r-1) == sc or Vector2i(c-1,r) == sc or Vector2i(c,r) == sc:
					skip = true; break
			if skip: continue
			
			if grid_ref[r-1][c-1] >= 1 and grid_ref[r-1][c] >= 1 and grid_ref[r][c-1] >= 1 and grid_ref[r][c] >= 1:
				var p = pillar_round_scene.instantiate() as Node3D
				p.name = "Pillar"
				parent.add_child(p)
				if Engine.is_editor_hint(): p.owner = get_tree().edited_scene_root
				var _w_off = wall_offset if typeof(wall_offset) == TYPE_VECTOR3 else Vector3.ZERO
				p.position = Vector3(c * tile_size - tile_size * 0.5, 0, r * tile_size - tile_size * 0.5) + _w_off

func spawn_pillar(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	if not pillar_corner: return
	var p = pillar_corner.instantiate() as Node3D
	p.name = "Pillar"
	parent.add_child(p)
	if Engine.is_editor_hint(): p.owner = get_tree().edited_scene_root
	var _w_off = wall_offset if typeof(wall_offset) == TYPE_VECTOR3 else Vector3.ZERO
	p.position = pos + _w_off; p.rotation.y = rot_y

func spawn_torch(parent: Node3D, pos: Vector3, norm: Vector3) -> void:
	if not torch_scene: return 
	var t = torch_scene.instantiate() as Node3D
	t.name = "Torch"
	parent.add_child(t)
	if Engine.is_editor_hint(): t.owner = get_tree().edited_scene_root
	var _w_off = wall_offset if typeof(wall_offset) == TYPE_VECTOR3 else Vector3.ZERO
	t.position = pos + (norm * 0.15) + Vector3(0, 1.8, 0) + _w_off
	if norm != Vector3.ZERO: t.rotation.y = atan2(-norm.x, -norm.z)
	
	var l = OmniLight3D.new()
	l.light_color = Color(1, 0.55, 0.2); l.light_energy = 2.0; l.omni_range = 8.0; l.shadow_enabled = true; l.position = Vector3(0, 0.2, 0.1)
	t.add_child(l)
	if Engine.is_editor_hint(): l.owner = get_tree().edited_scene_root

func place_dungeon_props(parent: Node3D, grid_ref: Array, rng: RandomNumberGenerator, tower_cells: Array) -> void:
	for r in range(1, grid_height - 1):
		for c in range(1, grid_width - 1):
			if grid_ref[r][c] < 1: continue
			
			var skip = false
			for sc in tower_cells:
				if Vector2i(c, r) == sc: skip = true; break
			if skip: continue
			
			var wc = int(grid_ref[r-1][c]==0)+int(grid_ref[r+1][c]==0)+int(grid_ref[r][c-1]==0)+int(grid_ref[r][c+1]==0)
			var od = Vector3.ZERO
			if grid_ref[r-1][c] != 0: od = Vector3(0,0,-1)
			elif grid_ref[r+1][c] != 0: od = Vector3(0,0, 1)
			elif grid_ref[r][c-1] != 0: od = Vector3(-1,0,0)
			elif grid_ref[r][c+1] != 0: od = Vector3(1,0,0)

			if spawn_chests and wc == 3 and chest_scene:
				var ch = chest_scene.instantiate() as Node3D
				ch.name = "Chest"
				parent.add_child(ch)
				if Engine.is_editor_hint(): ch.owner = get_tree().edited_scene_root
				var _f_off = floor_offset if typeof(floor_offset) == TYPE_VECTOR3 else Vector3.ZERO
				ch.position = Vector3(c * tile_size, 0, r * tile_size) + _f_off
				if od != Vector3.ZERO: ch.rotation.y = atan2(od.x, od.z) 
				
			elif spawn_debris and rng.randf() < debris_chance and debris_scene:
				var d = debris_scene.instantiate() as Node3D
				d.name = "Debris"
				parent.add_child(d)
				if Engine.is_editor_hint(): d.owner = get_tree().edited_scene_root
				var _f_off = floor_offset if typeof(floor_offset) == TYPE_VECTOR3 else Vector3.ZERO
				d.position = Vector3(c * tile_size, 0, r * tile_size) + _f_off + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
				d.rotation.y = rng.randf_range(0.0, TAU)

# --- HELPERS ---
func get_level_count() -> int: return levels.size()
func set_level_visible(level_index: int, is_visible: bool) -> void:
	var n = get_node_or_null("Level_%d" % level_index)
	if n: n.visible = is_visible
func get_room_world_centers(level_index: int = 0) -> Array:
	if level_index < 0 or level_index >= levels.size(): return []
	var y_off = level_index * level_height
	var out: Array = []
	for room in levels[level_index].rooms:
		var ctr = room.get_center()
		out.append(Vector3(ctr.x * tile_size, y_off, ctr.y * tile_size) + floor_offset)
	return out

func get_stair_world_positions(level_index: int = 0) -> Array[Vector3]:
	if level_index < 0 or level_index >= levels.size(): return []
	var t_cells = levels[level_index].stair_cells
	var local_x = 0; var local_z = 0
	if level_index % 2 != 0: local_x = 1; local_z = 1
	var out: Array[Vector3] = []
	for tc in t_cells:
		out.append(Vector3((tc.x + local_x) * tile_size, level_index * level_height, (tc.y + local_z) * tile_size) + floor_offset)
	return out

func get_random_floor_world_position(level_index: int = 0, rng_in: RandomNumberGenerator = null) -> Vector3:
	if level_index < 0 or level_index >= levels.size(): return Vector3.ZERO
	var lr = rng_in if rng_in else RandomNumberGenerator.new()
	if not rng_in: lr.randomize()
	var gr = levels[level_index].grid
	var sc = levels[level_index].stair_cells
	var tc: Array = []
	for s in sc:
		for tr in range(s.y, s.y + 2):
			for tcc in range(s.x, s.x + 2): tc.append(Vector2i(tcc, tr))
	var cells: Array = []
	for r in range(grid_height):
		for c in range(grid_width):
			if gr[r][c] >= 1 and not (Vector2i(c, r) in tc): cells.append(Vector2i(c, r))
	if cells.is_empty(): return Vector3.ZERO
	var pick = cells[lr.randi() % cells.size()]
	return Vector3(pick.x * tile_size, level_index * level_height, pick.y * tile_size) + floor_offset
