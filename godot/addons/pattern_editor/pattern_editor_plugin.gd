@tool
extends EditorPlugin

const MAIN_SCRIPT = preload("res://scripts/main.gd")
const LAYOUT_DOCK_SCRIPT = preload("res://addons/pattern_editor/shared_grid_editor_dock.gd")
const PATTERN_DOCK_SCRIPT = preload("res://addons/pattern_editor/stitch_pattern_editor_dock.gd")

var layout_dock: Control
var pattern_dock: Control
var target: Node

func _enter_tree() -> void:
	layout_dock = LAYOUT_DOCK_SCRIPT.new()
	layout_dock.name = "布局编辑器"
	layout_dock.layout_apply_requested.connect(_on_layout_apply_requested)
	layout_dock.level_list_change_requested.connect(_on_level_list_change_requested)
	layout_dock.level_files_change_requested.connect(_on_level_files_change_requested)
	layout_dock.level_selected.connect(_on_layout_level_selected)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, layout_dock)
	pattern_dock = PATTERN_DOCK_SCRIPT.new()
	pattern_dock.name = "编制区域编辑器"
	pattern_dock.pattern_apply_requested.connect(_on_pattern_apply_requested)
	pattern_dock.level_selected.connect(_on_pattern_level_selected)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, pattern_dock)
	layout_dock.set_target(null)
	pattern_dock.set_target(null)

func _exit_tree() -> void:
	if layout_dock:
		remove_control_from_docks(layout_dock)
		layout_dock.queue_free()
	if pattern_dock:
		remove_control_from_docks(pattern_dock)
		pattern_dock.queue_free()
	layout_dock = null
	pattern_dock = null
	target = null

func _handles(object: Object) -> bool:
	return object is Node and object.get_script() == MAIN_SCRIPT

func _edit(object: Object) -> void:
	target = object as Node
	if layout_dock:
		layout_dock.set_target(target)
	if pattern_dock:
		pattern_dock.set_target(target)

func _make_visible(visible: bool) -> void:
	if layout_dock:
		layout_dock.visible = visible
	if pattern_dock:
		pattern_dock.visible = visible

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not is_instance_valid(target) or not is_instance_valid(layout_dock):
		return false
	if not target.has_method("editor_shared_grid_cell_at_point"):
		return false
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return false
	var local_position: Vector2 = target.get_global_transform_with_canvas().affine_inverse() * event.position
	return layout_dock.handle_scene_canvas_input(local_position, event)

func _on_layout_apply_requested(level_index: int, level_name: String, layout_grid_size: Vector2i, game_grid_layout: String, belt_grid_position: Vector2i, belt_grid_size: Vector2i) -> void:
	if not is_instance_valid(target):
		return
	var configured_levels: Array = target.get("level_configs")
	if level_index >= configured_levels.size() and level_index >= 0:
		return
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("编辑布局网格")
	if level_index >= 0:
		var level: StitchLevelPattern = configured_levels[level_index]
		undo_redo.add_do_property(level, "level_name", level_name)
		undo_redo.add_do_property(level, "layout_grid_size", layout_grid_size)
		undo_redo.add_do_property(level, "game_grid_layout", game_grid_layout)
		undo_redo.add_do_property(level, "belt_grid_position", belt_grid_position)
		undo_redo.add_do_property(level, "belt_grid_size", belt_grid_size)
		undo_redo.add_do_property(level, "layout_configured", true)
		undo_redo.add_undo_property(level, "level_name", str(level.get("level_name")))
		undo_redo.add_undo_property(level, "layout_grid_size", level.get("layout_grid_size"))
		undo_redo.add_undo_property(level, "game_grid_layout", str(level.get("game_grid_layout")))
		undo_redo.add_undo_property(level, "belt_grid_position", level.get("belt_grid_position"))
		undo_redo.add_undo_property(level, "belt_grid_size", level.get("belt_grid_size"))
		undo_redo.add_undo_property(level, "layout_configured", bool(level.get("layout_configured")))
	else:
		var previous_grid_size: Vector2i = target.get("layout_grid_size")
		var previous_game_layout: String = str(target.get("game_grid_layout"))
		var previous_requirement_layout: String = str(target.get("stitch_requirement_layout"))
		var previous_belt_position: Vector2i = target.get("belt_grid_position")
		var previous_belt_size: Vector2i = target.get("belt_grid_size")
		var previous_layout_configured: bool = bool(target.get("layout_configured"))
		undo_redo.add_do_property(target, "layout_grid_size", layout_grid_size)
		undo_redo.add_do_property(target, "game_grid_layout", game_grid_layout)
		undo_redo.add_do_property(target, "belt_grid_position", belt_grid_position)
		undo_redo.add_do_property(target, "belt_grid_size", belt_grid_size)
		undo_redo.add_do_property(target, "layout_configured", true)
		undo_redo.add_undo_property(target, "layout_grid_size", previous_grid_size)
		undo_redo.add_undo_property(target, "game_grid_layout", previous_game_layout)
		undo_redo.add_undo_property(target, "belt_grid_position", previous_belt_position)
		undo_redo.add_undo_property(target, "belt_grid_size", previous_belt_size)
		undo_redo.add_undo_property(target, "layout_configured", previous_layout_configured)
	undo_redo.commit_action()
	var save_error := ""
	if level_index >= 0 and target.has_method("editor_save_level_file"):
		save_error = str(target.call("editor_save_level_file", level_index))
	target.call("refresh_pattern_preview")
	if not save_error.is_empty() and layout_dock:
		layout_dock.show_error_state(save_error)
	elif layout_dock:
		layout_dock.show_applied_state()

