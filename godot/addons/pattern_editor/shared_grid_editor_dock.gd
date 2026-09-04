@tool
extends VBoxContainer

signal layout_apply_requested(level_index: int, level_name: String, layout_grid_size: Vector2i, game_grid_layout: String, belt_grid_position: Vector2i, belt_grid_size: Vector2i)
signal level_list_change_requested(levels: Array, selected_index: int)
signal level_files_change_requested(paths: Array, selected_index: int)
signal level_file_save_requested(index: int)
signal level_selected(index: int)

const LEVEL_SCRIPT = preload("res://scripts/level_pattern.gd")
const CANVAS_SCRIPT = preload("res://addons/pattern_editor/shared_grid_editor_canvas.gd")
const LINK_POSITION_MARKER := "0"

var target: Node
var levels: Array = []
var level_paths: Array[String] = []
var selected_level_index := -1
var grid_size := Vector2i(10, 25)
var grid_data: Array = []
var requirement_data: Array = []
var belt_position := Vector2i(0, 25)
var belt_size := Vector2i(5, 5)
var selected_tool := "."
var selected_cell := Vector2i(-1, -1)
var scene_dragging_belt := false
var scene_resizing_belt := false
var scene_drag_offset := Vector2i.ZERO
var scene_pressed_cell := Vector2i(-1, -1)
var scene_drag_cell := Vector2i(-1, -1)
var scene_dragging_grid := false
var scene_painting_grid := false

var level_option: OptionButton
var level_name_edit: LineEdit
var columns_spin: SpinBox
var rows_spin: SpinBox
var belt_x_spin: SpinBox
var belt_y_spin: SpinBox
var canvas
var selection_label: Label
var status_label: Label
var stitch_palette: HBoxContainer
var link_palette: GridContainer
var apply_button: Button
var save_level_button: Button
var migration_button: Button
var restore_menu_button: MenuButton

func _ready() -> void:
	custom_minimum_size = Vector2(380, 0)
	_build_ui()
	_set_empty_state()

