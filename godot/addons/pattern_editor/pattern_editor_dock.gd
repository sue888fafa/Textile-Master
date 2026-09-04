@tool
extends VBoxContainer

signal pattern_apply_requested(level_index: int, level_name: String, pattern_grid_size: Vector2i, pattern_layout: String, link_grid_size: Vector2i, link_layout: String, requirement_layout: String, layout_grid_size: Vector2i, belt_grid_position: Vector2i, belt_grid_size: Vector2i, link_board_grid_position: Vector2i, link_board_grid_size: Vector2i)
signal level_list_change_requested(levels: Array, selected_index: int)

const LEVEL_SCRIPT = preload("res://scripts/level_pattern.gd")
const LAYOUT_CANVAS_SCRIPT = preload("res://addons/pattern_editor/layout_editor_canvas.gd")
const MAX_EDITOR_GRID_SIZE := 32
const LAYOUT_GRID_SIZE := Vector2i(20, 20)
const PATTERN_COLORS: Array[Dictionary] = [
	{"char": "c", "label": "珊瑚红", "hex": "#e86b5b"},
	{"char": "o", "label": "橙色", "hex": "#f27618"},
	{"char": "y", "label": "向日黄", "hex": "#e6b93f"},
	{"char": "v", "label": "橄榄绿", "hex": "#8bb900"},
	{"char": "g", "label": "叶绿色", "hex": "#5b9c72"},
	{"char": "l", "label": "湖蓝色", "hex": "#16b7c5"},
	{"char": "d", "label": "深蓝色", "hex": "#1474d4"},
	{"char": "p", "label": "紫色", "hex": "#8f2bd8"},
	{"char": "r", "label": "粉色", "hex": "#ed2164"}
]
const LINK_TILE_KEYS := ["style_0", "style_1", "style_2", "style_3", "style_4", "style_5", "style_6", "style_7", "style_8", "style_9", "style_10", "style_11", "style_12", "style_13", "style_14", "style_15", "style_16", "style_17", "style_18", "style_19", "style_20", "style_21", "style_22", "style_23", "style_24", "style_25", "style_26", "style_27", "style_28", "style_29", "style_30", "style_31", "style_32", "style_33", "style_34", "style_35", "style_36", "style_37", "style_38", "style_39", "style_40", "style_41", "style_42", "style_43", "style_44", "style_45", "style_46", "style_47", "style_48", "style_49", "style_50", "style_51", "style_52", "style_53"]
const LINK_TILE_COLORS := ["coral", "coral", "coral", "coral", "coral", "coral", "orange", "orange", "orange", "orange", "orange", "orange", "sun", "sun", "sun", "sun", "sun", "sun", "olive", "olive", "olive", "olive", "olive", "olive", "leaf", "leaf", "leaf", "leaf", "leaf", "leaf", "lake", "lake", "lake", "lake", "lake", "lake", "deep_blue", "deep_blue", "deep_blue", "deep_blue", "deep_blue", "deep_blue", "purple", "purple", "purple", "purple", "purple", "purple", "pink", "pink", "pink", "pink", "pink", "pink"]
const COLOR_LABELS := {"coral": "珊瑚红", "orange": "橙色", "sun": "向日黄", "olive": "橄榄绿", "leaf": "叶绿色", "lake": "湖蓝色", "deep_blue": "深蓝色", "purple": "紫色", "pink": "粉色"}

var target: Node
var pattern_columns := 10
var pattern_rows := 10
var link_columns := 12
var link_rows := 12
var selected_pattern_char := "c"
var selected_link_key := "0"
var selected_target := Vector2i(-1, -1)
var pattern_data: Array = []
var requirement_data: Array = []
var link_data: Array = []
var levels: Array = []
var selected_level_index := -1
var belt_grid_position := Vector2i(1, 2)
var belt_grid_size := Vector2i(18, 8)
var link_board_grid_position := Vector2i(1, 11)
var link_board_grid_size := Vector2i(18, 8)

var level_option: OptionButton
var level_name_edit: LineEdit
var pattern_size_x: SpinBox
var pattern_size_y: SpinBox
var link_size_x: SpinBox
var link_size_y: SpinBox
var pattern_palette: GridContainer
var link_palette: GridContainer
var pattern_grid: GridContainer
var link_grid: GridContainer
var pattern_scroll: ScrollContainer
var link_scroll: ScrollContainer
var pattern_mode_button: Button
var bind_button: Button
var clear_requirement_button: Button
var status_label: Label
var link_count_label: Label
var layout_canvas
var belt_size_x: SpinBox
var belt_size_y: SpinBox
var link_board_size_x: SpinBox
var link_board_size_y: SpinBox
var layout_status_label: Label
var apply_button: Button
var pattern_buttons: Array[Button] = []
var link_buttons: Array[Button] = []

func _ready() -> void:
	custom_minimum_size = Vector2(360, 0)
	_build_ui()
	_set_empty_state()

