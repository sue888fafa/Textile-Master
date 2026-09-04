@tool
extends VBoxContainer

signal pattern_apply_requested(level_index: int, level_name: String, pattern_grid_size: Vector2i, pattern_layout: String, requirement_layout: String)
signal level_selected(index: int)

const LEVEL_SCRIPT = preload("res://scripts/level_pattern.gd")
const LINK_TILE_KEYS := [
	"style_0", "style_1", "style_2", "style_3", "style_4", "style_5",
	"style_6", "style_7", "style_8", "style_9", "style_10", "style_11",
	"style_12", "style_13", "style_14", "style_15", "style_16", "style_17",
	"style_18", "style_19", "style_20", "style_21", "style_22", "style_23",
	"style_24", "style_25", "style_26", "style_27", "style_28", "style_29",
	"style_30", "style_31", "style_32", "style_33", "style_34", "style_35",
	"style_36", "style_37", "style_38", "style_39", "style_40", "style_41",
	"style_42", "style_43", "style_44", "style_45", "style_46", "style_47",
	"style_48", "style_49", "style_50", "style_51", "style_52", "style_53"
]
const COLOR_LABELS := {
	"coral": "珊瑚红", "orange": "橙色", "sun": "向日黄", "olive": "橄榄绿",
	"leaf": "叶绿色", "lake": "湖蓝色", "deep_blue": "深蓝色", "purple": "紫色", "pink": "粉色"
}
const PATTERN_OPTIONS := [
	{"char": "c", "color": "coral", "label": "珊瑚红", "hex": "#e86b5b"},
	{"char": "o", "color": "orange", "label": "橙色", "hex": "#f27618"},
	{"char": "y", "color": "sun", "label": "向日黄", "hex": "#e6b93f"},
	{"char": "v", "color": "olive", "label": "橄榄绿", "hex": "#8bb900"},
	{"char": "g", "color": "leaf", "label": "叶绿色", "hex": "#5b9c72"},
	{"char": "l", "color": "lake", "label": "湖蓝色", "hex": "#16b7c5"},
	{"char": "d", "color": "deep_blue", "label": "深蓝色", "hex": "#1474d4"},
	{"char": "p", "color": "purple", "label": "紫色", "hex": "#8f2bd8"},
	{"char": "r", "color": "pink", "label": "粉色", "hex": "#ed2164"}
]
const PATTERN_CELL_SIZE := 32.0

var target: Node
var levels: Array = []
var level_paths: Array[String] = []
var selected_level_index := -1
var pattern_size := Vector2i(10, 10)
var pattern_data: Array = []
var requirement_data: Array = []
var selected_tool := "c"
var selected_requirement := ""
var selected_cell := Vector2i(-1, -1)

var level_option: OptionButton
var level_name_edit: LineEdit
var columns_spin: SpinBox
var rows_spin: SpinBox
var pattern_palette: GridContainer
var pattern_grid: GridContainer
var apply_button: Button
var status_label: Label
var selection_label: Label
var count_label: Label
var save_level_button: Button

func _ready() -> void:
	custom_minimum_size = Vector2(360, 0)
	_build_ui()
	_set_empty_state()