func _build_ui() -> void:
	var dock_scroll := ScrollContainer.new()
	dock_scroll.name = "布局编辑器滚动区域"
	dock_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := VBoxContainer.new()
	content.name = "布局编辑器内容"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(360, 0)
	dock_scroll.add_child(content)
	add_child(dock_scroll)

	var title := Label.new()
	title.text = "布局编辑器"
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)
	var description := Label.new()
	description.text = "传送带和连连看点位都在这里手动摆放并吸附到网格。连连看物品的颜色和类型由编制区域自动生成。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("#8a8f99"))
	content.add_child(description)

	var level_row := HBoxContainer.new()
	level_row.add_child(_label("关卡"))
	level_option = OptionButton.new()
	level_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_option.item_selected.connect(_on_level_selected)
	level_row.add_child(level_option)
	var add_button := Button.new()
	add_button.text = "+"
	add_button.tooltip_text = "新增关卡"
	add_button.pressed.connect(_add_level)
	level_row.add_child(add_button)
	var duplicate_button := Button.new()
	duplicate_button.text = "复制"
	duplicate_button.pressed.connect(_duplicate_level)
	level_row.add_child(duplicate_button)
	var delete_button := Button.new()
	delete_button.text = "移出"
	delete_button.tooltip_text = "从游玩顺序移出，不删除磁盘文件"
	delete_button.pressed.connect(_delete_level)
	level_row.add_child(delete_button)
	content.add_child(level_row)

	var management_row := HBoxContainer.new()
	var move_up_button := Button.new()
	move_up_button.text = "上移"
	move_up_button.pressed.connect(_move_level_up)
	management_row.add_child(move_up_button)
	var move_down_button := Button.new()
	move_down_button.text = "下移"
	move_down_button.pressed.connect(_move_level_down)
	management_row.add_child(move_down_button)
	restore_menu_button = MenuButton.new()
	restore_menu_button.text = "从文件恢复"
	restore_menu_button.tooltip_text = "重新加入已移出顺序的关卡文件"
	restore_menu_button.get_popup().id_pressed.connect(_restore_level_file)
	management_row.add_child(restore_menu_button)
	migration_button = Button.new()
	migration_button.text = "迁移内嵌关卡"
	migration_button.tooltip_text = "将当前场景内嵌关卡保存为独立 .tres 文件"
	migration_button.pressed.connect(_migrate_embedded_levels)
	management_row.add_child(migration_button)
	save_level_button = Button.new()
	save_level_button.text = "保存当前关卡"
	save_level_button.pressed.connect(_save_current_level)
	management_row.add_child(save_level_button)
	content.add_child(management_row)

	var name_row := HBoxContainer.new()
	name_row.add_child(_label("名称"))
	level_name_edit = LineEdit.new()
	level_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_name_edit.text_changed.connect(func(_value: String): status_label.text = "关卡名称已修改，点击应用保存。")
	name_row.add_child(level_name_edit)
	content.add_child(name_row)

	var size_row := HBoxContainer.new()
	size_row.add_child(_label("统一网格"))
	columns_spin = _make_spin(1, 40)
	rows_spin = _make_spin(1, 60)
	columns_spin.value_changed.connect(_on_grid_size_changed)
	rows_spin.value_changed.connect(_on_grid_size_changed)
	size_row.add_child(columns_spin)
	size_row.add_child(_label(" × "))
	size_row.add_child(rows_spin)
	size_row.add_child(_label("（默认 10 × 25，正方形单元）"))
	content.add_child(size_row)

	var tool_help := _label("选择下方的点位工具后点击网格放置连连看点位；拖动已有点位或传送带区域会自动吸附到格子。拖动传送带右下角斜线调整柄可改变大小。运行时会按编制区域的颜色和数量自动生成物品。")
	tool_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tool_help.add_theme_color_override("font_color", Color("#8a8f99"))
	content.add_child(tool_help)
	var erase_button := Button.new()
	erase_button.text = "橡皮擦"
	erase_button.pressed.connect(_select_link_tool.bind("."))
	content.add_child(erase_button)

	link_palette = GridContainer.new()
	link_palette.columns = 1
	link_palette.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	link_palette.custom_minimum_size = Vector2(38, 36)
	link_palette.add_theme_constant_override("h_separation", 2)
	link_palette.add_theme_constant_override("v_separation", 2)
	var position_button := Button.new()
	position_button.custom_minimum_size = Vector2(48, 30)
	position_button.size = Vector2(48, 30)
	position_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	position_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	position_button.text = "绘制"
	position_button.tooltip_text = "绘制连连看点位"
	position_button.icon = null
	position_button.expand_icon = false
	position_button.pressed.connect(_select_link_tool.bind(LINK_POSITION_MARKER))
	link_palette.add_child(position_button)
	content.add_child(link_palette)

	var action_row := HBoxContainer.new()
	apply_button = Button.new()
	apply_button.text = "应用到 Main"
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.pressed.connect(_apply)
	action_row.add_child(apply_button)
	var reload_button := Button.new()
	reload_button.text = "重新载入"
	reload_button.pressed.connect(_reload_from_target)
	action_row.add_child(reload_button)
	var clear_button := Button.new()
	clear_button.text = "清空内容"
	clear_button.pressed.connect(_clear_content)
	action_row.add_child(clear_button)
	content.add_child(action_row)
	status_label = _label("")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 44)
	content.add_child(status_label)

	canvas = CANVAS_SCRIPT.new()
	canvas.custom_minimum_size = Vector2(220, 660)
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.grid_cell_pressed.connect(_on_grid_cell_pressed)
	canvas.grid_cells_moved.connect(_on_grid_cells_moved)
	canvas.belt_position_changed.connect(_on_belt_position_changed)
	canvas.belt_size_changed.connect(_on_belt_size_changed)
	var canvas_scroll := ScrollContainer.new()
	canvas_scroll.custom_minimum_size = Vector2(220, 300)
	canvas_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	canvas_scroll.add_child(canvas)
	content.add_child(canvas_scroll)

	selection_label = _label("")
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(selection_label)
	var belt_row := HBoxContainer.new()
	belt_row.add_child(_label("传送带尺寸"))
	belt_x_spin = _make_spin(5, 40)
	belt_y_spin = _make_spin(5, 60)
	belt_x_spin.value_changed.connect(_on_belt_size_changed)
	belt_y_spin.value_changed.connect(_on_belt_size_changed)
	belt_row.add_child(belt_x_spin)
	belt_row.add_child(_label(" × "))
	belt_row.add_child(belt_y_spin)
	content.add_child(belt_row)


func _label(value: String) -> Label:
	var result := Label.new()
	result.text = value
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return result

func _section_label(value: String) -> Label:
	var result := _label(value)
	result.add_theme_color_override("font_color", Color("#626975"))
	return result

func _make_spin(minimum: float, maximum: float) -> SpinBox:
	var result := SpinBox.new()
	result.min_value = minimum
	result.max_value = maximum
	result.step = 1
	result.custom_minimum_size = Vector2(62, 0)
	return result