func _build_ui() -> void:
	var title := Label.new()
	title.text = "关卡联动编辑器"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	var description := Label.new()
	description.text = "同时编辑编制目标、连连看物品和需求绑定。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("#8a8f99"))
	add_child(description)

	var level_row := HBoxContainer.new()
	add_child(level_row)
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
	delete_button.text = "删除"
	delete_button.pressed.connect(_delete_level)
	level_row.add_child(delete_button)

	var name_row := HBoxContainer.new()
	add_child(name_row)
	name_row.add_child(_label("名称"))
	level_name_edit = LineEdit.new()
	level_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_name_edit.placeholder_text = "例如：春日花环"
	level_name_edit.text_changed.connect(_on_level_name_changed)
	name_row.add_child(level_name_edit)

	var tabs := TabContainer.new()
	tabs.name = "编辑面板"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	tabs.add_child(_build_pattern_tab())
	tabs.add_child(_build_link_tab())
	tabs.add_child(_build_layout_tab())

	var action_row := HBoxContainer.new()
	add_child(action_row)
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
	clear_button.text = "清空全部"
	clear_button.pressed.connect(_clear_all)
	action_row.add_child(clear_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 42)
	status_label.add_theme_color_override("font_color", Color("#8a8f99"))
	add_child(status_label)

func _build_pattern_tab() -> Control:
	var panel := VBoxContainer.new()
	panel.name = "编制区域"
	panel.add_child(_section_label("编制区域：颜色与目标绑定"))
	var size_row := HBoxContainer.new()
	size_row.add_child(_label("尺寸"))
	pattern_size_x = _make_spin_box()
	pattern_size_y = _make_spin_box()
	size_row.add_child(pattern_size_x)
	size_row.add_child(_label(" × "))
	size_row.add_child(pattern_size_y)
	pattern_size_x.value_changed.connect(_on_pattern_size_changed)
	pattern_size_y.value_changed.connect(_on_pattern_size_changed)
	panel.add_child(size_row)
	pattern_palette = GridContainer.new()
	pattern_palette.columns = 5
	pattern_palette.add_theme_constant_override("h_separation", 3)
	pattern_palette.add_theme_constant_override("v_separation", 3)
	for option in PATTERN_COLORS:
		var button := Button.new()
		button.text = "%s %s" % [option.char.to_upper(), option.label]
		button.custom_minimum_size = Vector2(108, 28)
		button.toggle_mode = true
		button.pressed.connect(_select_pattern_char.bind(option.char))
		pattern_palette.add_child(button)
	var empty := Button.new()
	empty.text = "· 清除"
	empty.custom_minimum_size = Vector2(108, 28)
	empty.toggle_mode = true
	empty.pressed.connect(_select_pattern_char.bind("."))
	pattern_palette.add_child(empty)
	panel.add_child(pattern_palette)
	pattern_mode_button = Button.new()
	pattern_mode_button.text = "摆放颜色模式（点击格子修改并选择目标）"
	pattern_mode_button.toggle_mode = true
	pattern_mode_button.button_pressed = true
	pattern_mode_button.toggled.connect(_on_pattern_mode_toggled)
	panel.add_child(pattern_mode_button)
	pattern_scroll = _make_grid_scroll()
	pattern_grid = pattern_scroll.get_child(0)
	panel.add_child(pattern_scroll)

	var bind_row := HBoxContainer.new()
	bind_button = Button.new()
	bind_button.text = "绑定选中目标"
	bind_button.tooltip_text = "先点编制格子，再到连连看面板选择物品，返回后绑定"
	bind_button.pressed.connect(_bind_selected_target)
	bind_row.add_child(bind_button)
	clear_requirement_button = Button.new()
	clear_requirement_button.text = "清除需求"
	clear_requirement_button.pressed.connect(_clear_selected_requirement)
	bind_row.add_child(clear_requirement_button)
	panel.add_child(bind_row)
	return panel

func _build_link_tab() -> Control:
	var panel := VBoxContainer.new()
	panel.name = "连连看棋盘"
	panel.add_child(_section_label("连连看棋盘：摆放 32 种物品"))
	var size_row := HBoxContainer.new()
	size_row.add_child(_label("尺寸"))
	link_size_x = _make_spin_box()
	link_size_y = _make_spin_box()
	size_row.add_child(link_size_x)
	size_row.add_child(_label(" × "))
	size_row.add_child(link_size_y)
	link_size_x.value_changed.connect(_on_link_size_changed)
	link_size_y.value_changed.connect(_on_link_size_changed)
	panel.add_child(size_row)
	link_palette = GridContainer.new()
	link_palette.columns = 5
	link_palette.add_theme_constant_override("h_separation", 2)
	link_palette.add_theme_constant_override("v_separation", 2)
	for index in range(LINK_TILE_KEYS.size()):
		var key: String = LINK_TILE_KEYS[index]
		var button := Button.new()
		button.text = key
		button.tooltip_text = "物品 %s · %s" % [key, COLOR_LABELS[LINK_TILE_COLORS[index]]]
		button.custom_minimum_size = Vector2(48, 42)
		button.toggle_mode = true
		var texture := _target_link_texture(index)
		if texture:
			button.icon = texture
		button.pressed.connect(_select_link_key.bind(key))
		link_palette.add_child(button)
	var link_empty := Button.new()
	link_empty.text = "·"
	link_empty.tooltip_text = "清除棋盘格子"
	link_empty.custom_minimum_size = Vector2(48, 42)
	link_empty.toggle_mode = true
	link_empty.pressed.connect(_select_link_key.bind(""))
	link_palette.add_child(link_empty)
	panel.add_child(link_palette)
	link_count_label = Label.new()
	link_count_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	link_count_label.add_theme_color_override("font_color", Color("#626975"))
	panel.add_child(link_count_label)
	link_scroll = _make_grid_scroll()
	link_grid = link_scroll.get_child(0)
	panel.add_child(link_scroll)
	return panel