func _on_pattern_apply_requested(level_index: int, level_name: String, pattern_grid_size: Vector2i, pattern_layout: String, requirement_layout: String) -> void:
	if not is_instance_valid(target):
		return
	var configured_levels: Array = target.get("level_configs")
	if level_index >= configured_levels.size() and level_index >= 0:
		return
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("编辑编制区域图案")
	if level_index >= 0:
		var level: StitchLevelPattern = configured_levels[level_index]
		undo_redo.add_do_property(level, "level_name", level_name)
		undo_redo.add_do_property(level, "pattern_grid_size", pattern_grid_size)
		undo_redo.add_do_property(level, "pattern_layout", pattern_layout)
		undo_redo.add_do_property(level, "stitch_requirement_layout", requirement_layout)
		undo_redo.add_do_property(level, "auto_generate_link_tiles", true)
		undo_redo.add_undo_property(level, "level_name", str(level.get("level_name")))
		undo_redo.add_undo_property(level, "pattern_grid_size", level.get("pattern_grid_size"))
		undo_redo.add_undo_property(level, "pattern_layout", str(level.get("pattern_layout")))
		undo_redo.add_undo_property(level, "stitch_requirement_layout", str(level.get("stitch_requirement_layout")))
		undo_redo.add_undo_property(level, "auto_generate_link_tiles", bool(level.get("auto_generate_link_tiles")))
	else:
		undo_redo.add_do_property(target, "pattern_grid_size", pattern_grid_size)
		undo_redo.add_do_property(target, "pattern_layout", pattern_layout)
		undo_redo.add_do_property(target, "stitch_requirement_layout", requirement_layout)
		undo_redo.add_do_property(target, "auto_generate_link_tiles", true)
		undo_redo.add_undo_property(target, "pattern_grid_size", target.get("pattern_grid_size"))
		undo_redo.add_undo_property(target, "pattern_layout", str(target.get("pattern_layout")))
		undo_redo.add_undo_property(target, "stitch_requirement_layout", str(target.get("stitch_requirement_layout")))
		undo_redo.add_undo_property(target, "auto_generate_link_tiles", bool(target.get("auto_generate_link_tiles")))
	undo_redo.commit_action()
	var save_error := ""
	if level_index >= 0 and target.has_method("editor_save_level_file"):
		save_error = str(target.call("editor_save_level_file", level_index))
	target.call("refresh_pattern_preview")
	if not save_error.is_empty() and pattern_dock:
		pattern_dock.show_error_state(save_error)
	elif pattern_dock:
		pattern_dock.show_applied_state()

func _on_layout_level_selected(index: int) -> void:
	if pattern_dock:
		pattern_dock.select_level(index)

func _on_pattern_level_selected(index: int) -> void:
	if layout_dock:
		layout_dock.select_level(index)

func _on_level_list_change_requested(levels: Array, selected_index: int) -> void:
	if not is_instance_valid(target):
		return
	var previous_levels: Array = target.get("level_configs").duplicate()
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("调整关卡列表")
	undo_redo.add_do_property(target, "level_configs", levels)
	undo_redo.add_undo_property(target, "level_configs", previous_levels)
	undo_redo.commit_action()
	target.call("set_editor_preview_level", selected_index)
	if layout_dock:
		layout_dock.set_target(target)
	if pattern_dock:
		pattern_dock.set_target(target)

func _on_level_files_change_requested(paths: Array, selected_index: int) -> void:
	if not is_instance_valid(target):
		return
	var previous_paths: Array = target.get("level_files").duplicate()
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("调整独立关卡顺序")
	undo_redo.add_do_property(target, "level_files", paths)
	undo_redo.add_undo_property(target, "level_files", previous_paths)
	undo_redo.commit_action()
	if target.has_method("editor_reload_level_files"):
		target.call("editor_reload_level_files")
	target.call("set_editor_preview_level", selected_index)
	if layout_dock:
		layout_dock.set_target(target)
	if pattern_dock:
		pattern_dock.set_target(target)