func _target_link_texture(index: int) -> Texture2D:
	if not is_instance_valid(target):
		return null
	var textures: Array = target.get("link_tile_textures")
	return textures[index] if index >= 0 and index < textures.size() else null

func handle_scene_canvas_input(local_point: Vector2, event: InputEvent) -> bool:
	if not is_instance_valid(target):
		return false
	var cell: Vector2i = target.call("editor_shared_grid_cell_at_point", local_point)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if cell.x < 0:
				return false
			if bool(target.call("editor_is_belt_resize_handle", local_point)):
				scene_resizing_belt = true
				scene_dragging_belt = false
				scene_pressed_cell = Vector2i(-1, -1)
				accept_event()
				return true
			if bool(target.call("editor_is_belt_cell", cell)):
				scene_dragging_belt = true
				scene_resizing_belt = false
				scene_drag_offset = cell - belt_position
				scene_pressed_cell = Vector2i(-1, -1)
			else:
				scene_pressed_cell = cell
				scene_drag_cell = cell
				scene_dragging_grid = false
				scene_painting_grid = false
			accept_event()
			return true
		if scene_dragging_belt or scene_resizing_belt:
			scene_dragging_belt = false
			scene_resizing_belt = false
			return true
		if scene_pressed_cell.x >= 0 and not scene_dragging_grid and not scene_painting_grid:
			_on_grid_cell_pressed(scene_pressed_cell.y, scene_pressed_cell.x)
		scene_pressed_cell = Vector2i(-1, -1)
		scene_drag_cell = Vector2i(-1, -1)
		scene_dragging_grid = false
		scene_painting_grid = false
		return true
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if scene_resizing_belt:
			var new_size: Vector2i = target.call("editor_belt_size_from_point", local_point)
			_on_belt_size_changed(new_size)
			return true
		if scene_dragging_belt:
			if cell.x >= 0:
				_on_belt_position_changed(_clamp_position(cell - scene_drag_offset, belt_size))
			return true
		if scene_pressed_cell.x < 0:
			return false
		if cell.x < 0 or cell == scene_drag_cell:
			return true
		if not scene_dragging_grid and not scene_painting_grid:
			if str(grid_data[scene_pressed_cell.y][scene_pressed_cell.x]) != ".":
				scene_dragging_grid = true
			else:
				scene_painting_grid = true
				_on_grid_cell_pressed(cell.y, cell.x)
		if scene_dragging_grid:
			if bool(target.call("editor_is_belt_cell", cell)):
				status_label.text = "传送带占用区域不能放置方块。"
				return true
			_on_grid_cells_moved(scene_drag_cell.y, scene_drag_cell.x, cell.y, cell.x)
			scene_drag_cell = cell
		elif scene_painting_grid:
			_on_grid_cell_pressed(cell.y, cell.x)
			scene_drag_cell = cell
		return true
	return false

func _push_preview_to_target() -> void:
	if is_instance_valid(target):
		target.call("set_editor_layout_preview", grid_size, _serialize_grid(grid_data, "."), belt_position, belt_size)

func _scaled_palette_texture(texture: Texture2D, max_size: int) -> Texture2D:
	if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
		return texture
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	var scale_factor := minf(float(max_size) / float(image.get_width()), float(max_size) / float(image.get_height()))
	var target_size := Vector2i(maxi(1, roundi(image.get_width() * scale_factor)), maxi(1, roundi(image.get_height() * scale_factor)))
	if target_size == Vector2i(image.get_width(), image.get_height()):
		return texture
	image.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func set_target(new_target: Node) -> void:
	target = new_target
	if not is_node_ready():
		return
	if is_instance_valid(target):
		_reload_from_target()
	else:
		_set_empty_state()

func _set_empty_state() -> void:
	levels.clear()
	selected_level_index = -1
	level_name_edit.text = ""
	_load_data(Vector2i(10, 25), "", "", Vector2i(0, 0), Vector2i(5, 5), true)
	_refresh_level_options()
	apply_button.disabled = true
	status_label.text = "请在场景树中选中 Main 节点。"