func _build_layout_tab() -> Control:
	var panel := VBoxContainer.new()
	panel.name = "界面布局"
	panel.add_child(_section_label("界面布局：20×20 吸附网格"))
	var help := _label("拖动传送带或连连看区域；位置会自动吸附到网格。")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color("#8a8f99"))
	panel.add_child(help)
	layout_canvas = LAYOUT_CANVAS_SCRIPT.new()
	layout_canvas.custom_minimum_size = Vector2(180, 390)
	layout_canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout_canvas.layout_changed.connect(_on_layout_canvas_changed)
	panel.add_child(layout_canvas)
	var belt_row := HBoxContainer.new()
	belt_row.add_child(_label("传送带尺寸"))
	belt_size_x = _make_layout_spin_box()
	belt_size_y = _make_layout_spin_box()
	belt_row.add_child(belt_size_x)
	belt_row.add_child(_label(" × "))
	belt_row.add_child(belt_size_y)
	belt_size_x.value_changed.connect(_on_belt_size_changed)
	belt_size_y.value_changed.connect(_on_belt_size_changed)
	panel.add_child(belt_row)
	var link_row := HBoxContainer.new()
	link_row.add_child(_label("连连看尺寸"))
	link_board_size_x = _make_layout_spin_box()
	link_board_size_y = _make_layout_spin_box()
	link_row.add_child(link_board_size_x)
	link_row.add_child(_label(" × "))
	link_row.add_child(link_board_size_y)
	link_board_size_x.value_changed.connect(_on_link_board_size_changed)
	link_board_size_y.value_changed.connect(_on_link_board_size_changed)
	panel.add_child(link_row)
	layout_status_label = _label("")
	layout_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(layout_status_label)
	return panel

func _make_layout_spin_box() -> SpinBox:
	var spin := _make_spin_box()
	spin.min_value = 1
	spin.max_value = LAYOUT_GRID_SIZE.x
	return spin

func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _section_label(value: String) -> Label:
	var label := _label(value)
	label.add_theme_color_override("font_color", Color("#626975"))
	return label

func _make_spin_box() -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = MAX_EDITOR_GRID_SIZE
	spin.step = 1
	spin.custom_minimum_size = Vector2(72, 0)
	return spin

func _make_grid_scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 270)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	scroll.add_child(grid)
	return scroll

func _target_link_texture(index: int) -> Texture2D:
	if not is_instance_valid(target):
		return null
	var textures: Array = target.get("link_tile_textures")
	return textures[index] if index >= 0 and index < textures.size() else null

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
	_set_pattern_size(10, 10)
	_set_link_size(12, 12)
	_load_layout("", "", "")
	_load_screen_layout(LAYOUT_GRID_SIZE, Vector2i(1, 2), Vector2i(18, 8), Vector2i(1, 11), Vector2i(18, 8))
	_rebuild_grids()
	_refresh_level_options()
	apply_button.disabled = true
	status_label.text = "请在场景树中选中 Main 节点。"

func _reload_from_target() -> void:
	if not is_instance_valid(target):
		_set_empty_state()
		return
	levels = target.get("level_configs").duplicate()
	selected_target = Vector2i(-1, -1)
	if levels.is_empty():
		selected_level_index = -1
		level_name_edit.text = ""
		var pattern_size: Vector2i = target.get("pattern_grid_size")
		var link_size: Vector2i = target.get("link_grid_size")
		_set_pattern_size(maxi(pattern_size.x, 1), maxi(pattern_size.y, 1))
		_set_link_size(maxi(link_size.x, 1), maxi(link_size.y, 1))
		_load_layout(str(target.get("pattern_layout")), str(target.get("link_layout")), str(target.get("stitch_requirement_layout")))
		_load_screen_layout(target.get("layout_grid_size"), target.get("belt_grid_position"), target.get("belt_grid_size"), target.get("link_board_grid_position"), target.get("link_board_grid_size"))
	else:
		selected_level_index = clamp(selected_level_index, 0, levels.size() - 1)
		_load_level_data(selected_level_index)
	_refresh_level_options()
	apply_button.disabled = false
	level_name_edit.editable = true
	_refresh_link_palette_icons()
	status_label.text = "已载入 Main；修改后点击“应用到 Main”。"

func _refresh_level_options() -> void:
	level_option.clear()
	if levels.is_empty():
		level_option.add_item("单关配置")
		level_option.disabled = true
		return
	level_option.disabled = false
	for index in range(levels.size()):
		var level: Resource = levels[index]
		level_option.add_item("第 %02d 关 · %s" % [index + 1, str(level.get("level_name"))])
	level_option.select(selected_level_index)

