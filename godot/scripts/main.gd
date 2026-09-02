@tool
extends Control

## Native Godot 4 port of the conveyor cross-stitch game.
## All gameplay lives here; art slots are exported so the scene can be reskinned in Inspector.

const VIRTUAL_SIZE := Vector2(390.0, 844.0)
const COLOR_KEYS := ["coral", "sun", "leaf", "lake", "deep_blue"]
const MAX_DYNAMIC_MACHINES := 5
const MAX_QUEUE := MAX_DYNAMIC_MACHINES
const MAX_HOLDING := 5
const MATERIAL_VISIBLE_BALLS := 3.5
const MATERIAL_BALL_SIZE := 32.0
const MATERIAL_BALL_STEP := 34.0
const MATERIAL_REFILL_BATCH := 10
const BELT_END := 1.0
const WAVE_MACHINE_COUNT := 2
const SAFE_LAYOUT_ATTEMPTS := 30
const WEAVE_PASS_COUNT := 5
const WEAVE_PASS_BASE_DURATION := 0.28
const WEAVE_SPEED_MULTIPLIER := 1.5
const WEAVE_PASS_DURATION := WEAVE_PASS_BASE_DURATION / WEAVE_SPEED_MULTIPLIER
const MAX_ORDERS_PER_WAVE := 5
const ORDER_CHECK_DURATION := 0.42
const CAPACITY_RANGES := {
	"coral": Vector2i(3, 4),
	"sun": Vector2i(3, 4),
	"leaf": Vector2i(2, 2),
	"lake": Vector2i(1, 1),
	"deep_blue": Vector2i(1, 2)
}
const DEFAULT_PATTERN_LAYOUT := "cc..dd..cc\nc..yyyy..c\n..yyyyyy..\n.yyggggyy.\nyyggbbggyy\nyyggbbggyy\n.yyggggyy.\n..yyyyyy..\nc..yyyy..c\ncc..dd..cc"
const CHAR_TO_COLOR := {"c": "coral", "y": "sun", "g": "leaf", "b": "lake", "l": "lake", "d": "deep_blue"}
const COLORS := {
	"coral": {"label": "珊瑚红", "hex": "#e86b5b", "dark": "#bd4c42", "pale": "#fde9e3"},
	"sun": {"label": "向日黄", "hex": "#e6b93f", "dark": "#a8781d", "pale": "#fff5d8"},
	"leaf": {"label": "叶绿色", "hex": "#5b9c72", "dark": "#377453", "pale": "#e7f3e9"},
	"lake": {"label": "湖蓝色", "hex": "#16b7c5", "dark": "#087987", "pale": "#e0f7f8"},
	"deep_blue": {"label": "深蓝色", "hex": "#1474d4", "dark": "#0d4d99", "pale": "#e4efff"}
}

@export_category("Art Slots")
@export var background_texture: Texture2D
@export var score_panel_texture: Texture2D
@export var level_panel_texture: Texture2D
@export var pause_texture: Texture2D
@export var order_bubble_texture: Texture2D
@export var material_panel_texture: Texture2D
@export var recycle_tray_texture: Texture2D
@export var recycle_slot_texture: Texture2D
@export var board_texture: Texture2D
@export var unstitched_block_texture: Texture2D
@export var belt_texture: Texture2D
@export var machine_left_texture: Texture2D
@export var machine_bottom_texture: Texture2D
@export var machine_right_texture: Texture2D
@export var yarn_textures: Array[Texture2D] = []
@export var stitched_block_textures: Array[Texture2D] = []

@export_category("Level Editing")
@export var level_configs: Array[StitchLevelPattern] = []:
	set(value):
		level_configs = value
		editor_preview_level_index = _clamp_level_index(editor_preview_level_index)
		_connect_level_config_signals()
		_refresh_editor_preview()
@export_range(0, 99, 1) var start_level_index: int = 0
@export var pattern_grid_size: Vector2i = Vector2i(10, 10):
	set(value):
		pattern_grid_size = Vector2i(max(value.x, 1), max(value.y, 1))
		_refresh_editor_preview()
@export_multiline var pattern_layout: String = DEFAULT_PATTERN_LAYOUT:
	set(value):
		pattern_layout = value
		_refresh_editor_preview()

@export_category("Layout - 390x844")
@export var score_rect: Rect2 = Rect2(18, 20, 126, 46)
@export var level_rect: Rect2 = Rect2(137, 20, 128, 46)
@export var pause_rect: Rect2 = Rect2(304, 17, 68, 54)
@export var progress_rect: Rect2 = Rect2(18, 82, 172, 28)
@export var belt_panel_rect: Rect2 = Rect2(12, 120, 366, 390)
@export var belt_path_points: PackedVector2Array = PackedVector2Array([
	Vector2(0.10, 0.10),
	Vector2(0.88, 0.10),
	Vector2(0.90, 0.90),
	Vector2(0.15, 0.90),
	Vector2(0.15, 0.31)
])
@export var materials_panel_rect: Rect2 = Rect2(12, 520, 366, 312)
@export var recycle_tray_rect: Rect2 = Rect2(48, 550, 294, 62)
@export var recycle_slot_size: Vector2 = Vector2(52, 66)
@export var board_layout_rect: Rect2 = Rect2(78, 193, 236, 236)
@export var material_lane_1_rect: Rect2 = Rect2(18, 618, 82, 166)
@export var material_lane_2_rect: Rect2 = Rect2(103, 618, 82, 166)
@export var material_lane_3_rect: Rect2 = Rect2(188, 618, 82, 166)
@export var material_lane_4_rect: Rect2 = Rect2(273, 618, 82, 166)
@export var order_bubble_size: Vector2 = Vector2(52, 34)
@export var order_bubble_gap: float = 4.0
@export var order_bubble_offset: Vector2 = Vector2(34, 6)
@export var dynamic_machine_size: Vector2 = Vector2(58, 58)
@export var machine_counter_offset: Vector2 = Vector2(20, -38)
@export var machine_counter_size: Vector2 = Vector2(52, 24)

var state: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var font: Font
var next_ball_id: int = 1
var game_session: int = 0
var canvas_scale: float = 1.0
var canvas_origin: Vector2 = Vector2.ZERO
var game_paused: bool = false
var toast_text: String = ""
var toast_left: float = 0.0
var weaving_sessions: Array[Dictionary] = []
var order_feedbacks: Array[Dictionary] = []
var runtime_level_index: int = 0
var editor_preview_level_index: int = 0

var belt_rect: Rect2 = Rect2(28, 174, 334, 338)
var board_rect: Rect2 = Rect2(108, 263, 174, 174)
var lane_rects: Array[Rect2] = []

func _ready() -> void:
	font = ThemeDB.fallback_font
	_connect_level_config_signals()
	_sync_layout()
	if Engine.is_editor_hint():
		_refresh_editor_preview()
	else:
		runtime_level_index = _clamp_level_index(start_level_index)
		_reset_game()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if game_paused or state.is_empty():
		queue_redraw()
		return
	if toast_left > 0.0:
		toast_left -= delta
	if not state.is_empty() and state.status == "playing":
		_update_conveyor(delta)
		_try_match_holding()
	if not state.is_empty():
		_update_weaving(delta)
		_update_order_feedbacks(delta)
	if not state.is_empty() and state.status == "playing":
		_advance_wave_if_ready()
	queue_redraw()

func _draw() -> void:
	_sync_layout()
	if state.is_empty():
		_draw_background()
		return
	_layout_canvas()
	draw_set_transform(canvas_origin, 0.0, Vector2.ONE * canvas_scale)
	_draw_background()
	_draw_header()
	_draw_conveyor_panel()
	_draw_materials()
	_draw_toast()
	if game_paused and state.status == "playing":
		_draw_pause_overlay()
	if state.status != "playing":
		_draw_result()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _layout_canvas() -> void:
	canvas_scale = min(size.x / VIRTUAL_SIZE.x, size.y / VIRTUAL_SIZE.y)
	if canvas_scale <= 0.0:
		canvas_scale = 1.0
	canvas_origin = (size - VIRTUAL_SIZE * canvas_scale) * 0.5

func _sync_layout() -> void:
	belt_rect = belt_panel_rect.grow(-16)
	board_rect = board_layout_rect
	lane_rects = [material_lane_1_rect, material_lane_2_rect, material_lane_3_rect, material_lane_4_rect]