func _reload_from_target() -> void:
	if not is_instance_valid(target):
		_set_empty_state()
		return
	if target.has_method("clear_editor_layout_preview"):
		target.call("clear_editor_layout_preview")
	levels = target.get("level_configs").duplicate()
	level_paths = target.call("editor_get_level_files") if target.has_method("editor_get_level_files") else []
	selected_cell = Vector2i(-1, -1)
	if levels.is_empty():
		selected_level_index = -1
		level_name_edit.text = "单关配置"
		_load_data(target.get("layout_grid_size"), str(target.get("game_grid_layout")), str(target.get("stitch_requirement_layout")), target.get("belt_grid_position"), target.get("belt_grid_size"), bool(target.get("layout_configured")))
	else:
		selected_level_index = clampi(selected_level_index, 0, levels.size() - 1)
		_load_level_data(selected_level_index)
	_refresh_level_options()
	_refresh_position_palette_icon()
	_refresh_level_file_tools()
	apply_button.disabled = false
	var load_error := str(target.call("editor_get_level_load_error")) if target.has_method("editor_get_level_load_error") else ""
	status_label.text = load_error if not load_error.is_empty() else "已载入统一网格；修改后点击应用，再按 Ctrl+S 保存场景。"

func _load_level_data(index: int) -> void:
	if index < 0 or index >= levels.size():
		return
	var level: Resource = levels[index]
	level_name_edit.text = str(level.get("level_name"))
	var size: Vector2i = level.get("layout_grid_size")
	if size.x <= 0 or size.y <= 0:
		size = Vector2i(10, 25)
	var layout := str(level.get("game_grid_layout"))
	_load_data(size, layout, str(level.get("stitch_requirement_layout")), level.get("belt_grid_position"), level.get("belt_grid_size"), bool(level.get("layout_configured")))

func _load_data(new_size: Vector2i, layout: String, requirements: String, new_belt_position: Vector2i, new_belt_size: Vector2i, layout_is_configured: bool = true) -> void:
	grid_size = Vector2i(maxi(new_size.x, 1), maxi(new_size.y, 1))
	grid_data = _empty_grid()
	requirement_data = _empty_grid("")
	belt_size = Vector2i(maxi(new_belt_size.x, 5), maxi(new_belt_size.y, 5))
	belt_size = Vector2i(mini(belt_size.x, grid_size.x), mini(belt_size.y, grid_size.y))
	belt_position = _clamp_position(new_belt_position, belt_size)
	var layout_rows: PackedStringArray = layout.replace("\r", "").split("\n")
	for row in range(grid_size.y):
		var source := layout_rows[row] if row < layout_rows.size() else ""
		for column in range(grid_size.x):
			var value := source.substr(column, 1) if column < source.length() else "."
			if value == LINK_POSITION_MARKER and not _cell_in_belt(Vector2i(column, row)):
				grid_data[row][column] = LINK_POSITION_MARKER
	_set_spin_values()
	_sync_canvas()
	_update_selection_label()

func _empty_grid(empty_value: String = ".") -> Array:
	var result: Array = []
	for row in range(grid_size.y):
		var row_data: Array = []
		for column in range(grid_size.x):
			row_data.append(empty_value)
		result.append(row_data)
	return result

func _refresh_level_options() -> void:
	level_option.clear()
	if levels.is_empty():
		level_option.add_item("单关配置")
		level_option.disabled = true
		return
	level_option.disabled = false
	for index in range(levels.size()):
		level_option.add_item("第 %02d 关 · %s" % [index + 1, str(levels[index].get("level_name"))])
	level_option.select(selected_level_index)

func _refresh_level_file_tools() -> void:
	if migration_button:
		migration_button.visible = is_instance_valid(target) and level_paths.is_empty() and target.has_method("editor_has_embedded_levels") and bool(target.call("editor_has_embedded_levels"))
	if save_level_button:
		save_level_button.disabled = level_paths.is_empty() or selected_level_index < 0
	if restore_menu_button:
		var menu := restore_menu_button.get_popup()
		menu.clear()
		var available: Array = target.call("editor_list_level_files") if is_instance_valid(target) and target.has_method("editor_list_level_files") else []
		for path in available:
			if path in level_paths:
				continue
			menu.add_item(path.get_file(), menu.item_count)
			menu.set_item_metadata(menu.item_count - 1, path)
		if menu.item_count == 0:
			menu.add_item("没有可恢复的关卡文件", 0)
			menu.set_item_disabled(0, true)

func _select_tool(value: String) -> void:
	_select_link_tool(value)

func _refresh_position_palette_icon() -> void:
	if not link_palette or link_palette.get_child_count() == 0:
		return
	var button := link_palette.get_child(0) as Button
	if button:
		# 点位工具只负责绘制位置，不再用原始毛线球图标撑大按钮。
		button.icon = null
		button.text = "绘制"
		button.custom_minimum_size = Vector2(48, 30)
		button.size = Vector2(48, 30)

func _select_link_tool(value: String) -> void:
	selected_tool = value.to_lower()
	selection_label.text = "当前工具：橡皮擦" if selected_tool == "." else "当前工具：放置连连看点位"
	_sync_canvas()