func _load_level_data(index: int) -> void:
	if index < 0 or index >= levels.size():
		return
	var level: Resource = levels[index]
	level_name_edit.text = str(level.get("level_name"))
	var pattern_size: Vector2i = level.get("grid_size")
	if pattern_size.x <= 0 or pattern_size.y <= 0:
		pattern_size = level.get("pattern_grid_size")
	var link_size: Vector2i = level.get("link_grid_size")
	_set_pattern_size(maxi(pattern_size.x, 1), maxi(pattern_size.y, 1))
	_set_link_size(maxi(link_size.x, 1), maxi(link_size.y, 1))
	var pattern_layout := str(level.get("layout"))
	if pattern_layout.is_empty():
		pattern_layout = str(level.get("pattern_layout"))
	_load_layout(pattern_layout, str(level.get("link_layout")), str(level.get("stitch_requirement_layout")))
	if bool(level.get("layout_configured")):
		_load_screen_layout(level.get("layout_grid_size"), level.get("belt_grid_position"), level.get("belt_grid_size"), level.get("link_board_grid_position"), level.get("link_board_grid_size"))
	else:
		_load_screen_layout(target.get("layout_grid_size"), target.get("belt_grid_position"), target.get("belt_grid_size"), target.get("link_board_grid_position"), target.get("link_board_grid_size"))
	_rebuild_grids()
	_refresh_link_palette_icons()

func _load_screen_layout(_grid_size: Vector2i, new_belt_position: Vector2i, new_belt_size: Vector2i, new_link_position: Vector2i, new_link_size: Vector2i) -> void:
	belt_grid_position = new_belt_position
	belt_grid_size = new_belt_size
	link_board_grid_position = new_link_position
	link_board_grid_size = new_link_size
	if belt_grid_size.x < 1 or belt_grid_size.y < 1:
		belt_grid_size = Vector2i(18, 8)
	if link_board_grid_size.x < 1 or link_board_grid_size.y < 1:
		link_board_grid_size = Vector2i(18, 8)
	belt_grid_size = Vector2i(clampi(belt_grid_size.x, 5, LAYOUT_GRID_SIZE.x), clampi(belt_grid_size.y, 5, LAYOUT_GRID_SIZE.y))
	link_board_grid_size = Vector2i(clampi(link_board_grid_size.x, 1, LAYOUT_GRID_SIZE.x), clampi(link_board_grid_size.y, 1, LAYOUT_GRID_SIZE.y))
	belt_grid_position = _clamp_layout_position(belt_grid_position, belt_grid_size)
	link_board_grid_position = _clamp_layout_position(link_board_grid_position, link_board_grid_size)
	_set_layout_spin_values()
	_sync_layout_canvas()
	_update_layout_status()

func _clamp_layout_position(position: Vector2i, dimensions: Vector2i) -> Vector2i:
	return Vector2i(clampi(position.x, 0, maxi(LAYOUT_GRID_SIZE.x - dimensions.x, 0)), clampi(position.y, 0, maxi(LAYOUT_GRID_SIZE.y - dimensions.y, 0)))

func _set_layout_spin_values() -> void:
	if belt_size_x:
		belt_size_x.set_value_no_signal(belt_grid_size.x)
		belt_size_y.set_value_no_signal(belt_grid_size.y)
		link_board_size_x.set_value_no_signal(link_board_grid_size.x)
		link_board_size_y.set_value_no_signal(link_board_grid_size.y)

func _sync_layout_canvas() -> void:
	if layout_canvas:
		layout_canvas.configure(LAYOUT_GRID_SIZE, belt_grid_position, belt_grid_size, link_board_grid_position, link_board_grid_size)

func _on_level_selected(index: int) -> void:
	if index < 0 or index >= levels.size():
		return
	selected_level_index = index
	_load_level_data(index)
	if is_instance_valid(target):
		target.call("set_editor_preview_level", index)
	status_label.text = "正在编辑第 %02d 关。" % (index + 1)

func _on_level_name_changed(_value: String) -> void:
	if is_node_ready() and is_instance_valid(target):
		status_label.text = "关卡名称已修改，点击“应用到 Main”保存。"

func _new_level_from_current() -> StitchLevelPattern:
	var level: StitchLevelPattern = LEVEL_SCRIPT.new()
	level.level_name = "第 %02d 关" % (levels.size() + 1)
	level.pattern_grid_size = Vector2i(pattern_columns, pattern_rows)
	level.pattern_layout = _serialize_pattern()
	level.link_grid_size = Vector2i(link_columns, link_rows)
	level.link_layout = _serialize_links()
	level.stitch_requirement_layout = _serialize_requirements()
	level.layout_grid_size = LAYOUT_GRID_SIZE
	level.belt_grid_position = belt_grid_position
	level.belt_grid_size = belt_grid_size
	level.link_board_grid_position = link_board_grid_position
	level.link_board_grid_size = link_board_grid_size
	level.layout_configured = true
	return level