func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_sync_layout()
	weaving_sessions.clear()
	order_feedbacks.clear()
	var preview_pattern: Array[Dictionary] = _base_pattern()
	var active_ids: Array[String] = []
	for cell in preview_pattern:
		cell.active = true
		active_ids.append(cell.id)
	state = {
		"pattern": preview_pattern,
		"activeCellIds": active_ids,
		"levelSeed": 0,
		"totalMachineCapacity": {},
		"orderWaves": [{"id": 1, "publishedColors": [], "quotas": {}, "cellIds": [], "orders": []}],
		"currentWaveIndex": 0,
		"stitchedCells": [],
		"materialLanes": [
			{"id": 1, "balls": []},
			{"id": 2, "balls": []},
			{"id": 3, "balls": []},
			{"id": 4, "balls": []}
		],
		"conveyorQueue": [],
		"weavingSessions": weaving_sessions,
		"holdingArea": [],
		"machineCapacity": {},
		"status": "playing"
	}
	queue_redraw()

func set_editor_preview_level(index: int) -> void:
	editor_preview_level_index = _clamp_level_index(index)
	_refresh_editor_preview()

func refresh_pattern_preview() -> void:
	_refresh_editor_preview()

func _connect_level_config_signals() -> void:
	for config in level_configs:
		if config and not config.changed.is_connected(_on_level_config_changed):
			config.changed.connect(_on_level_config_changed)

func _on_level_config_changed() -> void:
	_refresh_editor_preview()

func _level_count() -> int:
	return max(level_configs.size(), 1)

func _clamp_level_index(index: int) -> int:
	return clamp(index, 0, _level_count() - 1)

func _selected_pattern_config() -> StitchLevelPattern:
	if level_configs.is_empty():
		return null
	var index := editor_preview_level_index if Engine.is_editor_hint() else runtime_level_index
	return level_configs[_clamp_level_index(index)]

func _configured_grid_size() -> Vector2i:
	var config := _selected_pattern_config()
	return config.grid_size if config else pattern_grid_size

func _configured_pattern_layout() -> String:
	var config := _selected_pattern_config()
	return config.layout if config else pattern_layout

func _current_level_name() -> String:
	var config := _selected_pattern_config()
	return config.level_name if config and not config.level_name.is_empty() else "第 %02d 关" % (runtime_level_index + 1)

func _grid_columns() -> int:
	return max(_configured_grid_size().x, 1)

func _grid_rows() -> int:
	return max(_configured_grid_size().y, 1)

func _draw_background() -> void:
	if background_texture:
		draw_texture_rect(background_texture, Rect2(Vector2.ZERO, VIRTUAL_SIZE), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, VIRTUAL_SIZE), Color("#f5f0e8"))
		for y in range(0, 844, 18):
			draw_line(Vector2(0, y), Vector2(390, y), Color(0.45, 0.40, 0.32, 0.025), 1.0)

func _draw_header() -> void:
	if score_panel_texture:
		draw_texture_rect(score_panel_texture, score_rect, false)
	else:
		_draw_box(score_rect, Color("#fffdf9"), 11, Color("#d8cfc1"), 2)
		draw_circle(score_rect.position + Vector2(24, score_rect.size.y * 0.5), 14, Color("#f2c547"))
		_text("★", score_rect.position + Vector2(15, score_rect.size.y * 0.5 + 8), 18, Color("#fff7d9"))
	_text("1,020", score_rect.position + Vector2(48, 31), 22, Color("#7b2f20"))
	if level_panel_texture:
		draw_texture_rect(level_panel_texture, level_rect, false)
	else:
		_draw_box(level_rect, Color("#2684c9"), 16, Color("#075b9e"), 3)
	_text(_current_level_name(), level_rect.position + Vector2(27, 30), 16, Color("#fffdf9"))
	if pause_texture:
		draw_texture_rect(pause_texture, pause_rect, false)
	else:
		_draw_box(pause_rect, Color("#2684c9"), 16, Color("#075b9e"), 3)
		_text("▶" if game_paused else "Ⅱ", pause_rect.position + Vector2(20 if game_paused else 22, 36), 24, Color("#fffdf9"))
	_draw_box(progress_rect, Color("#fffdf9"), 6, Color("#d8cfc1"))
	_text("绣制进度  %s / %s" % [state.stitchedCells.size(), state.activeCellIds.size()], progress_rect.position + Vector2(12, 19), 10, Color("#5f6b65"))

func _draw_conveyor_panel() -> void:
	if belt_texture:
		_draw_box(belt_panel_rect, Color(0.99, 0.98, 0.95, 0.22), 7, Color("#d8cfc1"))
	else:
		_draw_box(belt_panel_rect, Color(0.99, 0.98, 0.95, 0.94), 7, Color("#d8cfc1"))
	_text("02 / THREAD LINE", belt_panel_rect.position + Vector2(12, 22), 9, Color("#bd4c42"))
	_text("环形绣线传送带", belt_panel_rect.position + Vector2(12, 45), 18, Color("#243b3b"))
	var wave: Dictionary = state.orderWaves[state.currentWaveIndex]
	var wave_labels: Array[String] = []
	for color in wave.publishedColors:
		wave_labels.append(COLORS[color].label)
	_text("第 %02d 波 · %s订单" % [state.currentWaveIndex + 1, "、".join(wave_labels)], belt_panel_rect.position + Vector2(219, 23), 9, Color("#377453"))
	_draw_belt()
	_draw_board()
	_draw_dynamic_machines()
	_draw_order_bubbles()
	_draw_weaving_threads()
	_text("✦ 动态纺织机沿闭环顺时针移动，到最近位置后射线落到点位", belt_panel_rect.position + Vector2(13, belt_panel_rect.size.y - 24), 8, Color("#8e9188"))
	_text("传送带 %s / %s" % [state.conveyorQueue.size(), MAX_QUEUE], belt_panel_rect.position + Vector2(belt_panel_rect.size.x - 86, belt_panel_rect.size.y - 24), 9, Color("#6e7d77"))

func _draw_belt() -> void:
	if belt_texture:
		draw_texture_rect(belt_texture, belt_rect, false)
	else:
		_draw_box(belt_rect, Color("#71817c"), 42, Color("#53625e"), 12)
		var inner_rect: Rect2 = belt_rect.grow(-46)
		_draw_box(inner_rect, Color("#f9f4ea"), 28, Color("#50605b"), 12)
		_draw_box(inner_rect.grow(-16), Color(1, 0.99, 0.96, 0.7), 20, Color("#d7c9b7"), 1)
		for progress in [0.2, 0.4, 0.6, 0.8]:
			_text("›", _loop_point(progress), 27, Color(0.92, 0.88, 0.74, 0.45))

func _draw_board() -> void:
	var grid_columns: int = _grid_columns()
	var grid_rows: int = _grid_rows()
	var cell_size: Vector2 = Vector2(board_rect.size.x / float(grid_columns), board_rect.size.y / float(grid_rows))
	_text("01 / STITCH BOARD", board_rect.position + Vector2(5, -11), 8, Color("#bd4c42"))
	if board_texture:
		draw_texture_rect(board_texture, board_rect, false)
	else:
		_draw_box(board_rect.grow(5), Color("#e8ddcc"), 3, Color("#cbbda9"), 1)
		draw_rect(board_rect, Color("#ede5d6"))
	for column in range(grid_columns + 1):
		var x: float = board_rect.position.x + board_rect.size.x * column / float(grid_columns)
		draw_line(Vector2(x, board_rect.position.y), Vector2(x, board_rect.end.y), Color(0.45, 0.39, 0.31, 0.16), 1.0)
	for row in range(grid_rows + 1):
		var y: float = board_rect.position.y + board_rect.size.y * row / float(grid_rows)
		draw_line(Vector2(board_rect.position.x, y), Vector2(board_rect.end.x, y), Color(0.45, 0.39, 0.31, 0.16), 1.0)
	var stitched: Array = state.stitchedCells
	for cell in state.pattern:
		var cell_pos: Vector2 = board_rect.position + Vector2((cell.column + 0.5) * cell_size.x, (cell.row + 0.5) * cell_size.y)
		var color: Color = Color(COLORS[cell.color].hex)
		if not cell.active:
			color.a = 0.28
		var cell_rect: Rect2 = Rect2(board_rect.position + Vector2(cell.column, cell.row) * cell_size, cell_size)
		if cell.id in stitched:
			var stitched_texture_index: int = COLOR_KEYS.find(cell.color)
			if stitched_texture_index >= 0 and stitched_texture_index < stitched_block_textures.size() and stitched_block_textures[stitched_texture_index]:
				draw_texture_rect(stitched_block_textures[stitched_texture_index], cell_rect, false, Color(1, 1, 1, color.a))
			else:
				draw_line(cell_pos - Vector2(7, 7), cell_pos + Vector2(7, 7), color, 3.0, true)
				draw_line(cell_pos - Vector2(-7, 7), cell_pos + Vector2(-7, 7), color, 3.0, true)
		else:
			if unstitched_block_texture:
				draw_texture_rect(unstitched_block_texture, cell_rect, false, Color(1, 1, 1, color.a))
			else:
				draw_circle(cell_pos, 3.0, Color(color, 0.42))
			var weave_session: Dictionary = _weaving_for_cell(cell.id)
			if not weave_session.is_empty():
				_draw_weaving_cell(cell, weave_session)