func _on_grid_cell_pressed(row: int, column: int) -> void:
	if row < 0 or column < 0 or row >= grid_size.y or column >= grid_size.x:
		return
	selected_cell = Vector2i(column, row)
	if _cell_in_belt(selected_cell):
		status_label.text = "传送带占用区域不能放置物品或编制块。"
		_update_selection_label()
		return
	if selected_tool == ".":
		grid_data[row][column] = "."
	else:
		grid_data[row][column] = LINK_POSITION_MARKER
	_update_selection_label()
	_sync_canvas()
	_push_preview_to_target()
	status_label.text = "已修改统一网格，点击应用保存。"

func _on_grid_cells_moved(from_row: int, from_column: int, to_row: int, to_column: int) -> void:
	if from_row < 0 or from_column < 0 or to_row < 0 or to_column < 0:
		return
	if from_row >= grid_size.y or to_row >= grid_size.y or from_column >= grid_size.x or to_column >= grid_size.x:
		return
	var from_cell := Vector2i(from_column, from_row)
	var to_cell := Vector2i(to_column, to_row)
	if _cell_in_belt(to_cell):
		status_label.text = "传送带占用区域不能放置方块。"
		if canvas:
			canvas.reject_grid_move(from_cell)
		return
	if from_cell == to_cell or grid_data[from_row][from_column] == ".":
		return
	var content: String = str(grid_data[from_row][from_column])
	grid_data[from_row][from_column] = grid_data[to_row][to_column]
	grid_data[to_row][to_column] = content
	selected_cell = to_cell
	_sync_canvas()
	_update_selection_label()
	_push_preview_to_target()
	status_label.text = "方块已移动到 %d,%d，点击应用保存。" % [to_column, to_row]

func _on_belt_position_changed(new_position: Vector2i) -> void:
	belt_position = _clamp_position(new_position, belt_size)
	_set_spin_values()
	_update_selection_label()
	_push_preview_to_target()
	status_label.text = "传送带覆盖了连连看物品，请移开后再应用。" if _belt_has_content() else "传送带已吸附到 %s，点击应用保存。" % str(belt_position)

func _on_grid_size_changed(_value: float) -> void:
	if not is_node_ready():
		return
	var new_size := Vector2i(int(columns_spin.value), int(rows_spin.value))
	var old_data := grid_data
	var old_requirements := requirement_data
	grid_size = new_size
	grid_data = _resize_grid(old_data, ".")
	requirement_data = _resize_grid(old_requirements, "")
	belt_size = Vector2i(mini(belt_size.x, grid_size.x), mini(belt_size.y, grid_size.y))
	belt_position = _clamp_position(belt_position, belt_size)
	_sync_canvas()
	_push_preview_to_target()
	status_label.text = "统一网格尺寸已修改，超出范围内容被截断。"

func _resize_grid(old_data: Array, empty_value: String) -> Array:
	var result: Array = []
	for row in range(grid_size.y):
		var row_data: Array = []
		for column in range(grid_size.x):
			row_data.append(old_data[row][column] if row < old_data.size() and column < old_data[row].size() else empty_value)
		result.append(row_data)
	return result

func _on_belt_size_changed(value) -> void:
	if not is_node_ready():
		return
	if value is Vector2i:
		belt_size = Vector2i(clampi(value.x, 5, grid_size.x), clampi(value.y, 5, grid_size.y))
	else:
		belt_size = Vector2i(clampi(int(belt_x_spin.value), 5, grid_size.x), clampi(int(belt_y_spin.value), 5, grid_size.y))
	belt_position = _clamp_position(belt_position, belt_size)
	_set_spin_values()
	_sync_canvas()
	_update_selection_label()
	_push_preview_to_target()
	status_label.text = "传送带尺寸已修改，点击应用保存。"

func _cell_in_belt(cell: Vector2i) -> bool:
	return cell.x >= belt_position.x and cell.x < belt_position.x + belt_size.x and cell.y >= belt_position.y and cell.y < belt_position.y + belt_size.y

func _belt_has_content() -> bool:
	for row in range(belt_position.y, belt_position.y + belt_size.y):
		if row < 0 or row >= grid_data.size():
			continue
		for column in range(belt_position.x, belt_position.x + belt_size.x):
			if column < 0 or column >= grid_data[row].size():
				continue
			var value := str(grid_data[row][column])
			if not value.is_empty() and value != ".":
				return true
	return false

func _clamp_position(position: Vector2i, dimensions: Vector2i) -> Vector2i:
	return Vector2i(clampi(position.x, 0, maxi(grid_size.x - dimensions.x, 0)), clampi(position.y, 0, maxi(grid_size.y - dimensions.y, 0)))