func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	add_child(scroll)

	var title := Label.new()
	title.text = "编制区域编辑器"
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)
	var description := Label.new()
	description.text = "只编辑传送带内部的编制图案。连连看物品的位置仍在布局编辑器中手动摆放，物品类型和数量会按这里的颜色自动生成。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("#8a8f99"))
	content.add_child(description)

	var level_row := HBoxContainer.new()
	level_row.add_child(_label("关卡"))
	level_option = OptionButton.new()
	level_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_option.item_selected.connect(_on_level_selected)
	level_row.add_child(level_option)
	save_level_button = Button.new()
	save_level_button.text = "保存文件"
	save_level_button.tooltip_text = "保存当前关卡的独立 .tres 文件"
	save_level_button.pressed.connect(_save_current_level)
	level_row.add_child(save_level_button)
	content.add_child(level_row)

	var name_row := HBoxContainer.new()
	name_row.add_child(_label("名称"))
	level_name_edit = LineEdit.new()
	level_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_name_edit.editable = false
	name_row.add_child(level_name_edit)
	content.add_child(name_row)

	var size_row := HBoxContainer.new()
	size_row.add_child(_label("图案尺寸"))
	columns_spin = _make_spin(1, 40)
	rows_spin = _make_spin(1, 40)
	columns_spin.value_changed.connect(_on_size_changed)
	rows_spin.value_changed.connect(_on_size_changed)
	size_row.add_child(columns_spin)
	size_row.add_child(_label(" × "))
	size_row.add_child(rows_spin)
	content.add_child(size_row)

	pattern_palette = GridContainer.new()
	# Keep all nine color tools in two compact rows so the last four colors
	# remain visible in a narrow editor dock.
	pattern_palette.columns = 5
	pattern_palette.add_theme_constant_override("h_separation", 3)
	pattern_palette.add_theme_constant_override("v_separation", 3)
	for option in PATTERN_OPTIONS:
		var button := Button.new()
		button.text = option.char.to_upper()
		button.tooltip_text = "放置%s编制块" % option.label
		button.custom_minimum_size = Vector2(54, 30)
		button.pressed.connect(_select_pattern_tool.bind(option.char))
		pattern_palette.add_child(button)
	var erase_button := Button.new()
	erase_button.text = "橡皮擦"
	erase_button.custom_minimum_size = Vector2(54, 30)
	erase_button.pressed.connect(_select_pattern_tool.bind("."))
	pattern_palette.add_child(erase_button)
	content.add_child(pattern_palette)
	var clear_all_button := Button.new()
	clear_all_button.text = "一键清除全部编制格"
	clear_all_button.tooltip_text = "清空当前关卡的全部编制格，不改变图案尺寸"
	clear_all_button.custom_minimum_size = Vector2(0, 30)
	clear_all_button.pressed.connect(_clear_pattern)
	content.add_child(clear_all_button)

	count_label = _label("")
	count_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	count_label.add_theme_color_override("font_color", Color("#626975"))
	content.add_child(count_label)

	pattern_grid = GridContainer.new()
	pattern_grid.custom_minimum_size = Vector2(320, 320)
	pattern_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pattern_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pattern_grid.add_theme_constant_override("h_separation", 1)
	pattern_grid.add_theme_constant_override("v_separation", 1)
	content.add_child(pattern_grid)

	selection_label = _label("")
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(selection_label)
	var action_row := HBoxContainer.new()
	apply_button = Button.new()
	apply_button.text = "应用编制图案"
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.pressed.connect(_apply)
	action_row.add_child(apply_button)
	var reload_button := Button.new()
	reload_button.text = "重新载入"
	reload_button.pressed.connect(_reload_from_target)
	action_row.add_child(reload_button)
	content.add_child(action_row)
	status_label = _label("")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 42)
	content.add_child(status_label)

func _label(value: String) -> Label:
	var result := Label.new()
	result.text = value
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return result

func _make_spin(minimum: float, maximum: float) -> SpinBox:
	var result := SpinBox.new()
	result.min_value = minimum
	result.max_value = maximum
	result.step = 1
	result.custom_minimum_size = Vector2(64, 0)
	return result

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
	levels.clear()
	selected_level_index = -1
	level_name_edit.text = ""
	_load_data(Vector2i(10, 10), "", "")
	_refresh_level_options()
	apply_button.disabled = true
	status_label.text = "请在场景树中选中 Main 节点。"

func _reload_from_target() -> void:
	if not is_instance_valid(target):
		_set_empty_state()
		return
	levels = target.get("level_configs").duplicate()
	level_paths = target.call("editor_get_level_files") if target.has_method("editor_get_level_files") else []
	if levels.is_empty():
		selected_level_index = -1
		level_name_edit.text = "单关配置"
		_load_data(target.get("pattern_grid_size"), str(target.get("pattern_layout")), str(target.get("stitch_requirement_layout")))
	else:
		selected_level_index = clampi(selected_level_index, 0, levels.size() - 1)
		_load_level_data(selected_level_index)
	_refresh_level_options()
	if save_level_button:
		save_level_button.disabled = level_paths.is_empty() or selected_level_index < 0
	apply_button.disabled = false
	status_label.text = "已载入独立编制关卡；应用后会保存 .tres 文件。"

