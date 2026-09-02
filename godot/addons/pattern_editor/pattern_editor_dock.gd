@tool
extends VBoxContainer

signal pattern_apply_requested(level_index: int, level_name: String, grid_size: Vector2i, layout: String)
signal level_list_change_requested(levels: Array, selected_index: int)

const LEVEL_SCRIPT = preload("res://scripts/level_pattern.gd")

const MAX_EDITOR_GRID_SIZE := 32
const COLOR_OPTIONS: Array[Dictionary] = [
	{"char": "c", "label": "珊瑚红", "hex": "#e86b5b"},
	{"char": "y", "label": "向日黄", "hex": "#e6b93f"},
	{"char": "g", "label": "叶绿色", "hex": "#5b9c72"},
	{"char": "l", "label": "湖蓝色", "hex": "#16b7c5"},
	{"char": "d", "label": "深蓝色", "hex": "#1474d4"}
]
const VALID_CHARS := ["c", "y", "g", "l", "b", "d"]

var target: Node
var columns: int = 10
var rows: int = 10
var selected_char: String = "c"
var grid_data: Array = []
var levels: Array = []
var selected_level_index: int = -1

var level_option: OptionButton
var level_name_edit: LineEdit
var size_x_spin: SpinBox
var size_y_spin: SpinBox
var palette_container: GridContainer
var grid_container: GridContainer
var status_label: Label
var apply_button: Button
var cell_buttons: Array[Button] = []

func _ready() -> void:
	custom_minimum_size = Vector2(330, 0)
	_build_ui()
	_set_empty_state()