func _set_spin_values() -> void:
	columns_spin.set_value_no_signal(grid_size.x)
	rows_spin.set_value_no_signal(grid_size.y)
	belt_x_spin.set_value_no_signal(belt_size.x)
	belt_y_spin.set_value_no_signal(belt_size.y)

func _sync_canvas() -> void:
	if canvas:
		var textures: Array = target.get("link_tile_textures") if is_instance_valid(target) else []
		var background: Texture2D = target.get("link_tile_background_texture") if is_instance_valid(target) else null
		canvas.configure(grid_size, belt_position, belt_size, grid_data, selected_cell, textures, background)

func _update_selection_label() -> void:
	if not selection_label:
		return
	var point_count := 0
	for row in range(grid_data.size()):
		for value in grid_data[row]:
			if str(value) == LINK_POSITION_MARKER:
				point_count += 1
	var required_count := _configured_pattern_target_count() * 2
	var point_summary := "编制目标：%d 个\n所需连连看点位：%d 个\n当前手动点位：%d 个\n状态：%s" % [_configured_pattern_target_count(), required_count, point_count, "数量正确" if point_count == required_count else "数量不正确"]
	if selected_cell.x < 0:
		selection_label.text = (point_summary + "\n" if not point_summary.is_empty() else "") + "未选择格子。传送带占用区域不能放置连连看物品。"
		return
	var value: String = grid_data[selected_cell.y][selected_cell.x]
	selection_label.text = (point_summary + "\n" if not point_summary.is_empty() else "") + "格子 %d,%d：%s" % [selected_cell.x, selected_cell.y, value if value != "." else "空"]

func _on_level_selected(index: int) -> void:
	select_level(index)
	if is_instance_valid(target):
		target.call("set_editor_preview_level", index)
	level_selected.emit(index)
	status_label.text = "正在编辑第 %02d 关。" % (index + 1)

func select_level(index: int) -> void:
	if levels.is_empty():
		return
	selected_level_index = clampi(index, 0, levels.size() - 1)
	_load_level_data(selected_level_index)
	_refresh_level_options()

func _new_level_from_current() -> StitchLevelPattern:
	var level: StitchLevelPattern = LEVEL_SCRIPT.new()
	level.level_name = "第 %02d 关" % (levels.size() + 1)
	level.pattern_grid_size = _current_pattern_size()
	level.pattern_layout = _current_pattern_layout()
	level.stitch_requirement_layout = _current_requirement_layout()
	level.auto_generate_link_tiles = true
	level.link_tile_style_counts = target.get("link_tile_style_counts") if is_instance_valid(target) else [6, 6, 6, 6, 6, 6, 6, 6, 6]
	level.layout_grid_size = grid_size
	level.game_grid_layout = _serialize_grid(grid_data, ".")
	level.belt_grid_position = belt_position
	level.belt_grid_size = belt_size
	level.layout_configured = true
	return level

func _ensure_external_levels() -> bool:
	if not is_instance_valid(target):
		return false
	if not level_paths.is_empty():
		return true
	if not target.has_method("editor_migrate_embedded_levels"):
		return false
	var migration: Dictionary = target.call("editor_migrate_embedded_levels")
	var error := str(migration.get("error", ""))
	if not error.is_empty():
		status_label.text = error
		return false
	var migrated: Array = migration.get("paths", [])
	if migrated.is_empty():
		return false
	level_paths = migrated
	level_files_change_requested.emit(level_paths.duplicate(), selected_level_index)
	return true

func _migrate_embedded_levels() -> void:
	if _ensure_external_levels():
		status_label.text = "内嵌关卡已迁移为独立文件；按 Ctrl+S 保存场景。"
		_refresh_level_file_tools()

func _save_current_level() -> void:
	if not is_instance_valid(target):
		return
	if level_paths.is_empty():
		if not _ensure_external_levels():
			status_label.text = "请先迁移内嵌关卡。"
			return
	_apply()

func _move_level_up() -> void:
	_move_level(-1)

func _move_level_down() -> void:
	_move_level(1)

func _move_level(offset: int) -> void:
	if level_paths.is_empty() or selected_level_index < 0:
		return
	var target_index := selected_level_index + offset
	if target_index < 0 or target_index >= level_paths.size():
		return
	var path := level_paths[selected_level_index]
	level_paths[selected_level_index] = level_paths[target_index]
	level_paths[target_index] = path
	selected_level_index = target_index
	level_files_change_requested.emit(level_paths.duplicate(), selected_level_index)
	status_label.text = "关卡顺序已调整；按 Ctrl+S 保存场景。"