func _weaving_for_cell(cell_id: String) -> Dictionary:
	for weave_session in weaving_sessions:
		if str(weave_session.get("target_cell_id", "")) == cell_id:
			return weave_session
	return {}

func _draw_weaving_cell(cell: Dictionary, weave_session: Dictionary) -> void:
	var cell_size: Vector2 = Vector2(board_rect.size.x / float(_grid_columns()), board_rect.size.y / float(_grid_rows()))
	var cell_rect: Rect2 = Rect2(board_rect.position + Vector2(cell.column, cell.row) * cell_size, cell_size)
	var pass_index: int = clamp(int(weave_session.get("pass_index", 0)), 0, WEAVE_PASS_COUNT - 1)
	var pass_progress: float = clamp(float(weave_session.get("pass_progress", 0.0)), 0.0, 1.0)
	var texture_index: int = COLOR_KEYS.find(cell.color)
	var stitched_texture: Texture2D = null
	if texture_index >= 0 and texture_index < stitched_block_textures.size():
		stitched_texture = stitched_block_textures[texture_index]
	var stripe_height: float = cell_rect.size.y / float(WEAVE_PASS_COUNT)
	for stripe_index in range(WEAVE_PASS_COUNT):
		var visible_width: float = 0.0
		if stripe_index < pass_index:
			visible_width = cell_rect.size.x
		elif stripe_index == pass_index:
			visible_width = cell_rect.size.x * pass_progress
		if visible_width <= 0.0:
			continue
		var stripe_rect: Rect2 = Rect2(cell_rect.position + Vector2(0, stripe_index * stripe_height), Vector2(visible_width, stripe_height))
		if stitched_texture:
			var source_size: Vector2 = Vector2(stitched_texture.get_width(), stitched_texture.get_height())
			var source_rect: Rect2 = Rect2(
				Vector2(0, source_size.y * float(stripe_index) / float(WEAVE_PASS_COUNT)),
				Vector2(source_size.x * visible_width / cell_rect.size.x, source_size.y / float(WEAVE_PASS_COUNT))
			)
			draw_texture_rect_region(stitched_texture, stripe_rect, source_rect, Color.WHITE)
		else:
			var stitch_color: Color = Color(COLORS[cell.color].hex)
			stitch_color.a = 0.72
			draw_rect(stripe_rect, stitch_color)
			draw_line(stripe_rect.position + Vector2(2, stripe_rect.size.y - 2), stripe_rect.end - Vector2(2, 2), Color(1, 1, 1, 0.32), 1.0, true)

func _get_weave_endpoint(cell: Dictionary, pass_index: int, pass_progress: float) -> Vector2:
	var cell_size: Vector2 = Vector2(board_rect.size.x / float(_grid_columns()), board_rect.size.y / float(_grid_rows()))
	var cell_rect: Rect2 = Rect2(board_rect.position + Vector2(cell.column, cell.row) * cell_size, cell_size)
	var inset: float = min(cell_rect.size.x, cell_rect.size.y) * 0.14
	var y_ratio: float = float(pass_index) / float(WEAVE_PASS_COUNT - 1)
	return Vector2(
		lerp(cell_rect.position.x + inset, cell_rect.end.x - inset, clamp(pass_progress, 0.0, 1.0)),
		lerp(cell_rect.position.y + inset, cell_rect.end.y - inset, y_ratio)
	)

func _draw_dynamic_machines() -> void:
	for item in state.conveyorQueue:
		var point: Vector2 = _loop_point(item.progress)
		var machine_rect: Rect2 = Rect2(point - dynamic_machine_size * 0.5, dynamic_machine_size)
		var machine_texture: Texture2D = _machine_texture_for_progress(item.progress)
		if machine_texture:
			_draw_texture_contain(machine_texture, machine_rect)
		else:
			_draw_box(machine_rect, Color(COLORS[item.color].pale), 8, Color(COLORS[item.color].hex), 2)
			draw_rect(Rect2(machine_rect.position + Vector2(12, 10), Vector2(machine_rect.size.x - 24, 22)), Color("#fffdf8"), false, 2.0)
			draw_line(machine_rect.position + Vector2(machine_rect.size.x * 0.5, 13), machine_rect.position + Vector2(machine_rect.size.x * 0.5, 34), Color("#243b3b"), 2.0)
			draw_circle(machine_rect.position + Vector2(machine_rect.size.x * 0.5, 35), 3.0, Color("#fffdf8"))
		if bool(item.get("yarn_visible", true)):
			_draw_yarn_at(item.color, point + Vector2(0, 9), 15.0)
		if item.status == "stitching":
			draw_circle(point + Vector2(0, -dynamic_machine_size.y * 0.5 + 5), 4.0, Color("#fff4a8"))
	var start_point: Vector2 = _loop_point(0.0)
	var counter_rect: Rect2 = Rect2(start_point + machine_counter_offset, machine_counter_size)
	_draw_box(counter_rect, Color("#fffdf8"), 7, Color("#d8cfc1"), 1)
	_text("%d / %d" % [state.conveyorQueue.size(), MAX_DYNAMIC_MACHINES], counter_rect.position + Vector2(10, 16), 10, Color("#243b3b"))

func _draw_yarn_at(color: String, point: Vector2, radius: float) -> void:
	var texture_index: int = COLOR_KEYS.find(color)
	if texture_index >= 0 and texture_index < yarn_textures.size() and yarn_textures[texture_index]:
		draw_texture_rect(yarn_textures[texture_index], Rect2(point - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), false, Color.WHITE)
	else:
		draw_circle(point, radius, Color(COLORS[color].hex))
		draw_arc(point, radius - 4.0, -2.6, 1.5, 18, Color(1, 1, 1, 0.45), 1.0)

func _machine_texture_for_progress(progress: float) -> Texture2D:
	var points: PackedVector2Array = _belt_path_points()
	var segment_index: int = _path_segment_at_progress(progress)
	if segment_index < 0 or segment_index + 1 >= points.size():
		return machine_bottom_texture
	var direction: Vector2 = points[segment_index + 1] - points[segment_index]
	if abs(direction.x) > abs(direction.y):
		return machine_bottom_texture
	var segment_center_x: float = (points[segment_index].x + points[segment_index + 1].x) * 0.5
	var belt_center_x: float = belt_rect.get_center().x
	return machine_right_texture if segment_center_x >= belt_center_x else machine_left_texture