func _build_ui() -> void:
	var title := Label.new()
	title.text = "编制图案编辑器"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	var description := Label.new()
	description.text = "选择颜色后点击格子摆放；空白工具可清除格子。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("#8a8f99"))
	add_child(description)

	var level_row := HBoxContainer.new()
	add_child(level_row)
	var level_label := Label.new()
	level_label.text = "关卡"
	level_row.add_child(level_label)
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
	duplicate_button.tooltip_text = "复制当前关卡"
	duplicate_button.pressed.connect(_duplicate_level)
	level_row.add_child(duplicate_button)
	var delete_button := Button.new()
	delete_button.text = "删除"
	delete_button.tooltip_text = "删除当前关卡"
	delete_button.pressed.connect(_delete_level)
	level_row.add_child(delete_button)
	var name_row := HBoxContainer.new()
	add_child(name_row)
	var name_label := Label.new()
	name_label.text = "名称"
	name_row.add_child(name_label)
	level_name_edit = LineEdit.new()
	level_name_edit.placeholder_text = "例如：春日花环"
	level_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_name_edit.text_changed.connect(_on_level_name_changed)
	name_row.add_child(level_name_edit)

	var size_row := HBoxContainer.new()
	add_child(size_row)
	var size_label := Label.new()
	size_label.text = "网格"
	size_row.add_child(size_label)
	size_x_spin = _make_spin_box()
	size_x_spin.tooltip_text = "列数"
	size_row.add_child(size_x_spin)
	var multiply_label := Label.new()
	multiply_label.text = " × "
	size_row.add_child(multiply_label)
	size_y_spin = _make_spin_box()
	size_y_spin.tooltip_text = "行数"
	size_row.add_child(size_y_spin)
	size_x_spin.value_changed.connect(_on_size_changed)
	size_y_spin.value_changed.connect(_on_size_changed)

	var palette_label := Label.new()
	palette_label.text = "颜色"
	palette_label.add_theme_color_override("font_color", Color("#626975"))
	add_child(palette_label)
	palette_container = GridContainer.new()
	palette_container.columns = 2
	palette_container.add_theme_constant_override("h_separation", 4)
	palette_container.add_theme_constant_override("v_separation", 4)
	add_child(palette_container)
	for option in COLOR_OPTIONS:
		var button := Button.new()
		button.text = "%s %s" % [option.char, option.label]
		button.tooltip_text = "放置%s（%s）" % [option.label, option.char]
		button.custom_minimum_size = Vector2(145, 30)
		button.toggle_mode = true
		button.pressed.connect(_select_char.bind(option.char))
		palette_container.add_child(button)
	var empty_button := Button.new()
	empty_button.text = "· 空白"
	empty_button.tooltip_text = "清除格子"
	empty_button.custom_minimum_size = Vector2(145, 30)
	empty_button.toggle_mode = true
	empty_button.pressed.connect(_select_char.bind("."))
	palette_container.add_child(empty_button)

	var grid_scroll := ScrollContainer.new()
	grid_scroll.custom_minimum_size = Vector2(320, 430)
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(grid_scroll)
	grid_container = GridContainer.new()
	grid_container.add_theme_constant_override("h_separation", 2)
	grid_container.add_theme_constant_override("v_separation", 2)
	grid_scroll.add_child(grid_container)

	var action_row := HBoxContainer.new()
	add_child(action_row)
	apply_button = Button.new()
	apply_button.text = "应用到 Main"
	apply_button.tooltip_text = "写入 Main 节点并加入撤销历史"
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.pressed.connect(_apply)
	action_row.add_child(apply_button)
	var reload_button := Button.new()
	reload_button.text = "重新载入"
	reload_button.tooltip_text = "放弃未应用的修改，从 Main 重新载入"
	reload_button.pressed.connect(_reload_from_target)
	action_row.add_child(reload_button)
	var clear_button := Button.new()
	clear_button.text = "清空"
	clear_button.tooltip_text = "把当前网格全部清空"
	clear_button.pressed.connect(_clear_grid)
	action_row.add_child(clear_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#8a8f99"))
	add_child(status_label)
	_select_char(selected_char)

func _make_spin_box() -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = MAX_EDITOR_GRID_SIZE
	spin.step = 1
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.custom_minimum_size = Vector2(72, 0)
	return spin

func set_target(new_target: Node) -> void:
	target = new_target
	if not is_node_ready():
		return
	if is_instance_valid(target):
		_reload_from_target()
	else:
		_set_empty_state()

func _set_empty_state() -> void:
	if not is_node_ready():
		return
	status_label.text = "请在场景树中选中 Main 节点。"
	apply_button.disabled = true
	level_name_edit.editable = false
	_set_grid_size(10, 10)
	_rebuild_grid()
	levels.clear()
	selected_level_index = -1
	_refresh_level_options()

func _reload_from_target() -> void:
	if not is_instance_valid(target):
		_set_empty_state()
		return
	levels = target.get("level_configs").duplicate()
	if levels.is_empty():
		selected_level_index = -1
		level_name_edit.text = ""
		var size_value: Vector2i = target.get("pattern_grid_size")
		_set_grid_size(max(size_value.x, 1), max(size_value.y, 1))
		_load_layout(str(target.get("pattern_layout")))
		_rebuild_grid()
	else:
		selected_level_index = clamp(selected_level_index, 0, levels.size() - 1)
		_load_level_data(selected_level_index)
	_refresh_level_options()
	level_name_edit.editable = not levels.is_empty()
	apply_button.disabled = false
	status_label.text = "已载入 Main；修改后点击“应用到 Main”。"

func _refresh_level_options() -> void:
	if not level_option:
		return
	level_option.clear()
	if levels.is_empty():
		level_option.add_item("单关兼容配置")
		level_option.disabled = true
		return
	level_option.disabled = false
	for index in range(levels.size()):
		var level: Resource = levels[index]
		var name := str(level.get("level_name"))
		level_option.add_item("第 %02d 关 · %s" % [index + 1, name if not name.is_empty() else "未命名"])
	level_option.select(selected_level_index)

func _load_level_data(index: int) -> void:
	if index < 0 or index >= levels.size():
		return
	var level: Resource = levels[index]
	level_name_edit.set_text(str(level.get("level_name")))
	var size_value: Vector2i = level.get("grid_size")
	_set_grid_size(max(size_value.x, 1), max(size_value.y, 1))
	_load_layout(str(level.get("layout")))
	_rebuild_grid()

func _on_level_selected(index: int) -> void:
	if index < 0 or index >= levels.size():
		return
	selected_level_index = index
	_load_level_data(index)
	status_label.text = "正在编辑第 %02d 关。" % (index + 1)
	if is_instance_valid(target):
		target.call("set_editor_preview_level", index)

func _on_level_name_changed(_value: String) -> void:
	if is_node_ready() and is_instance_valid(target):
		status_label.text = "关卡名称已修改，点击“应用到 Main”保存。"

func _new_level_from_current() -> StitchLevelPattern:
	var level: StitchLevelPattern = LEVEL_SCRIPT.new()
	level.set("level_name", "第 %02d 关" % (levels.size() + 1))
	level.set("grid_size", Vector2i(columns, rows))
	level.set("layout", _serialize_layout())
	return level

func _add_level() -> void:
	if not is_instance_valid(target):
		return
	var new_level: StitchLevelPattern = _new_level_from_current()
	levels.append(new_level)
	selected_level_index = levels.size() - 1
	_refresh_level_options()
	_load_level_data(selected_level_index)
	level_option.select(selected_level_index)
	level_list_change_requested.emit(levels.duplicate(), selected_level_index)
	status_label.text = "已新增关卡，点击“应用到 Main”保存图案。"

func _duplicate_level() -> void:
	if not is_instance_valid(target) or selected_level_index < 0 or selected_level_index >= levels.size():
		return
	var source: StitchLevelPattern = levels[selected_level_index]
	var copy: StitchLevelPattern = LEVEL_SCRIPT.new()
	copy.set("level_name", "%s 副本" % str(source.get("level_name")))
	copy.set("grid_size", source.get("grid_size"))
	copy.set("layout", str(source.get("layout")))
	levels.insert(selected_level_index + 1, copy)
	selected_level_index += 1
	_refresh_level_options()
	_load_level_data(selected_level_index)
	level_option.select(selected_level_index)
	level_list_change_requested.emit(levels.duplicate(), selected_level_index)
	status_label.text = "已复制关卡，点击“应用到 Main”保存。"

func _delete_level() -> void:
	if not is_instance_valid(target) or selected_level_index < 0 or selected_level_index >= levels.size():
		return
	if levels.size() <= 1:
		status_label.text = "至少保留一个关卡；如需恢复单关模式，请在 Inspector 清空 level_configs。"
		return
	levels.remove_at(selected_level_index)
	if levels.is_empty():
		selected_level_index = -1
		_set_grid_size(10, 10)
		_load_layout("")
		_rebuild_grid()
	else:
		selected_level_index = min(selected_level_index, levels.size() - 1)
		_load_level_data(selected_level_index)
	_refresh_level_options()
	if selected_level_index >= 0:
		level_option.select(selected_level_index)
	level_list_change_requested.emit(levels.duplicate(), selected_level_index)
	status_label.text = "关卡已删除，点击“应用到 Main”保存。"

func _set_grid_size(new_columns: int, new_rows: int) -> void:
	columns = clamp(new_columns, 1, MAX_EDITOR_GRID_SIZE)
	rows = clamp(new_rows, 1, MAX_EDITOR_GRID_SIZE)
	size_x_spin.set_value_no_signal(columns)
	size_y_spin.set_value_no_signal(rows)
	var old_data: Array = grid_data
	grid_data = []
	for row in range(rows):
		var row_data: Array = []
		for column in range(columns):
			var value := "."
			if row < old_data.size() and column < old_data[row].size():
				value = old_data[row][column]
			row_data.append(value)
		grid_data.append(row_data)

func _load_layout(layout: String) -> void:
	var source_rows: PackedStringArray = layout.replace("\r", "").split("\n")
	for row in range(rows):
		var source := source_rows[row] if row < source_rows.size() else ""
		for column in range(columns):
			var value := source.substr(column, 1).to_lower() if column < source.length() else "."
			if value == "b":
				value = "l"
			if value not in VALID_CHARS:
				value = "."
			grid_data[row][column] = value

func _rebuild_grid() -> void:
	if not grid_container:
		return
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.free()
	cell_buttons.clear()
	grid_container.columns = columns
	var cell_size := clamp(340.0 / float(columns), 22.0, 36.0)
	for row in range(rows):
		for column in range(columns):
			var button := Button.new()
			button.custom_minimum_size = Vector2(cell_size, cell_size)
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(_paint_cell.bind(row, column))
			cell_buttons.append(button)
			grid_container.add_child(button)
			_update_cell_button(button, grid_data[row][column])

func _update_cell_button(button: Button, value: String) -> void:
	button.text = "" if value == "." else value.to_upper()
	button.tooltip_text = "空白" if value == "." else "第 %s 格：%s" % [value, _label_for_char(value)]
	var background := Color("#eef0f2") if value == "." else _color_for_char(value)
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color("#b9c0c8") if value == "." else background.lightened(0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_color_override("font_color", Color("#ffffff") if value != "." else Color("#969da6"))
	button.add_theme_font_size_override("font_size", 12)

func _select_char(value: String) -> void:
	selected_char = value
	for child in palette_container.get_children():
		if child is Button:
			child.button_pressed = child.text.begins_with(value) if value != "." else child.text.begins_with("·")

func _paint_cell(row: int, column: int) -> void:
	if row < 0 or row >= rows or column < 0 or column >= columns:
		return
	grid_data[row][column] = selected_char
	var index := row * columns + column
	if index < cell_buttons.size():
		_update_cell_button(cell_buttons[index], selected_char)
	status_label.text = "有未应用的图案修改。"

func _on_size_changed(_value: float) -> void:
	if not is_node_ready() or not is_instance_valid(target):
		return
	_set_grid_size(int(size_x_spin.value), int(size_y_spin.value))
	_rebuild_grid()
	status_label.text = "网格尺寸已修改，点击“应用到 Main”保存。"

func _clear_grid() -> void:
	for row in range(rows):
		for column in range(columns):
			grid_data[row][column] = "."
	_rebuild_grid()
	status_label.text = "网格已清空，点击“应用到 Main”保存。"

func _apply() -> void:
	if not is_instance_valid(target):
		return
	var level_name := level_name_edit.text
	pattern_apply_requested.emit(selected_level_index, level_name, Vector2i(columns, rows), _serialize_layout())

func _serialize_layout() -> String:
	var lines: PackedStringArray = []
	for row in grid_data:
		var line := ""
		for value in row:
			line += value
		lines.append(line)
	return "\n".join(lines)

func show_applied_state() -> void:
	status_label.text = "已应用到 Main；按 Ctrl+S 保存场景。"

func _color_for_char(value: String) -> Color:
	for option in COLOR_OPTIONS:
		if option.char == value:
			return Color(option.hex)
	return Color("#eef0f2")

func _label_for_char(value: String) -> String:
	for option in COLOR_OPTIONS:
		if option.char == value:
			return option.label
	return "空白"