func _load_level_data(index: int) -> void:
	if index < 0 or index >= levels.size():
		return
	var level: Resource = levels[index]
	level_name_edit.text = str(level.get("level_name"))
	var size: Vector2i = level.get("pattern_grid_size")
	if size.x <= 0 or size.y <= 0:
		size = Vector2i(10, 10)
	_load_data(size, str(level.get("pattern_layout")), str(level.get("stitch_requirement_layout")))

func _load_data(new_size: Vector2i, layout: String, requirements: String) -> void:
	pattern_size = Vector2i(maxi(new_size.x, 1), maxi(new_size.y, 1))
	pattern_data = _empty_grid(".")
	requirement_data = _empty_grid("")
	var layout_rows: PackedStringArray = layout.replace("\r", "").split("\n")
	for row in range(pattern_size.y):
		var source := layout_rows[row] if row < layout_rows.size() else ""
		for column in range(pattern_size.x):
			var value := source.substr(column, 1).to_lower() if column < source.length() else "."
			if not _is_pattern_char(value):
				value = "."
			pattern_data[row][column] = value
			if value != ".":
				requirement_data[row][column] = _default_key_for_color(_pattern_color_name(value))
	_set_spin_values()
	_rebuild_grid()
	_update_selection_label()
	_refresh_counts()

func _empty_grid(empty_value: String) -> Array:
	var result: Array = []
	for _row in range(pattern_size.y):
		var row_data: Array = []
		for _column in range(pattern_size.x):
			row_data.append(empty_value)
		result.append(row_data)
	return result

func _rebuild_grid() -> void:
	if not pattern_grid:
		return
	for child in pattern_grid.get_children():
		child.queue_free()
	pattern_grid.columns = pattern_size.x
	pattern_grid.custom_minimum_size = Vector2(pattern_size.x * PATTERN_CELL_SIZE, pattern_size.y * PATTERN_CELL_SIZE)
	for row in range(pattern_size.y):
		for column in range(pattern_size.x):
			var button := Button.new()
			button.custom_minimum_size = Vector2(PATTERN_CELL_SIZE, PATTERN_CELL_SIZE)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.add_theme_font_size_override("font_size", 14)
			button.text = _cell_label(row, column)
			button.tooltip_text = "编制格 %d,%d" % [column, row]
			button.modulate = _cell_modulate(row, column)
			button.pressed.connect(_on_pattern_cell_pressed.bind(row, column))
			pattern_grid.add_child(button)
	
func _cell_label(row: int, column: int) -> String:
	var value: String = pattern_data[row][column]
	if value == ".":
		return ""
	return value.to_upper()

func _cell_modulate(row: int, column: int) -> Color:
	if selected_cell == Vector2i(column, row):
		return Color("#fff0a1")
	var value: String = pattern_data[row][column]
	for option in PATTERN_OPTIONS:
		if option.char == value:
			return Color(option.hex)
	return Color("#ffffff")

func _set_spin_values() -> void:
	columns_spin.set_value_no_signal(pattern_size.x)
	rows_spin.set_value_no_signal(pattern_size.y)

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

func _select_pattern_tool(value: String) -> void:
	selected_tool = value
	status_label.text = "当前工具：%s" % ("橡皮擦" if value == "." else "放置" + value.to_upper() + "编制块")

func _clear_pattern() -> void:
	pattern_data = _empty_grid(".")
	requirement_data = _empty_grid("")
	selected_cell = Vector2i(-1, -1)
	_rebuild_grid()
	_update_selection_label()
	_refresh_counts()
	status_label.text = "当前关卡编制图案已一键清空；点击应用保存。"

func _select_requirement(key: String) -> void:
	selected_requirement = key
	if selected_cell.x >= 0 and _is_pattern_cell(selected_cell):
		if pattern_data[selected_cell.y][selected_cell.x] != ".":
			requirement_data[selected_cell.y][selected_cell.x] = key
			_rebuild_grid()
			_update_selection_label()
	status_label.text = "需求已更新；点击应用保存。" if not key.is_empty() else "已清除选中编制格的需求。"

func _on_pattern_cell_pressed(row: int, column: int) -> void:
	selected_cell = Vector2i(column, row)
	pattern_data[row][column] = selected_tool
	if selected_tool == ".":
		requirement_data[row][column] = ""
	else:
		var current := str(requirement_data[row][column])
		if current.is_empty() or _link_color_name(current) != _pattern_color_name(selected_tool):
			requirement_data[row][column] = _default_key_for_color(_pattern_color_name(selected_tool))
	_rebuild_grid()
	_update_selection_label()
	_refresh_counts()
	status_label.text = "已修改编制图案；点击应用保存。"