func _draw_order_bubbles() -> void:
	var wave: Dictionary = state.orderWaves[state.currentWaveIndex]
	var orders: Array = []
	for order_value in wave.get("orders", []):
		var order: Dictionary = order_value
		if str(order.get("status", "pending")) != "completed":
			orders.append(order)
	if orders.is_empty():
		return
	var origin: Vector2 = _order_bubble_origin(orders.size())
	for order_index in range(orders.size()):
		var order: Dictionary = orders[order_index]
		var bubble_rect: Rect2 = Rect2(origin + Vector2(order_index * (order_bubble_size.x + order_bubble_gap), 0), order_bubble_size)
		if order_bubble_texture:
			draw_texture_rect(order_bubble_texture, bubble_rect, false)
		else:
			_draw_box(bubble_rect, Color("#fffdf8"), 10, Color(COLORS[order.color].hex), 2)
		var icon_size: float = min(26.0, bubble_rect.size.y - 6.0)
		var icon_rect: Rect2 = Rect2(bubble_rect.get_center() - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
		var texture_index: int = COLOR_KEYS.find(order.color)
		if texture_index >= 0 and texture_index < yarn_textures.size() and yarn_textures[texture_index]:
			draw_texture_rect(yarn_textures[texture_index], icon_rect, false, Color.WHITE)
		else:
			draw_circle(icon_rect.get_center(), 9, Color(COLORS[order.color].hex))
	_draw_order_feedbacks()

func _order_bubble_origin(order_count: int) -> Vector2:
	var total_width: float = order_count * order_bubble_size.x + max(0, order_count - 1) * order_bubble_gap
	var anchor: Vector2 = _loop_point(0.0) + order_bubble_offset
	var origin_x: float = clamp(anchor.x, 6.0, VIRTUAL_SIZE.x - total_width - 6.0)
	return Vector2(origin_x, anchor.y)

func _draw_order_feedbacks() -> void:
	for feedback in order_feedbacks:
		var slot_index: int = max(0, int(feedback.get("slot_index", 0)))
		var origin: Vector2 = _order_bubble_origin(max(_orders_visible_count(), slot_index + 1))
		var bubble_rect: Rect2 = Rect2(origin + Vector2(slot_index * (order_bubble_size.x + order_bubble_gap), 0), order_bubble_size)
		_draw_box(bubble_rect, Color("#e0f4e3"), 10, Color("#56a86a"), 2)
		_text("✓", bubble_rect.position + Vector2(bubble_rect.size.x * 0.5 - 7.0, 25), 20, Color("#358b4c"))

func _orders_visible_count() -> int:
	if state.is_empty() or state.currentWaveIndex < 0 or state.currentWaveIndex >= state.orderWaves.size():
		return 0
	var count: int = 0
	var wave: Dictionary = state.orderWaves[state.currentWaveIndex]
	for order_value in wave.get("orders", []):
		var order: Dictionary = order_value
		if str(order.get("status", "pending")) != "completed":
			count += 1
	return count

func _draw_materials() -> void:
	if material_panel_texture:
		draw_texture_rect(material_panel_texture, materials_panel_rect, false)
	_text("03 / YARN DRAWERS", materials_panel_rect.position + Vector2(12, 23), 9, Color("#bd4c42"))
	_text("三合游戏区", materials_panel_rect.position + Vector2(12, 18), 18, Color("#243b3b"))
	_text("点击可见线团，三个同色会自动合成", materials_panel_rect.position + Vector2(174, 18), 8, Color("#8c8e84"))
	_text("待编制区  %d / %d" % [state.holdingArea.size(), MAX_HOLDING], recycle_tray_rect.position + Vector2(190, -7), 9, Color("#a3463d"))
	if recycle_tray_texture:
		draw_texture_rect(recycle_tray_texture, recycle_tray_rect, false)
	else:
		_draw_box(recycle_tray_rect, Color("#e9a544"), 13, Color("#c47b2a"), 2)
	for slot_index in range(5):
		var slot_rect: Rect2 = _recycle_slot_rect(slot_index)
		if recycle_slot_texture:
			_draw_texture_contain(recycle_slot_texture, slot_rect)
		else:
			_draw_box(slot_rect, Color("#f6c16a"), 9, Color("#d89137"), 1)
	for holding_index in range(state.holdingArea.size()):
		var holding_center: Vector2 = _recycle_slot_rect(holding_index).get_center()
		var holding_color: String = state.holdingArea[holding_index].color
		var holding_texture_index: int = COLOR_KEYS.find(holding_color)
		if holding_texture_index >= 0 and holding_texture_index < yarn_textures.size() and yarn_textures[holding_texture_index]:
			draw_texture_rect(yarn_textures[holding_texture_index], Rect2(holding_center - Vector2(15, 15), Vector2(30, 30)), false, Color.WHITE)
		else:
			draw_circle(holding_center, 13, Color(COLORS[holding_color].hex))
			draw_arc(holding_center, 9, -2.6, 1.5, 18, Color(1, 1, 1, 0.45), 1.0)
	for lane_index in range(state.materialLanes.size()):
		var lane: Dictionary = state.materialLanes[lane_index]
		var rect: Rect2 = lane_rects[lane_index]
		var lane_color: String = lane.balls[0].color if lane.balls.size() > 0 else COLOR_KEYS[lane_index]
		_text("● %02d" % (lane_index + 1), rect.position + Vector2(8, 22), 10, Color(COLORS[lane_color].dark))
		_text("%d" % lane.balls.size(), rect.position + Vector2(61, 22), 9, Color("#9a978d"))
		var visible_ball_count: int = min(lane.balls.size(), int(ceil(MATERIAL_VISIBLE_BALLS)))
		for ball_index in range(visible_ball_count):
			var ball: Dictionary = lane.balls[ball_index]
			var ball_top_left: Vector2 = rect.position + Vector2((rect.size.x - MATERIAL_BALL_SIZE) * 0.5, 30 + ball_index * MATERIAL_BALL_STEP)
			var visible_height: float = MATERIAL_BALL_SIZE if ball_index < int(floor(MATERIAL_VISIBLE_BALLS)) else MATERIAL_BALL_SIZE * 0.5
			var ball_rect: Rect2 = Rect2(ball_top_left, Vector2(MATERIAL_BALL_SIZE, visible_height))
			var ball_texture_index: int = COLOR_KEYS.find(ball.color)
			var is_selectable: bool = ball_index < int(floor(MATERIAL_VISIBLE_BALLS)) and _can_add_to_holding(ball.color) and state.status == "playing"
			if is_selectable:
				draw_arc(ball_rect.position + Vector2(MATERIAL_BALL_SIZE * 0.5, MATERIAL_BALL_SIZE * 0.5), MATERIAL_BALL_SIZE * 0.5 + 2.0, 0.0, TAU, 20, Color.WHITE, 1.5)
			if ball_texture_index >= 0 and ball_texture_index < yarn_textures.size() and yarn_textures[ball_texture_index]:
				var yarn_texture: Texture2D = yarn_textures[ball_texture_index]
				if visible_height < MATERIAL_BALL_SIZE:
					var source_size: Vector2 = Vector2(yarn_texture.get_width(), yarn_texture.get_height())
					draw_texture_rect_region(yarn_texture, ball_rect, Rect2(Vector2.ZERO, Vector2(source_size.x, source_size.y * visible_height / MATERIAL_BALL_SIZE)), Color.WHITE)
				else:
					draw_texture_rect(yarn_texture, ball_rect, false, Color.WHITE)
			else:
				var ball_center: Vector2 = ball_rect.position + Vector2(MATERIAL_BALL_SIZE * 0.5, MATERIAL_BALL_SIZE * 0.5)
				draw_circle(ball_center, MATERIAL_BALL_SIZE * 0.5, Color(COLORS[ball.color].hex))
				draw_arc(ball_center, MATERIAL_BALL_SIZE * 0.5 - 5.0, -2.6, 1.5, 18, Color(1, 1, 1, 0.45), 1.0)
			if ball_index == int(floor(MATERIAL_VISIBLE_BALLS)):
				draw_rect(ball_rect, Color(0.08, 0.10, 0.10, 0.62))
				draw_line(ball_rect.position, Vector2(ball_rect.end.x, ball_rect.position.y), Color(0.03, 0.05, 0.05, 0.75), 1.0)

func _recycle_slot_rect(slot_index: int) -> Rect2:
	var gap: float = (recycle_tray_rect.size.x - recycle_slot_size.x * 5.0) / 6.0
	var x: float = recycle_tray_rect.position.x + gap + slot_index * (recycle_slot_size.x + gap)
	var y: float = recycle_tray_rect.get_center().y - recycle_slot_size.y * 0.5
	return Rect2(Vector2(x, y), recycle_slot_size)

func _draw_texture_contain(texture: Texture2D, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
		return
	var source_size: Vector2 = Vector2(texture.get_width(), texture.get_height())
	var scale_factor: float = min(rect.size.x / source_size.x, rect.size.y / source_size.y)
	var draw_size: Vector2 = source_size * scale_factor
	var draw_rect: Rect2 = Rect2(rect.position + (rect.size - draw_size) * 0.5, draw_size)
	draw_texture_rect(texture, draw_rect, false, modulate)

func _draw_toast() -> void:
	if toast_left <= 0.0:
		return
	var width: float = min(320.0, 30.0 + font.get_string_size(toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	_draw_box(Rect2((390.0 - width) * 0.5, 806, width, 27), Color("#fffdf8"), 4, Color("#d9cdbd"))
	_text(toast_text, Vector2((390.0 - width) * 0.5 + 15, 824), 11, Color("#243b3b"))

func _draw_result() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIRTUAL_SIZE), Color(0.14, 0.23, 0.23, 0.52))
	var box: Rect2 = Rect2(42, 274, 306, 230)
	_draw_box(box, Color("#fffdf8"), 8, Color("#d6c5ad"))
	draw_circle(Vector2(195, 325), 27, Color("#fff7d9") if state.status == "won" else Color("#fde8e3"))
	_text("✦" if state.status == "won" else "!", Vector2(187, 334), 25, Color("#b27c1d") if state.status == "won" else Color("#c95249"))
	_text("MISSION COMPLETE" if state.status == "won" else "WORKTABLE FULL", Vector2(122, 370), 9, Color("#bd4c42"))
	_text("花园徽章完成" if state.status == "won" else "待编制区装满了", Vector2(105 if state.status == "won" else 100, 406), 24, Color("#243b3b"))
	_text("所有针脚都已经稳稳落在布面上。" if state.status == "won" else "先合成并送走线团，再继续整理材料。", Vector2(73, 431), 10, Color("#81847b"))
	_text("完成针脚    %d / %d" % [state.stitchedCells.size(), state.activeCellIds.size()], Vector2(105, 461), 12, Color("#243b3b"))
	_draw_box(Rect2(72, 473, 246, 35), Color("#243b3b"), 4)
	var result_action := "下一关" if state.status == "won" and runtime_level_index < _level_count() - 1 else "↻  再绣一次"
	_text(result_action, Vector2(145 if result_action == "下一关" else 157, 496), 13, Color("#fffdf8"))

func _draw_pause_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIRTUAL_SIZE), Color(0.14, 0.23, 0.23, 0.28))
	var box: Rect2 = Rect2(105, 390, 180, 74)
	_draw_box(box, Color("#fffdf8"), 10, Color("#d6c5ad"), 2)
	_text("游戏已暂停", box.position + Vector2(43, 31), 18, Color("#243b3b"))
	_text("点击右上角继续", box.position + Vector2(43, 54), 10, Color("#81847b"))

