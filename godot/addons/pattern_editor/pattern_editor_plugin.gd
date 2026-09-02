@tool
extends EditorPlugin

const MAIN_SCRIPT = preload("res://scripts/main.gd")
const DOCK_SCRIPT = preload("res://addons/pattern_editor/pattern_editor_dock.gd")

var dock: Control
var target: Node

func _enter_tree() -> void:
	dock = DOCK_SCRIPT.new()
	dock.name = "编制图案编辑器"
	dock.pattern_apply_requested.connect(_on_pattern_apply_requested)
	dock.level_list_change_requested.connect(_on_level_list_change_requested)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	dock.set_target(null)

func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
	dock = null
	target = null

func _handles(object: Object) -> bool:
	return object is Node and object.get_script() == MAIN_SCRIPT

func _edit(object: Object) -> void:
	target = object as Node
	if dock:
		dock.set_target(target)

func _make_visible(visible: bool) -> void:
	if dock:
		dock.visible = visible

func _on_pattern_apply_requested(level_index: int, level_name: String, grid_size: Vector2i, layout: String) -> void:
	if not is_instance_valid(target):
		return
	var configured_levels: Array = target.get("level_configs")
	if level_index >= configured_levels.size():
		return
	var undo_redo: UndoRedo = get_undo_redo()
	undo_redo.create_action("编辑编制图案")
	if level_index >= 0:
		var level: StitchLevelPattern = configured_levels[level_index]
		undo_redo.add_do_property(level, "level_name", level_name)
		undo_redo.add_do_property(level, "grid_size", grid_size)
		undo_redo.add_do_property(level, "layout", layout)
		undo_redo.add_undo_property(level, "level_name", str(level.get("level_name")))
		undo_redo.add_undo_property(level, "grid_size", level.get("grid_size"))
		undo_redo.add_undo_property(level, "layout", str(level.get("layout")))
	else:
		var previous_size: Vector2i = target.get("pattern_grid_size")
		var previous_layout: String = str(target.get("pattern_layout"))
		undo_redo.add_do_property(target, "pattern_grid_size", grid_size)
		undo_redo.add_do_property(target, "pattern_layout", layout)
		undo_redo.add_undo_property(target, "pattern_grid_size", previous_size)
		undo_redo.add_undo_property(target, "pattern_layout", previous_layout)
	undo_redo.commit_action()
	target.call("refresh_pattern_preview")
	if dock:
		dock.show_applied_state()

func _on_level_list_change_requested(levels: Array, selected_index: int) -> void:
	if not is_instance_valid(target):
		return
	var previous_levels: Array = target.get("level_configs").duplicate()
	var undo_redo: UndoRedo = get_undo_redo()
	undo_redo.create_action("调整关卡列表")
	undo_redo.add_do_property(target, "level_configs", levels)
	undo_redo.add_undo_property(target, "level_configs", previous_levels)
	undo_redo.commit_action()
	target.call("set_editor_preview_level", selected_index)
	if dock:
		dock.show_applied_state()