func _add_level() -> void:
	if not is_instance_valid(target):
		return
	levels.append(_new_level_from_current())
	selected_level_index = levels.size() - 1
	_refresh_level_options()
	level_option.select(selected_level_index)
	level_list_change_requested.emit(levels.duplicate(), selected_level_index)
	status_label.text = "已新增关卡，点击“应用到 Main”保存。"

func _duplicate_level() -> void:
	if not is_instance_valid(target) or selected_level_index < 0 or selected_level_index >= levels.size():
		return
	var source: Resource = levels[selected_level_index]
	var copy: StitchLevelPattern = LEVEL_SCRIPT.new()
	copy.level_name = "%s 副本" % str(source.get("level_name"))
	copy.pattern_grid_size = source.get("pattern_grid_size")
	copy.pattern_layout = str(source.get("pattern_layout"))
	copy.link_grid_size = source.get("link_grid_size")
	copy.link_layout = str(source.get("link_layout"))
	copy.stitch_requirement_layout = str(source.get("stitch_requirement_layout"))
	copy.layout_grid_size = source.get("layout_grid_size")
	copy.belt_grid_position = source.get("belt_grid_position")
	copy.belt_grid_size = source.get("belt_grid_size")
	copy.link_board_grid_position = source.get("link_board_grid_position")
	copy.link_board_grid_size = source.get("link_board_grid_size")
	copy.layout_configured = true
	levels.insert(selected_level_index + 1, copy)
	selected_level_index += 1
	_refresh_level_options()
	_load_level_data(selected_level_index)
	level_list_change_requested.emit(levels.duplicate(), selected_level_index)
	status_label.text = "已复制关卡，点击“应用到 Main”保存。"

func _delete_level() -> void:
	if not is_instance_valid(target) or selected_level_index < 0 or selected_level_index >= levels.size():
		return
	if levels.size() <= 1:
		status_label.text = "至少保留一个关卡。"
		return
	levels.remove_at(selected_level_index)
	selected_level_index = min(selected_level_index, levels.size() - 1)
	_load_level_data(selected_level_index)
	_refresh_level_options()
	level_list_change_requested.emit(levels.duplicate(), selected_level_index)
	status_label.text = "关卡已删除，点击“应用到 Main”保存。"

func _set_pattern_size(new_columns: int, new_rows: int) -> void:
	pattern_columns = clampi(new_columns, 1, MAX_EDITOR_GRID_SIZE)
	pattern_rows = clampi(new_rows, 1, MAX_EDITOR_GRID_SIZE)
	pattern_size_x.set_value_no_signal(pattern_columns)
	pattern_size_y.set_value_no_signal(pattern_rows)
	pattern_data = _resize_string_grid(pattern_data, pattern_columns, pattern_rows, ".")
	requirement_data = _resize_string_grid(requirement_data, pattern_columns, pattern_rows, "")

func _set_link_size(new_columns: int, new_rows: int) -> void:
	link_columns = clampi(new_columns, 1, MAX_EDITOR_GRID_SIZE)
	link_rows = clampi(new_rows, 1, MAX_EDITOR_GRID_SIZE)
	link_size_x.set_value_no_signal(link_columns)
	link_size_y.set_value_no_signal(link_rows)
	link_data = _resize_string_grid(link_data, link_columns, link_rows, "")

func _resize_string_grid(old_data: Array, new_columns: int, new_rows: int, empty_value: String) -> Array:
	var result: Array = []
	for row in range(new_rows):
		var row_data: Array = []
		for column in range(new_columns):
			row_data.append(old_data[row][column] if row < old_data.size() and column < old_data[row].size() else empty_value)
		result.append(row_data)
	return result

func _load_layout(pattern_layout: String, links_layout: String, requirements_layout: String) -> void:
	var pattern_rows_text := pattern_layout.replace("\r", "").split("\n")
	var link_rows_text := links_layout.replace("\r", "").split("\n")
	var requirement_rows_text := requirements_layout.replace("\r", "").split("\n")
	for row in range(pattern_rows):
		var pattern_row: String = pattern_rows_text[row] if row < pattern_rows_text.size() else ""
		for column in range(pattern_columns):
			var value := pattern_row.substr(column, 1).to_lower() if column < pattern_row.length() else "."
			pattern_data[row][column] = value if _is_pattern_char(value) else "."
			var requirement_row: String = requirement_rows_text[row] if row < requirement_rows_text.size() else ""
			var requirement := requirement_row.substr(column, 1).to_lower() if column < requirement_row.length() else ""
			requirement_data[row][column] = requirement if LINK_TILE_KEYS.has(requirement) else ""
	for row in range(link_rows):
		var link_row: String = link_rows_text[row] if row < link_rows_text.size() else ""
		for column in range(link_columns):
			var key := link_row.substr(column, 1).to_lower() if column < link_row.length() else ""
			link_data[row][column] = key if LINK_TILE_KEYS.has(key) else ""
	if links_layout.strip_edges().is_empty() and requirements_layout.strip_edges().is_empty():
		_seed_legacy_configuration()