func _restore_level_file(item_id: int) -> void:
	if not is_instance_valid(target) or not target.has_method("editor_list_level_files"):
		return
	var menu := restore_menu_button.get_popup()
	if item_id < 0 or item_id >= menu.item_count or menu.is_item_disabled(item_id):
		return
	var path := str(menu.get_item_metadata(item_id))
	if path.is_empty() or path in level_paths:
		return
	var insert_index := selected_level_index + 1 if selected_level_index >= 0 else level_paths.size()
	level_paths.insert(insert_index, path)
	selected_level_index = insert_index
	level_files_change_requested.emit(level_paths.duplicate(), selected_level_index)
	status_label.text = "已恢复关卡文件；按 Ctrl+S 保存场景。"

func _add_level() -> void:
	if not is_instance_valid(target):
		return
	if level_paths.is_empty() and not _ensure_external_levels():
		var new_level := _new_level_from_current()
		var result: Dictionary = target.call("editor_save_new_level", new_level) if target.has_method("editor_save_new_level") else {}
		if str(result.get("error", "")).is_empty() and not str(result.get("path", "")).is_empty():
			level_paths.append(str(result.path))
			selected_level_index = 0
			level_files_change_requested.emit(level_paths.duplicate(), selected_level_index)
			status_label.text = "已创建独立关卡文件；按 Ctrl+S 保存场景。"
		else:
			status_label.text = str(result.get("error", "无法创建独立关卡文件"))
		return
	if level_paths.is_empty():
		return
	var source_index := clampi(selected_level_index, 0, levels.size() - 1)
	var result: Dictionary = target.call("editor_create_level_file", source_index, "副本")
	if not str(result.get("error", "")).is_empty():
		status_label.text = str(result.error)
		return
	level_paths.insert(source_index + 1, str(result.path))
	selected_level_index = source_index + 1
	_refresh_level_options()
	level_option.select(selected_level_index)
	level_files_change_requested.emit(level_paths.duplicate(), selected_level_index)
	status_label.text = "已新增关卡，点击应用保存。"

func _duplicate_level() -> void:
	if not is_instance_valid(target) or selected_level_index < 0 or selected_level_index >= levels.size():
		return
	if level_paths.is_empty() and not _ensure_external_levels():
		return
	var result: Dictionary = target.call("editor_create_level_file", selected_level_index, "副本")
	if not str(result.get("error", "")).is_empty():
		status_label.text = str(result.error)
		return
	level_paths.insert(selected_level_index + 1, str(result.path))
	selected_level_index += 1
	_refresh_level_options()
	level_files_change_requested.emit(level_paths.duplicate(), selected_level_index)
	status_label.text = "已复制关卡；按 Ctrl+S 保存场景顺序。"

func _delete_level() -> void:
	if level_paths.is_empty() or selected_level_index < 0 or selected_level_index >= level_paths.size():
		return
	if level_paths.size() <= 1:
		status_label.text = "至少保留一个关卡。"
		return
	level_paths.remove_at(selected_level_index)
	selected_level_index = mini(selected_level_index, level_paths.size() - 1)
	_refresh_level_options()
	level_files_change_requested.emit(level_paths.duplicate(), selected_level_index)
	status_label.text = "关卡已移出顺序，磁盘文件仍保留；按 Ctrl+S 保存场景。"

func _clear_content() -> void:
	grid_data = _empty_grid()
	selected_cell = Vector2i(-1, -1)
	_sync_canvas()
	_update_selection_label()
	status_label.text = "统一网格内容已清空。"

func _validate_configuration() -> String:
	var occupied_count := 0
	for row in range(grid_size.y):
		for column in range(grid_size.x):
			var value: String = grid_data[row][column]
			if value == LINK_POSITION_MARKER:
				occupied_count += 1
			if not value.is_empty() and value != "." and _cell_in_belt(Vector2i(column, row)):
				return "传送带区域覆盖了格子 %d,%d" % [column, row]
	if occupied_count % 2 != 0:
		return "连连看点位总数必须为双数，当前为 %d 个" % occupied_count
	var required_count := _configured_pattern_target_count() * 2
	if _configured_pattern_target_count() == 0 and occupied_count > 0:
		return "空编制图案不能放置连连看点位"
	if occupied_count != required_count:
		return "连连看点位数量必须等于编制目标数量的两倍：需要 %d 个，当前为 %d 个" % [required_count, occupied_count]
	return ""