func _on_size_changed(_value: float) -> void:
	if not is_node_ready():
		return
	var new_size := Vector2i(maxi(int(columns_spin.value), 1), maxi(int(rows_spin.value), 1))
	var old_data := pattern_data
	var old_requirements := requirement_data
	pattern_size = new_size
	pattern_data = _resize_grid(old_data, ".")
	requirement_data = _resize_grid(old_requirements, "")
	_rebuild_grid()
	_update_selection_label()
	_refresh_counts()
	status_label.text = "编制图案尺寸已修改，超出范围内容被截断。"

func _resize_grid(old_data: Array, empty_value: String) -> Array:
	var result: Array = []
	for row in range(pattern_size.y):
		var row_data: Array = []
		for column in range(pattern_size.x):
			row_data.append(old_data[row][column] if row < old_data.size() and column < old_data[row].size() else empty_value)
		result.append(row_data)
	return result

func _is_pattern_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < pattern_size.x and cell.y < pattern_size.y

func _is_pattern_char(value: String) -> bool:
	return value in ["c", "o", "y", "v", "g", "l", "b", "d", "p", "r"]

func _pattern_color_name(value: String) -> String:
	return {"c": "coral", "o": "orange", "y": "sun", "v": "olive", "g": "leaf", "l": "lake", "b": "lake", "d": "deep_blue", "p": "purple", "r": "pink"}.get(value, "coral")

func _default_key_for_color(color: String) -> String:
	var colors := ["coral", "orange", "sun", "olive", "leaf", "lake", "deep_blue", "purple", "pink"]
	var index := colors.find(color)
	var style_index: int = maxi(index, 0) * 6
	return "style_%d" % style_index

func _link_color_name(key: String) -> String:
	var index := LINK_TILE_KEYS.find(key)
	if key.begins_with("style_"):
		index = int(key.trim_prefix("style_"))
	var colors := ["coral", "orange", "sun", "olive", "leaf", "lake", "deep_blue", "purple", "pink"]
	var group_index: int = int(index / 6)
	return colors[group_index] if index >= 0 and group_index < colors.size() else ""

func _update_selection_label() -> void:
	if not selection_label:
		return
	if not _is_pattern_cell(selected_cell):
		selection_label.text = "未选择编制格。"
		return
	var value: String = pattern_data[selected_cell.y][selected_cell.x]
	var requirement: String = requirement_data[selected_cell.y][selected_cell.x]
	selection_label.text = "格子 %d,%d：%s；自动物品类型：%s" % [selected_cell.x, selected_cell.y, value.to_upper() if value != "." else "空", requirement if not requirement.is_empty() else "无"]

func _refresh_counts() -> void:
	if not count_label:
		return
	var counts := {}
	var total_targets := 0
	for row in range(pattern_size.y):
		for column in range(pattern_size.x):
			var value: String = pattern_data[row][column]
			if value == ".":
				continue
			var color := _pattern_color_name(value)
			counts[color] = int(counts.get(color, 0)) + 1
			total_targets += 1
	var lines: PackedStringArray = []
	for option in PATTERN_OPTIONS:
		var target_count: int = int(counts.get(option.color, 0))
		lines.append("%s：%d 个目标，需要 %d 个连连看点位" % [option.label, target_count, target_count * 2])
	lines.append("总计：%d 个编制目标，需要 %d 个连连看点位" % [total_targets, total_targets * 2])
	count_label.text = "编制目标与点位需求\n" + "\n".join(lines)

func _on_level_selected(index: int) -> void:
	select_level(index)
	if is_instance_valid(target):
		target.call("set_editor_preview_level", index)
	level_selected.emit(index)

func select_level(index: int) -> void:
	if levels.is_empty():
		return
	selected_level_index = clampi(index, 0, levels.size() - 1)
	_load_level_data(selected_level_index)
	_refresh_level_options()
	if save_level_button:
		save_level_button.disabled = level_paths.is_empty() or selected_level_index < 0