func _seed_legacy_configuration() -> void:
	var color_to_key := {"c": "0", "y": "1", "g": "2", "l": "3", "b": "3", "d": "4"}
	var keys: Array = []
	for row in range(pattern_rows):
		for column in range(pattern_columns):
			var color_char: String = pattern_data[row][column]
			if not color_to_key.has(color_char):
				continue
			var key: String = color_to_key[color_char]
			requirement_data[row][column] = key
			keys.append(key)
			keys.append(key)
	var positions: Array[Vector2i] = []
	for row in range(link_rows):
		for column in range(link_columns):
			positions.append(Vector2i(row, column))
	var count := min(keys.size(), positions.size())
	for index in range(count):
		var position: Vector2i = positions[index]
		link_data[position.x][position.y] = keys[index]

func _is_pattern_char(value: String) -> bool:
	return value in [".", "c", "o", "y", "v", "g", "l", "b", "d", "p", "r"]

func _rebuild_grids() -> void:
	_rebuild_pattern_grid()
	_rebuild_link_grid()

func _rebuild_pattern_grid() -> void:
	if not pattern_grid:
		return
	for child in pattern_grid.get_children():
		child.queue_free()
	pattern_buttons.clear()
	pattern_grid.columns = pattern_columns
	var cell_size := clampf(330.0 / float(pattern_columns), 22.0, 34.0)
	for row in range(pattern_rows):
		for column in range(pattern_columns):
			var button := Button.new()
			button.custom_minimum_size = Vector2(cell_size, cell_size)
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(_on_pattern_cell_pressed.bind(row, column))
			pattern_grid.add_child(button)
			pattern_buttons.append(button)
			_update_pattern_button(button, row, column)

func _rebuild_link_grid() -> void:
	if not link_grid:
		return
	for child in link_grid.get_children():
		child.queue_free()
	link_buttons.clear()
	link_grid.columns = link_columns
	var cell_size := clampf(330.0 / float(link_columns), 20.0, 34.0)
	for row in range(link_rows):
		for column in range(link_columns):
			var button := Button.new()
			button.custom_minimum_size = Vector2(cell_size, cell_size)
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(_on_link_cell_pressed.bind(row, column))
			link_grid.add_child(button)
			link_buttons.append(button)
			_update_link_button(button, row, column)
	_update_link_counts()

func _refresh_link_palette_icons() -> void:
	if not link_palette:
		return
	for index in range(min(LINK_TILE_KEYS.size(), link_palette.get_child_count())):
		var button := link_palette.get_child(index) as Button
		if button:
			button.icon = _target_link_texture(index)

func _update_link_counts() -> void:
	if not link_count_label:
		return
	var counts := {}
	for row in link_data:
		for key in row:
			if not key.is_empty():
				counts[key] = int(counts.get(key, 0)) + 1
	var values: PackedStringArray = []
	for key in LINK_TILE_KEYS:
		var count: int = int(counts.get(key, 0))
		if count > 0:
			values.append("%s:%d对" % [key, count / 2] if count % 2 == 0 else "%s:%d枚" % [key, count])
	link_count_label.text = "当前棋盘配对：" + ("、".join(values) if not values.is_empty() else "无")

func _update_pattern_button(button: Button, row: int, column: int) -> void:
	var value: String = pattern_data[row][column]
	var requirement: String = requirement_data[row][column]
	button.text = "." if value == "." else value.to_upper() + (" [" + requirement + "]" if not requirement.is_empty() else "")
	button.tooltip_text = "目标 %d-%d · 需求：%s" % [row, column, requirement if not requirement.is_empty() else "未绑定"]
	var bg := Color("#eef0f2") if value == "." else _pattern_color(value)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color("#ffffff") if Vector2i(row, column) == selected_target else Color("#b9c0c8")
	style.set_border_width_all(2 if Vector2i(row, column) == selected_target else 1)
	style.set_corner_radius_all(3)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_color_override("font_color", Color.WHITE if value != "." else Color("#969da6"))

func _update_link_button(button: Button, row: int, column: int) -> void:
	var key: String = link_data[row][column]
	button.text = key
	button.icon = _target_link_texture(LINK_TILE_KEYS.find(key)) if not key.is_empty() else null
	button.tooltip_text = "棋盘 %d-%d：物品 %s" % [row, column, key if not key.is_empty() else "空"]
	var style := StyleBoxFlat.new()
	style.bg_color = _link_color(key) if not key.is_empty() else Color("#eef0f2")
	style.set_border_width_all(1)
	style.border_color = Color("#b9c0c8")
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)

func _select_pattern_char(value: String) -> void:
	selected_pattern_char = value
	for child in pattern_palette.get_children():
		if child is Button:
			child.button_pressed = (value == "." and child.text.begins_with("·")) or (value != "." and child.text.begins_with(value.to_upper()))

func _select_link_key(value: String) -> void:
	selected_link_key = value
	for child in link_palette.get_children():
		if child is Button:
			child.button_pressed = (value.is_empty() and child.text == "·") or (not value.is_empty() and child.text == value)
	if selected_target.x >= 0:
		status_label.text = "已选择物品 %s；点击“绑定选中目标”写入目标。" % (value if not value.is_empty() else "空")

func _on_pattern_mode_toggled(enabled: bool) -> void:
	pattern_mode_button.text = "摆放颜色模式（点击格子修改并选择目标）" if enabled else "选择目标模式（点击格子只选择）"