func _draw_box(rect: Rect2, bg: Color, radius: int, border: Color = Color.TRANSPARENT, border_width: int = 0) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border_width > 0:
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
		style.border_color = border
	draw_style_box(style, rect)

func _text(value: String, position: Vector2, size_px: int, color: Color) -> void:
	draw_string(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _loop_point(progress: float) -> Vector2:
	var points: PackedVector2Array = _belt_path_points()
	if points.size() < 2:
		return belt_rect.get_center()
	var total_length: float = 0.0
	for index in range(points.size() - 1):
		total_length += points[index].distance_to(points[index + 1])
	var distance_left: float = clamp(progress, 0.0, BELT_END) * total_length
	for index in range(points.size() - 1):
		var segment_length: float = points[index].distance_to(points[index + 1])
		if distance_left <= segment_length:
			if segment_length <= 0.0:
				return points[index]
			return points[index].lerp(points[index + 1], distance_left / segment_length)
		distance_left -= segment_length
	return points[points.size() - 1]

func _belt_path_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for normalized_point in belt_path_points:
		points.append(belt_rect.position + Vector2(normalized_point.x * belt_rect.size.x, normalized_point.y * belt_rect.size.y))
	return points

func _path_segment_at_progress(progress: float) -> int:
	var points: PackedVector2Array = _belt_path_points()
	if points.size() < 2:
		return -1
	var total_length: float = _path_total_length(points)
	var distance_left: float = clamp(progress, 0.0, BELT_END) * total_length
	for index in range(points.size() - 1):
		var segment_length: float = points[index].distance_to(points[index + 1])
		if distance_left <= segment_length:
			return index
		distance_left -= segment_length
	return points.size() - 2

func _path_total_length(points: PackedVector2Array) -> float:
	var total_length: float = 0.0
	for index in range(points.size() - 1):
		total_length += points[index].distance_to(points[index + 1])
	return total_length

func _path_progress_for_point(point: Vector2) -> float:
	var points: PackedVector2Array = _belt_path_points()
	if points.size() < 2:
		return 0.0
	var total_length: float = _path_total_length(points)
	if total_length <= 0.0:
		return 0.0
	var best_distance: float = INF
	var best_path_distance: float = 0.0
	var distance_before: float = 0.0
	for index in range(points.size() - 1):
		var start: Vector2 = points[index]
		var end: Vector2 = points[index + 1]
		var segment: Vector2 = end - start
		var segment_length_squared: float = segment.length_squared()
		var ratio: float = 0.0
		if segment_length_squared > 0.0:
			ratio = clamp((point - start).dot(segment) / segment_length_squared, 0.0, 1.0)
		var projection: Vector2 = start.lerp(end, ratio)
		var distance: float = projection.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best_path_distance = distance_before + segment.length() * ratio
		distance_before += segment.length()
	return clamp(best_path_distance / total_length, 0.0, BELT_END)

func _forward_distance(from_progress: float, to_progress: float) -> float:
	return fmod(to_progress - from_progress + BELT_END, BELT_END)

func _did_pass_progress(old_progress: float, new_progress: float, target_progress: float) -> bool:
	if target_progress < 0.0:
		return false
	return old_progress <= target_progress and new_progress >= target_progress

func _dynamic_machine_count() -> int:
	return state.conveyorQueue.size()

func _board_cell_center(cell_id: String) -> Vector2:
	for cell in state.pattern:
		if cell.id == cell_id:
			var cell_size: Vector2 = Vector2(board_rect.size.x / float(_grid_columns()), board_rect.size.y / float(_grid_rows()))
			return board_rect.position + Vector2((cell.column + 0.5) * cell_size.x, (cell.row + 0.5) * cell_size.y)
	return board_rect.get_center()

func _update_weaving(delta: float) -> void:
	var finished: Array[Dictionary] = []
	for weave_session in weaving_sessions:
		if game_session != int(weave_session.get("session", -1)):
			continue
		weave_session.elapsed = float(weave_session.get("elapsed", 0.0)) + delta
		var completed_passes: int = int(weave_session.elapsed / WEAVE_PASS_DURATION)
		weave_session.pass_index = min(completed_passes, WEAVE_PASS_COUNT - 1)
		weave_session.pass_progress = clamp(fmod(weave_session.elapsed, WEAVE_PASS_DURATION) / WEAVE_PASS_DURATION, 0.0, 1.0)
		if weave_session.elapsed >= WEAVE_PASS_COUNT * WEAVE_PASS_DURATION:
			weave_session.pass_index = WEAVE_PASS_COUNT - 1
			weave_session.pass_progress = 1.0
		var target: Dictionary = _cell_by_id(str(weave_session.get("target_cell_id", "")))
		if not target.is_empty():
			weave_session.endpoint = _get_weave_endpoint(target, weave_session.pass_index, weave_session.pass_progress)
		if weave_session.elapsed >= WEAVE_PASS_COUNT * WEAVE_PASS_DURATION:
			finished.append(weave_session)
	for weave_session in finished:
		weaving_sessions.erase(weave_session)
		if game_session != int(weave_session.get("session", -1)):
			continue
		var item: Dictionary = weave_session.get("machine", {})
		var target: Dictionary = _cell_by_id(str(weave_session.get("target_cell_id", "")))
		_complete_stitch(item, target, str(weave_session.get("color", "")))

func _update_order_feedbacks(delta: float) -> void:
	var expired: Array[Dictionary] = []
	for feedback in order_feedbacks:
		feedback.elapsed = float(feedback.get("elapsed", 0.0)) + delta
		if feedback.elapsed >= ORDER_CHECK_DURATION:
			expired.append(feedback)
	for feedback in expired:
		order_feedbacks.erase(feedback)

func _draw_weaving_threads() -> void:
	for weave_session in weaving_sessions:
		var item: Dictionary = weave_session.get("machine", {})
		if item.is_empty():
			continue
		var start_point: Vector2 = _loop_point(float(item.get("progress", 0.0)))
		var end_point: Vector2 = weave_session.get("endpoint", board_rect.get_center())
		var color_key: String = str(weave_session.get("color", "coral"))
		var thread_color: Color = Color(COLORS[color_key].hex)
		draw_line(start_point, end_point, Color(1, 1, 1, 0.62), 8.0, true)
		draw_line(start_point, end_point, thread_color, 4.0, true)
		draw_circle(end_point, 5.5, Color(1, 1, 1, 0.9))
		draw_circle(end_point, 3.5, thread_color)

func _update_conveyor(delta: float) -> void:
	var finished: Array[Dictionary] = []
	for item in state.conveyorQueue:
		var old_progress: float = item.progress
		if not bool(item.get("processed", false)) and str(item.get("target_cell_id", "")) == "":
			_plan_machine_target(item)
		item.progress += delta * 0.22
		if not bool(item.get("processed", false)) and _did_pass_progress(old_progress, item.progress, float(item.get("target_progress", -1.0))):
			_start_dynamic_stitch(item)
		if item.progress >= BELT_END and (not bool(item.get("processed", false)) or item.status != "stitching"):
			finished.append(item)
	for item in finished:
		if item in state.conveyorQueue:
			state.conveyorQueue.erase(item)
		item.status = "finished"
		if not bool(item.get("processed", false)):
			_restore_machine_product(item)
	_try_finish_game()

func _restore_machine_product(item: Dictionary) -> void:
	var color: String = item.color
	state.machineCapacity[color] = int(state.machineCapacity.get(color, 0)) + 1
	_release_order(item)
	if state.holdingArea.size() >= MAX_HOLDING:
		_lose_game("待编制区已满，无法收回纺织机线团")
		return
	state.holdingArea.append({"id": item.id, "color": color, "waveIndex": -1, "groupIndex": -1})
	_show_toast("%s纺织机未找到目标，线团返回待编制区" % COLORS[color].label)

func _reserve_order(color: String) -> String:
	if state.currentWaveIndex < 0 or state.currentWaveIndex >= state.orderWaves.size():
		return ""
	var wave: Dictionary = state.orderWaves[state.currentWaveIndex]
	for order_value in wave.get("orders", []):
		var order: Dictionary = order_value
		if order.color == color and str(order.get("status", "pending")) == "pending":
			order.status = "reserved"
			return str(order.id)
	return ""

func _complete_order(item: Dictionary) -> void:
	var wave_index: int = int(item.get("dispatch_wave_index", -1))
	if wave_index < 0 or wave_index >= state.orderWaves.size():
		return
	var order_id: String = str(item.get("order_id", ""))
	var wave: Dictionary = state.orderWaves[wave_index]
	var slot_index: int = 0
	for order_value in wave.get("orders", []):
		var order: Dictionary = order_value
		if str(order.get("id", "")) == order_id:
			order.status = "completed"
			order_feedbacks.append({"order_id": order_id, "color": order.color, "slot_index": slot_index, "elapsed": 0.0, "session": game_session})
			return
		if str(order.get("status", "pending")) != "completed":
			slot_index += 1

func _release_order(item: Dictionary) -> void:
	var wave_index: int = int(item.get("dispatch_wave_index", -1))
	if wave_index < 0 or wave_index >= state.orderWaves.size():
		return
	var order_id: String = str(item.get("order_id", ""))
	var wave: Dictionary = state.orderWaves[wave_index]
	for order_value in wave.get("orders", []):
		var order: Dictionary = order_value
		if str(order.get("id", "")) == order_id and str(order.get("status", "")) in ["reserved", "completed"]:
			order.status = "pending"
			_remove_order_feedback(order_id)
			return

func _remove_order_feedback(order_id: String) -> void:
	var remove_feedbacks: Array[Dictionary] = []
	for feedback in order_feedbacks:
		if str(feedback.get("order_id", "")) == order_id:
			remove_feedbacks.append(feedback)
	for feedback in remove_feedbacks:
		order_feedbacks.erase(feedback)

func _try_finish_game() -> void:
	if state.status != "playing":
		return
	if state.stitchedCells.size() >= state.activeCellIds.size() and state.conveyorQueue.is_empty() and weaving_sessions.is_empty():
		state.status = "won"

func _plan_machine_target(item: Dictionary) -> void:
	var item_wave_index: int = int(item.get("dispatch_wave_index", state.currentWaveIndex))
	if item_wave_index < 0 or item_wave_index >= state.orderWaves.size():
		item.target_progress = 0.0
		return
	var wave: Dictionary = state.orderWaves[item_wave_index]
	var candidates: Array[Dictionary] = []
	var occupied: Array[String] = _occupied_target_ids()
	for cell_id in wave.cellIds:
		if occupied.has(cell_id) or cell_id in state.stitchedCells:
			continue
		for cell in state.pattern:
			if cell.id == cell_id and cell.color == item.color:
				candidates.append(cell)
	if candidates.is_empty():
		item.target_progress = BELT_END
		return
	var best_candidate: Dictionary = candidates[0]
	var best_distance: float = INF
	for candidate in candidates:
		var cell_point: Vector2 = _board_cell_center(candidate.id)
		var candidate_progress: float = _path_progress_for_point(cell_point)
		var forward_distance: float = _forward_distance(item.progress, candidate_progress)
		if forward_distance < best_distance:
			best_distance = forward_distance
			best_candidate = candidate
	item.target_progress = item.progress + best_distance
	item.target_cell_id = best_candidate.id

func _occupied_target_ids() -> Array[String]:
	var occupied: Array[String] = []
	for item in state.conveyorQueue:
		var target_id: String = str(item.get("target_cell_id", ""))
		if target_id != "":
			occupied.append(target_id)
	return occupied

func _cell_by_id(cell_id: String) -> Dictionary:
	for cell in state.pattern:
		if cell.id == cell_id:
			return cell
	return {}

func _start_dynamic_stitch(item: Dictionary) -> void:
	if bool(item.get("processed", false)):
		return
	var target_id: String = str(item.get("target_cell_id", ""))
	if target_id == "":
		_plan_machine_target(item)
		target_id = str(item.get("target_cell_id", ""))
	if target_id == "":
		return
	var target: Dictionary = {}
	for cell in state.pattern:
		if cell.id == target_id:
			target = cell
			break
	if target.is_empty() or target.id in state.stitchedCells:
		return
	item.processed = true
	item.status = "stitching"
	item.yarn_visible = false
	weaving_sessions.append({
		"machine_id": item.id,
		"target_cell_id": target.id,
		"color": item.color,
		"elapsed": 0.0,
		"pass_index": 0,
		"pass_progress": 0.0,
		"endpoint": _get_weave_endpoint(target, 0, 0.0),
		"machine": item,
		"session": game_session
	})

func _complete_stitch(item: Dictionary, target: Dictionary, color: String) -> void:
	if state.status != "playing" or item.status != "stitching" or target.is_empty():
		return
	if target.id not in state.stitchedCells:
		state.stitchedCells.append(target.id)
	item.status = "moving"
	_show_toast("%s订单完成" % COLORS[color].label)
	_try_finish_game()

func _is_wave_complete() -> bool:
	var wave: Dictionary = state.orderWaves[state.currentWaveIndex]
	for order_value in wave.get("orders", []):
		var order: Dictionary = order_value
		if str(order.get("status", "pending")) != "completed":
			return false
	return true

func _advance_wave_if_ready() -> void:
	if state.status != "playing" or not _is_wave_complete():
		return
	if state.currentWaveIndex >= state.orderWaves.size() - 1:
		return
	state.currentWaveIndex += 1
	var next_wave: Dictionary = state.orderWaves[state.currentWaveIndex]
	state.machineCapacity = {}
	for color in COLOR_KEYS:
		state.machineCapacity[color] = next_wave.quotas.get(color, 0)
	var labels: Array[String] = []
	for color in next_wave.publishedColors:
		labels.append(COLORS[color].label)
	_show_toast("第 %02d 波订单：%s" % [state.currentWaveIndex + 1, "、".join(labels)])

func _dispatch_lane(lane_index: int, ball_index: int) -> void:
	if state.status != "playing":
		return
	if lane_index < 0 or lane_index >= state.materialLanes.size():
		return
	var lane: Dictionary = state.materialLanes[lane_index]
	if lane.balls.is_empty():
		_refill_material_lane(lane_index)
	if lane.balls.is_empty():
		return
	var selectable_count: int = int(floor(MATERIAL_VISIBLE_BALLS))
	if ball_index < 0 or ball_index >= min(selectable_count, lane.balls.size()):
		return
	var ball: Dictionary = lane.balls[ball_index]
	if state.holdingArea.size() == MAX_HOLDING - 1 and not _can_complete_holding_match(ball.color):
		_lose_game("待编制区已有 4 个线团，当前线团无法合成")
		return
	if not _can_add_to_holding(ball.color):
		_lose_game("待编制区已满，无法继续取线团")
		return
	lane.balls.remove_at(ball_index)
	if lane.balls.is_empty():
		_refill_material_lane(lane_index)
	state.holdingArea.append(ball)
	_show_toast("%s线团进入待编制区" % COLORS[ball.color].label)
	_try_match_holding()

func _can_complete_holding_match(color: String) -> bool:
	if state.conveyorQueue.size() >= MAX_QUEUE:
		return false
	if state.currentWaveIndex < 0 or state.currentWaveIndex >= state.orderWaves.size():
		return false
	var wave: Dictionary = state.orderWaves[state.currentWaveIndex]
	if not wave.publishedColors.has(color) or int(state.machineCapacity.get(color, 0)) <= 0:
		return false
	var same_count: int = 0
	for held_ball in state.holdingArea:
		if held_ball.color == color:
			same_count += 1
	return same_count >= 2

func _material_ball_index_at_point(lane_index: int, point: Vector2) -> int:
	if lane_index < 0 or lane_index >= state.materialLanes.size():
		return -1
	var lane: Dictionary = state.materialLanes[lane_index]
	var rect: Rect2 = lane_rects[lane_index]
	var visible_ball_count: int = min(lane.balls.size(), int(ceil(MATERIAL_VISIBLE_BALLS)))
	var selectable_count: int = int(floor(MATERIAL_VISIBLE_BALLS))
	for ball_index in range(visible_ball_count):
		var visible_height: float = MATERIAL_BALL_SIZE if ball_index < selectable_count else MATERIAL_BALL_SIZE * 0.5
		var ball_rect: Rect2 = Rect2(
			rect.position + Vector2((rect.size.x - MATERIAL_BALL_SIZE) * 0.5, 30 + ball_index * MATERIAL_BALL_STEP),
			Vector2(MATERIAL_BALL_SIZE, visible_height)
		)
		if ball_rect.has_point(point):
			return ball_index if ball_index < selectable_count else -1
	return -1

func _refill_material_lane(lane_index: int) -> void:
	if lane_index < 0 or lane_index >= state.materialLanes.size():
		return
	var lane: Dictionary = state.materialLanes[lane_index]
	var refill_color: String = _next_refill_color()
	var refill_wave_index: int = state.currentWaveIndex if _is_current_color_needed(refill_color) else -1
	for _index in range(MATERIAL_REFILL_BATCH):
		lane.balls.append({"id": next_ball_id, "color": refill_color, "waveIndex": refill_wave_index, "groupIndex": -1})
		next_ball_id += 1

func _is_current_color_needed(color: String) -> bool:
	if state.is_empty() or state.currentWaveIndex < 0 or state.currentWaveIndex >= state.orderWaves.size():
		return false
	var wave: Dictionary = state.orderWaves[state.currentWaveIndex]
	return wave.publishedColors.has(color) and int(state.machineCapacity.get(color, 0)) > 0

func _next_refill_color() -> String:
	var needed_colors: Array = []
	for color in COLOR_KEYS:
		if _is_current_color_needed(color):
			needed_colors.append(color)
	if not needed_colors.is_empty():
		return str(_shuffle(needed_colors)[0])
	var filler_colors: Array = []
	for color in COLOR_KEYS:
		if not _is_current_color_needed(color):
			filler_colors.append(color)
	if filler_colors.is_empty():
		filler_colors = COLOR_KEYS.duplicate()
	return str(_shuffle(filler_colors)[0])

func _can_add_to_holding(color: String) -> bool:
	if state.holdingArea.size() < MAX_HOLDING:
		return true
	if state.conveyorQueue.size() >= MAX_QUEUE:
		return false
	var wave: Dictionary = state.orderWaves[state.currentWaveIndex]
	if not wave.publishedColors.has(color) or state.machineCapacity.get(color, 0) <= 0:
		return false
	var same_count: int = 0
	for held_ball in state.holdingArea:
		if held_ball.color == color:
			same_count += 1
	return same_count >= 2

func _try_match_holding() -> void:
	if state.status != "playing" or state.holdingArea.is_empty():
		return
	while state.conveyorQueue.size() < MAX_QUEUE:
		var wave: Dictionary = state.orderWaves[state.currentWaveIndex]
		var match_color: String = ""
		for candidate in _shuffle(COLOR_KEYS):
			var color: String = str(candidate)
			if not wave.publishedColors.has(color) or state.machineCapacity.get(color, 0) <= 0:
				continue
			var same_indices: Array[int] = []
			for holding_index in range(state.holdingArea.size()):
				if state.holdingArea[holding_index].color == color:
					same_indices.append(holding_index)
			if same_indices.size() >= 3:
				match_color = color
				break
		if match_color == "":
			return
		var order_id: String = _reserve_order(match_color)
		if order_id == "":
			return
		var remove_indices: Array[int] = []
		for holding_index in range(state.holdingArea.size()):
			if state.holdingArea[holding_index].color == match_color and remove_indices.size() < 3:
				remove_indices.append(holding_index)
		for index in range(remove_indices.size() - 1, -1, -1):
			state.holdingArea.remove_at(remove_indices[index])
		var product: Dictionary = {"id": next_ball_id, "color": match_color, "waveIndex": state.currentWaveIndex, "groupIndex": -1, "order_id": order_id}
		next_ball_id += 1
		state.machineCapacity[match_color] = max(0, int(state.machineCapacity.get(match_color, 0)) - 1)
		var machine: Dictionary = _make_dynamic_machine(product)
		_complete_order(machine)
		state.conveyorQueue.append(machine)
		_show_toast("3 个%s线团合成，送上传送带" % COLORS[match_color].label)

func _lose_game(message: String) -> void:
	state.status = "lost"
	_show_toast(message)

func _make_dynamic_machine(ball: Dictionary) -> Dictionary:
	var spawn_progress: float = min(0.32, state.conveyorQueue.size() * 0.08)
	return {
		"id": ball.id,
		"color": ball.color,
		"order_id": str(ball.get("order_id", "")),
		"progress": spawn_progress,
		"status": "moving",
		"target_progress": -1.0,
		"target_cell_id": "",
		"yarn_visible": true,
		"dispatch_wave_index": state.currentWaveIndex,
		"processed": false
	}

func _show_toast(message: String) -> void:
	toast_text = message
	toast_left = 2.1

func _handle_virtual_input(point: Vector2) -> void:
	if pause_rect.has_point(point) and not state.is_empty() and state.status == "playing":
		game_paused = not game_paused
		_show_toast("游戏已暂停" if game_paused else "继续绣制")
		return
	if state.status != "playing":
		if Rect2(72, 473, 246, 35).has_point(point):
			if state.status == "won" and runtime_level_index < _level_count() - 1:
				runtime_level_index += 1
			_reset_game()
		return
	if game_paused:
		_show_toast("游戏已暂停")
		return
	for lane_index in range(lane_rects.size()):
		if lane_rects[lane_index].has_point(point):
			var ball_index: int = _material_ball_index_at_point(lane_index, point)
			if ball_index >= 0:
				_dispatch_lane(lane_index, ball_index)
			return

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset_game()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_virtual_input((event.position - canvas_origin) / canvas_scale)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_virtual_input((event.position - canvas_origin) / canvas_scale)

func _reset_game() -> void:
	game_session += 1
	weaving_sessions.clear()
	order_feedbacks.clear()
	next_ball_id = 1
	game_paused = false
	toast_text = ""
	var level: Dictionary = _create_level()
	var initial_wave: Dictionary = level.orderWaves[0] if not level.orderWaves.is_empty() else {"quotas": {}}
	state = {
		"pattern": level.pattern,
		"activeCellIds": level.activeCellIds,
		"levelSeed": level.levelSeed,
		"totalMachineCapacity": level.totalMachineCapacity,
		"orderWaves": level.orderWaves,
		"currentWaveIndex": 0,
		"stitchedCells": [],
		"materialLanes": _create_material_lanes(level),
		"conveyorQueue": [],
		"weavingSessions": weaving_sessions,
		"holdingArea": [],
		"machineCapacity": {},
		"status": "won" if level.activeCellIds.is_empty() else "playing"
	}
	for color in COLOR_KEYS:
		state.machineCapacity[color] = initial_wave.quotas.get(color, 0)
	toast_left = 0.0

func _create_level() -> Dictionary:
	var seed_value: int = randi()
	rng.seed = seed_value
	var level_pattern: Array[Dictionary] = _base_pattern()
	var total_capacity: Dictionary = {}
	for color in COLOR_KEYS:
		var range_value: Vector2i = CAPACITY_RANGES[color]
		var available_count: int = 0
		for cell in level_pattern:
			if cell.color == color:
				available_count += 1
		var capacity_max: int = min(range_value.y, available_count)
		var capacity_min: int = min(range_value.x, capacity_max)
		total_capacity[color] = rng.randi_range(capacity_min, capacity_max)
	for color in COLOR_KEYS:
		var available: Array = []
		for cell in level_pattern:
			if cell.color == color:
				available.append(cell)
		available = _shuffle(available)
		for index in range(min(total_capacity[color], available.size())):
			available[index].active = true
	var active_by_color: Dictionary = {}
	var active_offsets: Dictionary = {}
	for color in COLOR_KEYS:
		var active_cells: Array = []
		for cell in level_pattern:
			if cell.active and cell.color == color:
				active_cells.append(cell)
		active_by_color[color] = _shuffle(active_cells)
		active_offsets[color] = 0
	var remaining: Dictionary = total_capacity.duplicate()
	var waves: Array[Dictionary] = []
	var first_wave: bool = true
	while _sum_dictionary(remaining) > 0:
		var available_colors: Array = []
		for color in COLOR_KEYS:
			if remaining[color] > 0:
				available_colors.append(color)
		var published: Array = []
		if first_wave and remaining.coral > 0:
			published.append("coral")
			var secondary_colors: Array = []
			for candidate_color in available_colors:
				if candidate_color != "coral":
					secondary_colors.append(candidate_color)
			if not secondary_colors.is_empty():
				published.append(_shuffle(secondary_colors)[0])
		else:
			published = _shuffle(available_colors).slice(0, min(WAVE_MACHINE_COUNT, available_colors.size()))
		var order_limit: int = min(MAX_ORDERS_PER_WAVE, _sum_dictionary(remaining))
		var order_count: int = rng.randi_range(1, order_limit) if order_limit > 1 else order_limit
		var orders: Array[Dictionary] = []
		var quotas: Dictionary = {}
		var cell_ids: Array[String] = []
		var wave_id: int = waves.size() + 1
		if first_wave and remaining.get("coral", 0) > 0:
			var coral_cells: Array = active_by_color["coral"]
			var coral_offset: int = active_offsets["coral"]
			orders.append({"id": "%d-%d" % [wave_id, orders.size() + 1], "color": "coral", "status": "pending"})
			quotas["coral"] = 1
			cell_ids.append(coral_cells[coral_offset].id)
			active_offsets["coral"] = coral_offset + 1
			remaining["coral"] -= 1
		while orders.size() < order_count:
			var order_colors: Array = []
			for color in published:
				if int(remaining.get(color, 0)) > 0:
					order_colors.append(color)
			if order_colors.is_empty():
				break
			var order_color: String = str(_shuffle(order_colors)[0])
			var color_cells: Array = active_by_color[order_color]
			var color_offset: int = active_offsets[order_color]
			orders.append({"id": "%d-%d" % [wave_id, orders.size() + 1], "color": order_color, "status": "pending"})
			quotas[order_color] = int(quotas.get(order_color, 0)) + 1
			cell_ids.append(color_cells[color_offset].id)
			active_offsets[order_color] = color_offset + 1
			remaining[order_color] -= 1
		published = []
		for order in orders:
			if not published.has(order.color):
				published.append(order.color)
		waves.append({"id": wave_id, "publishedColors": published, "quotas": quotas, "cellIds": cell_ids, "orders": orders})
		first_wave = false
	if waves.is_empty():
		waves.append({"id": 1, "publishedColors": [], "quotas": {}, "cellIds": [], "orders": []})
	var active_ids: Array[String] = []
	for cell in level_pattern:
		if cell.active:
			active_ids.append(cell.id)
	return {"levelSeed": seed_value, "pattern": level_pattern, "totalMachineCapacity": total_capacity, "activeCellIds": active_ids, "orderWaves": waves}

func _base_pattern() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var grid_columns: int = _grid_columns()
	var grid_rows: int = _grid_rows()
	var layout_rows: PackedStringArray = _configured_pattern_layout().replace("\r", "").split("\n")
	for row_index in range(grid_rows):
		var row: String = layout_rows[row_index] if row_index < layout_rows.size() else ""
		row = row.replace("\t", ".").replace(" ", ".")
		while row.length() < grid_columns:
			row += "."
		if row.length() > grid_columns:
			row = row.substr(0, grid_columns)
		for column in range(grid_columns):
			var key: String = CHAR_TO_COLOR.get(row.substr(column, 1), "")
			if key != "":
				result.append({"id": "%d-%d" % [row_index, column], "row": row_index, "column": column, "color": key, "active": false})
	return result

func _create_material_lanes(level: Dictionary) -> Array[Dictionary]:
	var active_balls: Array = []
	var group_index: int = 0
	for wave_index in range(level.orderWaves.size()):
		var wave: Dictionary = level.orderWaves[wave_index]
		for cell_id in wave.cellIds:
			for cell in level.pattern:
				if cell.id == cell_id:
					for _source_index in range(3):
						active_balls.append({"id": next_ball_id, "color": cell.color, "waveIndex": wave_index, "groupIndex": group_index})
						next_ball_id += 1
					group_index += 1
	var spare_balls: Array = []
	var spare_target: int = max(0, 40 - active_balls.size())
	var spare_colors: Array[String] = ["coral", "sun", "leaf", "lake", "deep_blue", "coral", "sun", "leaf", "lake", "deep_blue"]
	for spare_index in range(spare_target):
		var spare_color: String = spare_colors[spare_index % spare_colors.size()]
		spare_balls.append({"id": next_ball_id, "color": spare_color, "waveIndex": -1, "groupIndex": -1})
		next_ball_id += 1
	var ordered: Array = active_balls + spare_balls
	for attempt in range(SAFE_LAYOUT_ATTEMPTS):
		var lanes: Array[Dictionary] = _build_material_lanes(ordered)
		if _has_tri_safe_route(lanes, level.orderWaves):
			return lanes
	return _build_safe_material_lanes(ordered, level.orderWaves)

func _build_material_lanes(ordered: Array) -> Array[Dictionary]:
	var lanes: Array[Dictionary] = [{"id": 1, "balls": []}, {"id": 2, "balls": []}, {"id": 3, "balls": []}, {"id": 4, "balls": []}]
	var random_order: Array = _shuffle(ordered)
	var lane_order: Array = _shuffle([0, 1, 2, 3])
	for index in range(random_order.size()):
		lanes[lane_order[index % 4]].balls.append(random_order[index])
	return lanes

func _build_safe_material_lanes(ordered: Array, waves: Array[Dictionary]) -> Array[Dictionary]:
	# Fallback keeps each three-ball source group together and puts spare balls at
	# the bottoms of the lanes, so every order wave has a guaranteed route.
	var lanes: Array[Dictionary] = [{"id": 1, "balls": []}, {"id": 2, "balls": []}, {"id": 3, "balls": []}, {"id": 4, "balls": []}]
	var groups: Dictionary = {}
	var spares: Array = []
	for ball in ordered:
		var ball_group: int = int(ball.get("groupIndex", -1))
		if ball_group < 0:
			spares.append(ball)
		else:
			if not groups.has(ball_group):
				groups[ball_group] = []
			groups[ball_group].append(ball)
	var group_ids: Array = _shuffle(groups.keys())
	for group_id in group_ids:
		var target_lane: int = 0
		for lane_index in range(1, lanes.size()):
			if lanes[lane_index].balls.size() < lanes[target_lane].balls.size():
				target_lane = lane_index
		for ball in groups[group_id]:
			lanes[target_lane].balls.append(ball)
	for spare in spares:
		var target_lane: int = 0
		for lane_index in range(1, lanes.size()):
			if lanes[lane_index].balls.size() < lanes[target_lane].balls.size():
				target_lane = lane_index
		if lanes[target_lane].balls.size() < 10:
			lanes[target_lane].balls.append(spare)
	return lanes

func _has_tri_safe_route(lanes: Array[Dictionary], waves: Array[Dictionary]) -> bool:
	var holding_counts: Dictionary = {}
	for color in COLOR_KEYS:
		holding_counts[color] = 0
	return _search_tri_safe_route(lanes, waves, 0, [0, 0, 0, 0], holding_counts, {}, {})

func _search_tri_safe_route(lanes: Array[Dictionary], waves: Array[Dictionary], wave_index: int, positions: Array, holding_counts: Dictionary, quota_left: Dictionary, memo: Dictionary) -> bool:
	if wave_index >= waves.size():
		return true
	var wave: Dictionary = waves[wave_index]
	var remaining: Dictionary = quota_left.duplicate()
	if remaining.is_empty():
		remaining = wave.quotas.duplicate()
	var holding_key: String = ""
	for color in COLOR_KEYS:
		holding_key += "%d," % holding_counts.get(color, 0)
	var position_key: String = "%d,%d,%d,%d" % [positions[0], positions[1], positions[2], positions[3]]
	var quota_key: String = ""
	for color in COLOR_KEYS:
		quota_key += "%d," % remaining.get(color, 0)
	var memo_key: String = "%d|%s|%s|%s" % [wave_index, position_key, holding_key, quota_key]
	if memo.has(memo_key):
		return memo[memo_key]
	if _sum_dictionary(remaining) <= 0:
		for color in COLOR_KEYS:
			if holding_counts.get(color, 0) != 0:
				memo[memo_key] = false
				return false
		var advanced: bool = _search_tri_safe_route(lanes, waves, wave_index + 1, positions, holding_counts, {}, memo)
		memo[memo_key] = advanced
		return advanced
	for lane_index in range(lanes.size()):
		var position: int = positions[lane_index]
		if position >= lanes[lane_index].balls.size():
			continue
		var ball: Dictionary = lanes[lane_index].balls[position]
		if int(ball.get("waveIndex", -1)) != wave_index:
			continue
		var color: String = ball.color
		var held_count: int = holding_counts.get(color, 0)
		if _sum_dictionary(holding_counts) >= MAX_HOLDING and held_count < 2:
			continue
		var next_positions: Array = positions.duplicate()
		next_positions[lane_index] += 1
		var next_holding: Dictionary = holding_counts.duplicate()
		var next_quota: Dictionary = remaining.duplicate()
		if held_count >= 2:
			if next_quota.get(color, 0) <= 0:
				continue
			next_holding[color] = 0
			next_quota[color] -= 1
		else:
			next_holding[color] = held_count + 1
		if _search_tri_safe_route(lanes, waves, wave_index, next_positions, next_holding, next_quota, memo):
			memo[memo_key] = true
			return true
	memo[memo_key] = false
	return false

func _sum_dictionary(values: Dictionary) -> int:
	var total: int = 0
	for value in values.values():
		total += value
	return total

func _shuffle(items: Array) -> Array:
	var result: Array = items.duplicate()
	for index in range(result.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temp: Variant = result[index]
		result[index] = result[swap_index]
		result[swap_index] = temp
	return result