func _save_current_level() -> void:
	if not is_instance_valid(target) or selected_level_index < 0 or level_paths.is_empty():
		status_label.text = "请先在布局编辑器中迁移或创建独立关卡文件。"
		return
	_apply()

func _configured_link_layout() -> String:
	if selected_level_index >= 0 and selected_level_index < levels.size():
		return str(levels[selected_level_index].get("game_grid_layout"))
	return str(target.get("game_grid_layout")) if is_instance_valid(target) else ""

func _configured_layout_size() -> Vector2i:
	if selected_level_index >= 0 and selected_level_index < levels.size():
		return level_size_or_default(levels[selected_level_index].get("layout_grid_size"))
	return level_size_or_default(target.get("layout_grid_size")) if is_instance_valid(target) else Vector2i(10, 25)

func level_size_or_default(value: Vector2i) -> Vector2i:
	return value if value.x > 0 and value.y > 0 else Vector2i(10, 25)

func _configured_belt_size() -> Vector2i:
	if selected_level_index >= 0 and selected_level_index < levels.size():
		var value: Vector2i = levels[selected_level_index].get("belt_grid_size")
		return value if value.x > 0 and value.y > 0 else Vector2i(5, 5)
	if is_instance_valid(target):
		var value: Vector2i = target.get("belt_grid_size")
		return value if value.x > 0 and value.y > 0 else Vector2i(5, 5)
	return Vector2i(5, 5)

func _link_counts() -> Dictionary:
	var counts := {}
	var layout := _configured_link_layout().replace("\r", "").split("\n")
	var size := _configured_layout_size()
	for row in range(size.y):
		var source: String = layout[row] if row < layout.size() else ""
		for column in range(size.x):
			if column >= source.length():
				continue
			var key := source.substr(column, 1).to_lower()
			if LINK_TILE_KEYS.has(key):
				counts[key] = int(counts.get(key, 0)) + 1
	return counts

func _validate() -> String:
	var target_count := 0
	for row in range(pattern_size.y):
		for column in range(pattern_size.x):
			var value: String = pattern_data[row][column]
			if value == ".":
				continue
			if not _is_pattern_char(value):
				return "编制格 %d,%d 包含非法颜色" % [column, row]
			target_count += 1
	var layout_size := _configured_layout_size()
	var belt_dimensions := _configured_belt_size()
	var available_cells := layout_size.x * layout_size.y - belt_dimensions.x * belt_dimensions.y
	var point_count := 0
	for row in _configured_link_layout().replace("\r", "").split("\n"):
		for column in range(row.length()):
			if row.substr(column, 1) == "0":
				point_count += 1
	var required_count := target_count * 2
	if required_count > available_cells:
		return "需要 %d 个连连看点位，但传送带外只有 %d 个空位" % [required_count, available_cells]
	if point_count != required_count:
		return "连连看点位数量必须等于编制目标数量的两倍：需要 %d 个，当前为 %d 个" % [required_count, point_count]
	return ""

func _serialize(data: Array, empty_value: String) -> String:
	var lines: PackedStringArray = []
	for row in data:
		var line := ""
		for value in row:
			line += str(value) if not str(value).is_empty() else empty_value
		lines.append(line)
	return "\n".join(lines)

func _apply() -> void:
	if not is_instance_valid(target):
		return
	var error := _validate()
	if not error.is_empty():
		status_label.add_theme_color_override("font_color", Color("#c95249"))
		status_label.text = "校验失败：" + error
		return
	pattern_apply_requested.emit(selected_level_index, level_name_edit.text, pattern_size, _serialize(pattern_data, "."), _generated_requirement_layout())

func _generated_requirement_layout() -> String:
	var result := _empty_grid(".")
	for row in range(pattern_size.y):
		for column in range(pattern_size.x):
			var value: String = pattern_data[row][column]
			if value != ".":
				result[row][column] = _default_key_for_color(_pattern_color_name(value))
	return _serialize(result, ".")

func show_applied_state() -> void:
	status_label.add_theme_color_override("font_color", Color("#4e7d5e"))
	status_label.text = "编制图案已应用；按 Ctrl+S 保存场景。"

func show_error_state(message: String) -> void:
	status_label.add_theme_color_override("font_color", Color("#c95249"))
	status_label.text = message