func _on_pattern_cell_pressed(row: int, column: int) -> void:
	selected_target = Vector2i(row, column)
	if pattern_mode_button.button_pressed:
		pattern_data[row][column] = selected_pattern_char
		if selected_pattern_char == ".":
			requirement_data[row][column] = ""
	_update_pattern_buttons()
	status_label.text = "已选择目标 %d-%d；请在连连看面板选择物品后绑定。" % [row, column]

func _on_link_cell_pressed(row: int, column: int) -> void:
	link_data[row][column] = selected_link_key
	var index := row * link_columns + column
	if index < link_buttons.size():
		_update_link_button(link_buttons[index], row, column)
	_update_link_counts()
	status_label.text = "已修改连连看棋盘，点击“应用到 Main”保存。"

func _bind_selected_target() -> void:
	if selected_target.x < 0 or selected_target.y < 0:
		status_label.text = "请先选择一个编制目标格子。"
		return
	var row := selected_target.x
	var column := selected_target.y
	if pattern_data[row][column] == ".":
		status_label.text = "空白格不能绑定需求，请先放置颜色。"
		return
	requirement_data[row][column] = selected_link_key
	_update_pattern_buttons()
	status_label.text = "目标 %d-%d 已绑定物品 %s。" % [row, column, selected_link_key]

func _clear_selected_requirement() -> void:
	if selected_target.x < 0:
		return
	requirement_data[selected_target.x][selected_target.y] = ""
	_update_pattern_buttons()
	status_label.text = "已清除目标需求。"

func _update_pattern_buttons() -> void:
	for row in range(pattern_rows):
		for column in range(pattern_columns):
			var index := row * pattern_columns + column
			if index < pattern_buttons.size():
				_update_pattern_button(pattern_buttons[index], row, column)

func _on_pattern_size_changed(_value: float) -> void:
	if not is_node_ready():
		return
	_set_pattern_size(int(pattern_size_x.value), int(pattern_size_y.value))
	_rebuild_pattern_grid()
	status_label.text = "编制网格尺寸已修改。"

func _on_link_size_changed(_value: float) -> void:
	if not is_node_ready():
		return
	_set_link_size(int(link_size_x.value), int(link_size_y.value))
	_rebuild_link_grid()
	status_label.text = "连连看网格尺寸已修改。"

func _on_layout_canvas_changed(new_belt_position: Vector2i, new_link_position: Vector2i) -> void:
	belt_grid_position = _clamp_layout_position(new_belt_position, belt_grid_size)
	link_board_grid_position = _clamp_layout_position(new_link_position, link_board_grid_size)
	_update_layout_status()
	status_label.text = "界面布局已修改，点击“应用到 Main”保存。"
	_sync_layout_canvas()

func _on_belt_size_changed(_value: float) -> void:
	if not is_node_ready():
		return
	belt_grid_size = Vector2i(clampi(int(belt_size_x.value), 5, LAYOUT_GRID_SIZE.x), clampi(int(belt_size_y.value), 5, LAYOUT_GRID_SIZE.y))
	belt_grid_position = _clamp_layout_position(belt_grid_position, belt_grid_size)
	_set_layout_spin_values()
	_sync_layout_canvas()
	_update_layout_status()
	status_label.text = "传送带尺寸已修改，点击“应用到 Main”保存。"

func _on_link_board_size_changed(_value: float) -> void:
	if not is_node_ready():
		return
	link_board_grid_size = Vector2i(clampi(int(link_board_size_x.value), 1, LAYOUT_GRID_SIZE.x), clampi(int(link_board_size_y.value), 1, LAYOUT_GRID_SIZE.y))
	link_board_grid_position = _clamp_layout_position(link_board_grid_position, link_board_grid_size)
	_set_layout_spin_values()
	_sync_layout_canvas()
	_update_layout_status()
	status_label.text = "连连看区域尺寸已修改，点击“应用到 Main”保存。"

func _layout_rect_intersects() -> bool:
	var belt_end := belt_grid_position + belt_grid_size
	var link_end := link_board_grid_position + link_board_grid_size
	return belt_grid_position.x < link_end.x and belt_end.x > link_board_grid_position.x and belt_grid_position.y < link_end.y and belt_end.y > link_board_grid_position.y

func _update_layout_status() -> void:
	if not layout_status_label:
		return
	if _layout_rect_intersects():
		layout_status_label.add_theme_color_override("font_color", Color("#c95249"))
		layout_status_label.text = "错误：传送带与连连看区域重叠，不能应用。"
	else:
		layout_status_label.add_theme_color_override("font_color", Color("#626975"))
		layout_status_label.text = "传送带位置 %s，连连看位置 %s" % [str(belt_grid_position), str(link_board_grid_position)]

func _clear_all() -> void:
	pattern_data = _resize_string_grid([], pattern_columns, pattern_rows, ".")
	requirement_data = _resize_string_grid([], pattern_columns, pattern_rows, "")
	link_data = _resize_string_grid([], link_columns, link_rows, "")
	selected_target = Vector2i(-1, -1)
	_rebuild_grids()
	status_label.text = "三类配置已清空。"

