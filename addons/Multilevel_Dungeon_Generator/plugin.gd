@tool
extends EditorPlugin

var dock_panel: Control

func _enter_tree() -> void:
	var panel_script = preload("dungeon_panel.gd")
	dock_panel = panel_script.new()
	add_control_to_bottom_panel(dock_panel, "Dungeon Gen")
	
	# Give the panel access to the Godot Editor so it can automatically select nodes
	dock_panel.editor_interface = get_editor_interface()
	dock_panel.setup()

func _exit_tree() -> void:
	if dock_panel:
		remove_control_from_bottom_panel(dock_panel)
		dock_panel.free()