func _configured_pattern_color_count() -> int:
	var layout := ""
	var size := Vector2i(10, 10)
	if selected_level_index >= 0 and selected_level_index < levels.size():
		var level: Resource = levels[selected_level_index]
		layout = str(level.get("pattern_layout"))
		size = level.get("pattern_grid_size")
	elif is_instance_valid(target):
		layout = str(target.get("pattern_layout"))
		size = target.get("pattern_grid_size")
	var colors: Dictionary = {}
	var rows := layout.replace("\r", "").split("\n")
	for row in range(size.y):
		var source: String = rows[row] if row < rows.size() else ""
		for column in range(size.x):
			if column < source.length():
				var color_key := {"c": "coral", "o": "orange", "y": "sun", "v": "olive", "g": "leaf", "l": "lake", "b": "lake", "d": "deep_blue", "p": "purple", "r": "pink"}.get(source.substr(column, 1).to_lower(), "")
				if not color_key.is_empty():
					colors[color_key] = true
	return colors.size()

func _configured_pattern_target_count() -> int:
	var layout := ""
	var size := Vector2i(10, 10)
	if selected_level_index >= 0 and selected_level_index < levels.size():
		var level: Resource = levels[selected_level_index]
		layout = str(level.get("pattern_layout"))
		size = level.get("pattern_grid_size")
	elif is_instance_valid(target):
		layout = str(target.get("pattern_layout"))
		size = target.get("pattern_grid_size")
	if size.x <= 0 or size.y <= 0:
		size = Vector2i(10, 10)
	var count := 0
	var rows := layout.replace("\r", "").split("\n")
	for row in range(size.y):
		var source := rows[row] if row < rows.size() else ""
		for column in range(size.x):
			if column >= source.length():
				continue
			if source.substr(column, 1).to_lower() in ["c", "o", "y", "v", "g", "l", "b", "d", "p", "r"]:
				count += 1
	return count

func _validate_layout() -> String:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return "统一网格尺寸必须为正数"
	if belt_size.x < 5 or belt_size.y < 5:
		return "传送带尺寸不能小于 5×5"
	if belt_position.x < 0 or belt_position.y < 0 or belt_position.x + belt_size.x > grid_size.x or belt_position.y + belt_size.y > grid_size.y:
		return "传送带超出统一网格边界"
	return ""

func _apply() -> void:
	if not is_instance_valid(target):
		return
	var error := _validate_configuration()
	if error.is_empty():
		error = _validate_layout()
	if not error.is_empty():
		status_label.add_theme_color_override("font_color", Color("#c95249"))
		status_label.text = "校验失败：" + error
		return
	layout_apply_requested.emit(selected_level_index, level_name_edit.text, grid_size, _serialize_grid(grid_data, "."), belt_position, belt_size)

func _current_pattern_size() -> Vector2i:
	if selected_level_index >= 0 and selected_level_index < levels.size():
		var value: Vector2i = levels[selected_level_index].get("pattern_grid_size")
		return value if value.x > 0 and value.y > 0 else Vector2i(10, 10)
	if is_instance_valid(target):
		var value: Vector2i = target.get("pattern_grid_size")
		return value if value.x > 0 and value.y > 0 else Vector2i(10, 10)
	return Vector2i(10, 10)

func _current_pattern_layout() -> String:
	if selected_level_index >= 0 and selected_level_index < levels.size():
		return str(levels[selected_level_index].get("pattern_layout"))
	return str(target.get("pattern_layout")) if is_instance_valid(target) else ""

func _current_requirement_layout() -> String:
	if selected_level_index >= 0 and selected_level_index < levels.size():
		return str(levels[selected_level_index].get("stitch_requirement_layout"))
	return str(target.get("stitch_requirement_layout")) if is_instance_valid(target) else ""

func _serialize_grid(data: Array, empty_value: String) -> String:
	var lines: PackedStringArray = []
	for row in data:
		var line := ""
		for value in row:
			line += value if not str(value).is_empty() else empty_value
		lines.append(line)
	return "\n".join(lines)

func _stitch_color_name(value: String) -> String:
	return {"C": "coral", "O": "orange", "Y": "sun", "V": "olive", "G": "leaf", "A": "lake", "L": "lake", "D": "deep_blue", "P": "purple", "R": "pink"}.get(value, "")

func show_applied_state() -> void:
	status_label.add_theme_color_override("font_color", Color("#4e7d5e"))
	status_label.text = "统一网格配置已应用；按 Ctrl+S 保存场景。"

func show_error_state(message: String) -> void:
	status_label.add_theme_color_override("font_color", Color("#c95249"))
	status_label.text = message