func _validate_configuration() -> String:
	var requirement_counts := {}
	for row in range(pattern_rows):
		for column in range(pattern_columns):
			var color_char: String = pattern_data[row][column]
			if color_char == ".":
				continue
			var required_key: String = requirement_data[row][column]
			if required_key.is_empty():
				return "目标 %d-%d：尚未绑定连连看物品" % [row, column]
			var expected_color := _pattern_color_name(color_char)
			if _link_color_name(required_key) != expected_color:
				return "目标 %d-%d：绑定物品颜色与编制颜色不一致" % [row, column]
			requirement_counts[required_key] = int(requirement_counts.get(required_key, 0)) + 1
	var link_counts := {}
	for row in range(link_rows):
		for column in range(link_columns):
			var key: String = link_data[row][column]
			if key.is_empty():
				continue
			link_counts[key] = int(link_counts.get(key, 0)) + 1
	for key in LINK_TILE_KEYS:
		var count: int = int(link_counts.get(key, 0))
		if count % 2 != 0:
			return "物品 %s：棋盘数量为 %d，必须是偶数" % [key, count]
		var pairs := count / 2
		var required_pairs: int = int(requirement_counts.get(key, 0))
		if pairs != required_pairs:
			return "物品 %s：需要 %d 对，当前棋盘有 %d 对" % [key, required_pairs, pairs]
	return ""

func _validate_layout_configuration() -> String:
	if LAYOUT_GRID_SIZE != Vector2i(20, 20):
		return "布局网格必须为 20×20"
	if belt_grid_size.x < 5 or belt_grid_size.y < 5:
		return "传送带尺寸不能小于 5×5"
	if not _layout_rect_in_bounds(belt_grid_position, belt_grid_size):
		return "传送带超出 20×20 布局网格"
	if not _layout_rect_in_bounds(link_board_grid_position, link_board_grid_size):
		return "连连看区域超出 20×20 布局网格"
	if _layout_rect_intersects():
		return "传送带与连连看区域不能重叠"
	return ""

func _layout_rect_in_bounds(position: Vector2i, dimensions: Vector2i) -> bool:
	return position.x >= 0 and position.y >= 0 and dimensions.x > 0 and dimensions.y > 0 and position.x + dimensions.x <= LAYOUT_GRID_SIZE.x and position.y + dimensions.y <= LAYOUT_GRID_SIZE.y

func _apply() -> void:
	if not is_instance_valid(target):
		return
	var error := _validate_configuration()
	if not error.is_empty():
		status_label.add_theme_color_override("font_color", Color("#c95249"))
		status_label.text = "校验失败：" + error
		return
	var layout_error := _validate_layout_configuration()
	if not layout_error.is_empty():
		_update_layout_status()
		status_label.add_theme_color_override("font_color", Color("#c95249"))
		status_label.text = "校验失败：" + layout_error
		return
	pattern_apply_requested.emit(selected_level_index, level_name_edit.text, Vector2i(pattern_columns, pattern_rows), _serialize_pattern(), Vector2i(link_columns, link_rows), _serialize_links(), _serialize_requirements(), LAYOUT_GRID_SIZE, belt_grid_position, belt_grid_size, link_board_grid_position, link_board_grid_size)

func _serialize_pattern() -> String:
	return _serialize_grid(pattern_data, ".")

func _serialize_links() -> String:
	return _serialize_grid(link_data, ".")

func _serialize_requirements() -> String:
	return _serialize_grid(requirement_data, ".")

func _serialize_grid(data: Array, empty_value: String) -> String:
	var lines: PackedStringArray = []
	for row in data:
		var line := ""
		for value in row:
			line += value if not value.is_empty() else empty_value
		lines.append(line)
	return "\n".join(lines)

func show_applied_state() -> void:
	status_label.add_theme_color_override("font_color", Color("#4e7d5e"))
	status_label.text = "已应用三类配置和界面布局；按 Ctrl+S 保存场景。"

func _pattern_color(value: String) -> Color:
	for option in PATTERN_COLORS:
		if option.char == value or (value == "b" and option.char == "l"):
			return Color(option.hex)
	return Color("#eef0f2")

func _pattern_color_name(value: String) -> String:
	return {"c": "coral", "o": "orange", "y": "sun", "v": "olive", "g": "leaf", "l": "lake", "b": "lake", "d": "deep_blue", "p": "purple", "r": "pink"}.get(value, "")

func _link_color_name(key: String) -> String:
	var index := LINK_TILE_KEYS.find(key)
	if key.begins_with("style_"):
		index = int(key.trim_prefix("style_"))
	return LINK_TILE_COLORS[index] if index >= 0 else ""

func _link_color(key: String) -> Color:
	var color_name := _link_color_name(key)
	var hexes := {"coral": "#e86b5b", "orange": "#f27618", "sun": "#e6b93f", "olive": "#8bb900", "leaf": "#5b9c72", "lake": "#16b7c5", "deep_blue": "#1474d4", "purple": "#8f2bd8", "pink": "#ed2164"}
	return Color(hexes.get(color_name, "#eef0f2"))
