@tool
extends Control

## Native Godot 4 port of the conveyor cross-stitch game.
## All gameplay lives here; art slots are exported so the scene can be reskinned in Inspector.

const VIRTUAL_SIZE := Vector2(390.0, 844.0)
const LEVEL_DIRECTORY := "res://levels"
const COLOR_KEYS := ["coral", "orange", "sun", "olive", "leaf", "lake", "deep_blue", "purple", "pink"]
const BELT_END := 1.0
const WEAVE_PASS_COUNT := 5
const WEAVE_PASS_BASE_DURATION := 0.28
const WEAVE_SPEED_MULTIPLIER := 1.5
const WEAVE_PASS_DURATION := WEAVE_PASS_BASE_DURATION / WEAVE_SPEED_MULTIPLIER
const LINK_TILE_KEYS := [
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
	"k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
	"u", "v", "w", "x", "y", "z"
]
const DEFAULT_LINK_TILE_STYLE_COUNTS := [6, 6, 6, 6, 6, 6, 6, 6, 6]
const LINK_PRODUCT_DURATION := 0.55
const VICTORY_FLOAT_DURATION := 0.9
const LINK_SELECTION_PULSE_DURATION := 0.28
const LINK_SELECTION_PULSE_AMPLITUDE := 0.18
const LINK_ELIMINATION_PULSE_AMPLITUDE := 0.45
const DEFAULT_PATTERN_LAYOUT := "cc..dd..cc\nc..yyyy..c\n..yyyyyy..\n.yyggggyy.\nyyggbbggyy\nyyggbbggyy\n.yyggggyy.\n..yyyyyy..\nc..yyyy..c\ncc..dd..cc"
const CHAR_TO_COLOR := {"c": "coral", "o": "orange", "y": "sun", "v": "olive", "g": "leaf", "b": "lake", "l": "lake", "d": "deep_blue", "p": "purple", "r": "pink"}
const SHARED_CHAR_TO_COLOR := {"C": "coral", "O": "orange", "Y": "sun", "V": "olive", "G": "leaf", "A": "lake", "L": "lake", "D": "deep_blue", "P": "purple", "R": "pink"}
const COLORS := {
	"coral": {"label": "珊瑚红", "hex": "#e86b5b", "dark": "#bd4c42", "pale": "#fde9e3"},
	"orange": {"label": "橙色", "hex": "#f27618", "dark": "#ba4f0f", "pale": "#fff0df"},
	"sun": {"label": "向日黄", "hex": "#e6b93f", "dark": "#a8781d", "pale": "#fff5d8"},
	"olive": {"label": "橄榄绿", "hex": "#8bb900", "dark": "#587800", "pale": "#f1f8d7"},
	"leaf": {"label": "叶绿色", "hex": "#5b9c72", "dark": "#377453", "pale": "#e7f3e9"},
	"lake": {"label": "湖蓝色", "hex": "#16b7c5", "dark": "#087987", "pale": "#e0f7f8"},
	"deep_blue": {"label": "深蓝色", "hex": "#1474d4", "dark": "#0d4d99", "pale": "#e4efff"},
	"purple": {"label": "紫色", "hex": "#8f2bd8", "dark": "#601a9d", "pale": "#f1e5ff"},
	"pink": {"label": "粉色", "hex": "#ed2164", "dark": "#aa1648", "pale": "#ffe5ef"}
}

@export_category("Art Slots")
@export var background_texture: Texture2D
@export var score_panel_texture: Texture2D
@export var level_panel_texture: Texture2D
@export var pause_texture: Texture2D
@export var add_time_texture: Texture2D
@export var shuffle_texture: Texture2D
@export var auto_clear_texture: Texture2D
@export var tool_slot_background_texture: Texture2D
@export var material_panel_texture: Texture2D
@export var board_texture: Texture2D
@export var link_tile_background_texture: Texture2D
@export_group("连连看图标样式")
@export var link_tile_textures: Array[Texture2D] = []:
	set(value):
		link_tile_textures = value
		if is_inside_tree():
			_refresh_editor_preview()
@export var link_tile_style_counts: Array[int] = [6, 6, 6, 6, 6, 6, 6, 6, 6]:
	set(value):
		link_tile_style_counts = _normalize_style_counts(value)
		if is_inside_tree():
			_refresh_editor_preview()
@export var unstitched_block_texture: Texture2D
@export var belt_texture: Texture2D
@export var machine_left_texture: Texture2D
@export var machine_bottom_texture: Texture2D
@export var machine_right_texture: Texture2D
@export var yarn_textures: Array[Texture2D] = []
@export var stitched_block_textures: Array[Texture2D] = []

@export_storage var link_grid_size: Vector2i = Vector2i(12, 12):
	set(value):
		link_grid_size = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		_refresh_editor_preview()

@export_category("Level Editing")
@export_storage var level_configs: Array[StitchLevelPattern] = []:
	set(value):
		level_configs = value
		editor_preview_level_index = _clamp_level_index(editor_preview_level_index)
		_connect_level_config_signals()
		_refresh_editor_preview()
@export var level_files: Array[String] = []:
	set(value):
		level_files = value.duplicate()
		if is_inside_tree():
			_load_external_level_configs()
@export_range(0, 99, 1) var start_level_index: int = 0
@export_storage var pattern_grid_size: Vector2i = Vector2i(10, 10):
	set(value):
		pattern_grid_size = Vector2i(max(value.x, 1), max(value.y, 1))
		_refresh_editor_preview()
@export_storage var pattern_layout: String = DEFAULT_PATTERN_LAYOUT:
	set(value):
		pattern_layout = value
		_refresh_editor_preview()
@export_storage var link_layout: String = "":
	set(value):
		link_layout = value
		_refresh_editor_preview()

@export_category("Shared Game Grid")
@export var shared_grid_margin: Vector2 = Vector2(12, 12)
@export_multiline var game_grid_layout: String = "":
	set(value):
		game_grid_layout = value
		_refresh_editor_preview()
@export_multiline var stitch_requirement_layout: String = "":
	set(value):
		stitch_requirement_layout = value
		_refresh_editor_preview()
@export_storage var auto_generate_link_tiles: bool = true

@export_category("Layout Editing")
@export var layout_grid_size: Vector2i = Vector2i(10, 25):
	set(value):
		var normalized := Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		if layout_grid_size == normalized:
			return
		layout_grid_size = normalized
		_refresh_editor_preview()
@export var belt_grid_position: Vector2i = Vector2i(0, 0)
@export var belt_grid_size: Vector2i = Vector2i(8, 8)
@export var layout_configured: bool = false
@export_storage var link_board_grid_position: Vector2i = Vector2i.ZERO
@export_storage var link_board_grid_size: Vector2i = Vector2i.ZERO

@export_group("胜利 UI")
@export var victory_panel_rect: Rect2 = Rect2(42, 216, 306, 304)
@export var victory_pattern_rect: Rect2 = Rect2(141, 238, 108, 108)
@export var result_action_rect: Rect2 = Rect2(72, 536, 246, 42)

@export_category("场景 UI 布局")
@export_node_path("Control") var score_ui_node_path: NodePath = NodePath("UI/ScoreUI")
@export_node_path("Control") var level_ui_node_path: NodePath = NodePath("UI/LevelUI")
@export_node_path("Control") var pause_ui_node_path: NodePath = NodePath("UI/PauseUI")
@export_node_path("Control") var add_time_ui_node_path: NodePath = NodePath("UI/AddTimeUI")
@export_node_path("Control") var shuffle_ui_node_path: NodePath = NodePath("UI/ShuffleUI")
@export_node_path("Control") var auto_clear_ui_node_path: NodePath = NodePath("UI/AutoClearUI")

@export_category("Layout - 390x844")
@export var score_rect: Rect2 = Rect2(18, 20, 126, 46)
@export var level_rect: Rect2 = Rect2(137, 20, 128, 46)
@export var pause_rect: Rect2 = Rect2(304, 17, 68, 54)
@export var belt_panel_rect: Rect2 = Rect2(12, 80, 366, 350)
@export var belt_path_points: PackedVector2Array = PackedVector2Array([
	Vector2(0.10, 0.10),
	Vector2(0.88, 0.10),
	Vector2(0.90, 0.90),
	Vector2(0.15, 0.90),
	Vector2(0.15, 0.31)
])
@export var materials_panel_rect: Rect2 = Rect2(12, 440, 366, 390)
@export_group("连连看 UI")
@export var link_board_rect: Rect2 = Rect2(18, 460, 354, 354)
@export_range(0.0, 0.5, 0.01) var link_cell_gap_ratio: float = 0.02
@export var link_tile_selected_color: Color = Color(1.0, 0.72, 0.14, 0.52)
@export_group("编制区域")
@export var board_layout_rect: Rect2 = Rect2(78, 153, 236, 236):
	set(value):
		if board_layout_rect == value:
			return
		board_layout_rect = value
		# Inspector edits must immediately rebuild the derived board rectangle,
		# including when the Main node is being previewed by the editor plugin.
		if is_inside_tree():
			_sync_layout()
			queue_redraw()
@export_node_path("Control") var stitch_area_node_path: NodePath = NodePath("StitchAreaUI")
@export_group("传送带对象尺寸")
@export var dynamic_machine_size: Vector2 = Vector2(58, 58):
	set(value):
		dynamic_machine_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		if is_inside_tree():
			queue_redraw()
@export_range(2.0, 40.0, 1.0) var conveyor_product_yarn_radius: float = 9.0:
	set(value):
		conveyor_product_yarn_radius = clampf(value, 2.0, 40.0)
		if is_inside_tree():
			queue_redraw()
@export_range(2.0, 40.0, 1.0) var machine_yarn_radius: float = 7.5:
	set(value):
		machine_yarn_radius = clampf(value, 2.0, 40.0)
		if is_inside_tree():
			queue_redraw()

var state: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var font: Font
var next_ball_id: int = 1
var game_session: int = 0
var canvas_scale: float = 1.0
var canvas_origin: Vector2 = Vector2.ZERO
var game_paused: bool = false
var pause_level_select_open: bool = false
var toast_text: String = ""
var toast_left: float = 0.0
var weaving_sessions: Array[Dictionary] = []
var link_products: Array[Dictionary] = []
var victory_snapshot: Array[Dictionary] = []
var victory_float_progress: float = 0.0
var victory_animation_active: bool = false
var runtime_level_index: int = 0
var editor_preview_level_index: int = 0
var editor_layout_override: Dictionary = {}
var level_load_error: String = ""

var belt_rect: Rect2 = Rect2(28, 174, 334, 338)
var board_rect: Rect2 = Rect2(108, 263, 174, 174)
var active_belt_panel_rect: Rect2 = belt_panel_rect
var active_link_board_rect: Rect2 = link_board_rect
var shared_grid_rect: Rect2 = Rect2(0, 0, VIRTUAL_SIZE.x, VIRTUAL_SIZE.y)

func _ready() -> void:
	font = ThemeDB.fallback_font
	_load_external_level_configs()
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
	if not state.is_empty() and float(state.get("linkEffectLeft", 0.0)) > 0.0:
		state.linkEffectElapsed = float(state.get("linkEffectElapsed", 0.0)) + delta
		state.linkEffectLeft = maxf(0.0, float(state.linkEffectLeft) - delta)
		if state.linkEffectLeft <= 0.0:
			_commit_link_removals()
	if not state.is_empty() and float(state.get("selectionPulseLeft", 0.0)) > 0.0:
		state.selectionPulseLeft = maxf(0.0, float(state.selectionPulseLeft) - delta)
	if not state.is_empty() and state.status == "playing":
		_update_link_products(delta)
		_update_conveyor(delta)
	if not state.is_empty():
		_update_weaving(delta)
		if state.status == "won" and victory_animation_active:
			victory_float_progress = minf(1.0, victory_float_progress + delta / VICTORY_FLOAT_DURATION)
			if victory_float_progress >= 1.0:
				victory_animation_active = false
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
	if Engine.is_editor_hint():
		_draw_editor_layout_overlay()
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
	active_belt_panel_rect = belt_panel_rect
	active_link_board_rect = link_board_rect
	_sync_configured_layout()
	# The configured belt area is the visible conveyor boundary. Keep only the
	# path and stitch-board insets inside it; do not add another outer margin.
	belt_rect = active_belt_panel_rect
	board_rect = _editable_stitch_area_rect() if _has_editable_stitch_area() else (_pattern_rect_for_belt() if _uses_shared_grid() else board_layout_rect)

func _has_editable_stitch_area() -> bool:
	return not stitch_area_node_path.is_empty() and get_node_or_null(stitch_area_node_path) is Control

func _editable_stitch_area_rect() -> Rect2:
	var area := get_node_or_null(stitch_area_node_path) as Control
	if area == null:
		return board_layout_rect
	var scale := area.scale.abs()
	var area_rect := Rect2(area.position, area.size * scale)
	if area_rect.size.x <= 1.0 or area_rect.size.y <= 1.0:
		return board_layout_rect
	return area_rect

func _ui_layout_rect(path: NodePath, fallback: Rect2) -> Rect2:
	var item := get_node_or_null(path) as Control
	if item == null or item.size.x <= 1.0 or item.size.y <= 1.0:
		return fallback
	var item_scale := item.scale.abs()
	var item_position := item.position
	return Rect2(item_position, item.size * item_scale)

func _pattern_rect_for_belt() -> Rect2:
	# board_layout_rect is the editable design size for the stitch-board base.
	# Keep it centered in the configured belt and clamp it so the base cannot
	# cover the belt border or extend outside a small belt.
	var requested_size := board_layout_rect.size
	if requested_size.x <= 1.0 or requested_size.y <= 1.0:
		var fallback_inset := clampf(minf(belt_rect.size.x, belt_rect.size.y) * 0.12, 8.0, 28.0)
		requested_size = (belt_rect.grow(-fallback_inset)).size
	# _draw_board() adds a 5 px outer frame around the board. Reserve only
	# that frame here so Inspector values such as 150 x 150 remain effective.
	var maximum_size := Vector2(maxf(40.0, belt_rect.size.x - 10.0), maxf(40.0, belt_rect.size.y - 10.0))
	var board_size := Vector2(
		clampf(requested_size.x, 40.0, maximum_size.x),
		clampf(requested_size.y, 40.0, maximum_size.y)
	)
	return Rect2(belt_rect.get_center() - board_size * 0.5, board_size)

func _shared_grid_cell_size() -> float:
	var columns := maxi(layout_grid_size.x, 1)
	var rows := maxi(layout_grid_size.y, 1)
	var margin := Vector2(maxf(shared_grid_margin.x, 0.0), maxf(shared_grid_margin.y, 0.0))
	var available := Vector2(maxf(VIRTUAL_SIZE.x - margin.x * 2.0, 1.0), maxf(VIRTUAL_SIZE.y - margin.y * 2.0, 1.0))
	return minf(available.x / float(columns), available.y / float(rows))

func _shared_grid_rect() -> Rect2:
	var cell := _shared_grid_cell_size()
	var grid_dimensions := Vector2(layout_grid_size) * cell
	return Rect2((VIRTUAL_SIZE - grid_dimensions) * 0.5, grid_dimensions)

func _shared_grid_cell_rect(row: int, column: int) -> Rect2:
	var cell := _shared_grid_cell_size()
	return Rect2(shared_grid_rect.position + Vector2(column, row) * cell, Vector2.ONE * cell)

func _uses_shared_grid() -> bool:
	# All current levels use the shared placement grid. The old separate
	# link-board layout is intentionally no longer a runtime mode.
	return true

func _rect_from_layout_grid(position: Vector2i, grid_size: Vector2i) -> Rect2:
	var cell := _shared_grid_cell_size()
	return Rect2(shared_grid_rect.position + Vector2(position) * cell, Vector2(grid_size) * cell)

func _has_valid_layout(position: Vector2i, grid_size: Vector2i) -> bool:
	return position.x >= 0 and position.y >= 0 and grid_size.x > 0 and grid_size.y > 0 and position.x + grid_size.x <= layout_grid_size.x and position.y + grid_size.y <= layout_grid_size.y

func _can_use_grid_layout(layout_size: Vector2i, belt_position: Vector2i, belt_size: Vector2i) -> bool:
	return layout_size.x > 0 and layout_size.y > 0 and belt_size.x >= 5 and belt_size.y >= 5 and belt_position.x >= 0 and belt_position.y >= 0 and belt_position.x + belt_size.x <= layout_size.x and belt_position.y + belt_size.y <= layout_size.y

func _sync_configured_layout() -> void:
	var config := _selected_pattern_config()
	var use_grid_layout := true
	var configured_layout_grid_size := layout_grid_size
	var configured_belt_position := belt_grid_position
	var configured_belt_size := belt_grid_size
	if Engine.is_editor_hint() and not editor_layout_override.is_empty():
		use_grid_layout = true
		configured_layout_grid_size = editor_layout_override.get("layout_grid_size", layout_grid_size)
		configured_belt_position = editor_layout_override.get("belt_grid_position", belt_grid_position)
		configured_belt_size = editor_layout_override.get("belt_grid_size", belt_grid_size)
	elif config:
		configured_layout_grid_size = config.get("layout_grid_size")
		configured_belt_position = config.get("belt_grid_position")
		configured_belt_size = config.get("belt_grid_size")
	if use_grid_layout and _uses_shared_grid() and _can_use_grid_layout(configured_layout_grid_size, configured_belt_position, configured_belt_size):
		layout_grid_size = configured_layout_grid_size
		shared_grid_rect = _shared_grid_rect()
		active_belt_panel_rect = _rect_from_layout_grid(configured_belt_position, configured_belt_size)
		active_link_board_rect = shared_grid_rect
	else:
		shared_grid_rect = Rect2(Vector2.ZERO, VIRTUAL_SIZE)

func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_sync_layout()
	weaving_sessions.clear()
	link_products.clear()
	var preview_pattern: Array[Dictionary] = _base_pattern()
	var active_ids: Array[String] = []
	for cell in preview_pattern:
		cell.active = not str(cell.get("required_tile_key", "")).is_empty()
		if cell.active:
			active_ids.append(cell.id)
	state = {
		"pattern": preview_pattern,
		"activeCellIds": active_ids,
		"levelSeed": 0,
		"stitchedCells": [],
		"conveyorQueue": [],
		"linkProducts": link_products,
		"weavingSessions": weaving_sessions,
		"linkTiles": _create_link_tiles(),
		"selectedTileId": "",
		"pendingLinkTileIds": [],
		"claimedStitchGroupIds": [],
		"linkPath": [],
		"linkEffectLeft": 0.0,
		"linkEffectElapsed": 0.0,
		"linkEffectDuration": 0.42,
		"selectionPulseLeft": 0.0,
		"conveyorSpeedMultiplier": 1.0,
		"linkEffectColor": "coral",
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

func _load_external_level_configs() -> void:
	if level_files.is_empty():
		return
	var loaded_levels: Array[StitchLevelPattern] = []
	var errors: Array[String] = []
	for file_path in level_files:
		var resource := ResourceLoader.load(file_path, "Resource", ResourceLoader.CACHE_MODE_REUSE)
		if resource is StitchLevelPattern:
			loaded_levels.append(resource)
		else:
			errors.append(str(file_path))
			var placeholder := StitchLevelPattern.new()
			placeholder.level_name = "加载失败：" + file_path.get_file()
			loaded_levels.append(placeholder)
	level_configs = loaded_levels
	if not errors.is_empty():
		level_load_error = "无法加载关卡文件：" + ", ".join(errors)
	else:
		level_load_error = ""

func editor_get_level_files() -> Array[String]:
	return level_files.duplicate()

func editor_get_level_load_error() -> String:
	return level_load_error

func editor_reload_level_files() -> void:
	_load_external_level_configs()

func editor_save_new_level(level: StitchLevelPattern) -> Dictionary:
	if level == null:
		return {"path": "", "error": "关卡资源为空"}
	var file_path := _next_level_file_path(level_configs.size())
	var error := ResourceSaver.save(level, file_path)
	if error != OK:
		return {"path": "", "error": "保存 %s 失败（错误码 %d）" % [file_path, error]}
	return {"path": file_path, "error": ""}

func editor_has_embedded_levels() -> bool:
	return level_files.is_empty() and not level_configs.is_empty()

func editor_list_level_files() -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(LEVEL_DIRECTORY)
	if directory == null:
		return result
	for file_name in directory.get_files():
		if file_name.to_lower().ends_with(".tres"):
			result.append(LEVEL_DIRECTORY + "/" + file_name)
	result.sort()
	return result

func editor_migrate_embedded_levels() -> Dictionary:
	if not editor_has_embedded_levels():
		return {"paths": level_files.duplicate(), "error": ""}
	var created: Array[String] = []
	for index in range(level_configs.size()):
		var source: StitchLevelPattern = level_configs[index]
		var copy: StitchLevelPattern = source.duplicate(true) as StitchLevelPattern
		var file_path := _next_level_file_path(index)
		var error := ResourceSaver.save(copy, file_path)
		if error != OK:
			return {"paths": [], "error": "保存 %s 失败（错误码 %d）" % [file_path, error]}
		created.append(file_path)
	return {"paths": created, "error": ""}

func editor_create_level_file(source_index: int, name_suffix: String = "副本") -> Dictionary:
	if source_index < 0 or source_index >= level_configs.size():
		return {"path": "", "error": "没有可复制的源关卡"}
	var source: StitchLevelPattern = level_configs[source_index]
	var copy: StitchLevelPattern = source.duplicate(true) as StitchLevelPattern
	copy.level_name = "%s %s" % [str(source.level_name), name_suffix]
	var file_path := _next_level_file_path(source_index)
	var error := ResourceSaver.save(copy, file_path)
	if error != OK:
		return {"path": "", "error": "保存 %s 失败（错误码 %d）" % [file_path, error]}
	return {"path": file_path, "error": ""}

func editor_save_level_file(index: int) -> String:
	if index < 0 or index >= level_configs.size() or index >= level_files.size():
		return "当前关卡没有对应的独立文件"
	var error := ResourceSaver.save(level_configs[index], level_files[index])
	return "" if error == OK else "保存 %s 失败（错误码 %d）" % [level_files[index], error]

func _next_level_file_path(seed_index: int) -> String:
	var used := {}
	for path in editor_list_level_files():
		used[path] = true
	for path in level_files:
		used[path] = true
	var serial := maxi(seed_index + 1, 1)
	while true:
		var candidate := "%s/level_%03d.tres" % [LEVEL_DIRECTORY, serial]
		if not used.has(candidate):
			return candidate
		serial += 1
	return "%s/level_%03d.tres" % [LEVEL_DIRECTORY, serial]

func _clamp_level_index(index: int) -> int:
	return clamp(index, 0, _level_count() - 1)

func _selected_pattern_config() -> StitchLevelPattern:
	if level_configs.is_empty():
		return null
	var index := editor_preview_level_index if Engine.is_editor_hint() else runtime_level_index
	return level_configs[_clamp_level_index(index)]

func _configured_grid_size() -> Vector2i:
	var config := _selected_pattern_config()
	if config:
		var configured: Vector2i = config.get("pattern_grid_size")
		if configured.x > 0 and configured.y > 0:
			return configured
	return pattern_grid_size

func _configured_pattern_layout() -> String:
	var config := _selected_pattern_config()
	if config:
		return str(config.get("pattern_layout"))
	return pattern_layout

func _configured_game_grid_layout() -> String:
	if Engine.is_editor_hint() and not editor_layout_override.is_empty():
		return str(editor_layout_override.get("game_grid_layout", ""))
	var config := _selected_pattern_config()
	if config:
		return str(config.get("game_grid_layout"))
	return game_grid_layout

func _uses_auto_generated_link_tiles() -> bool:
	return true

func _configured_link_grid_size() -> Vector2i:
	var config := _selected_pattern_config()
	if config:
		var configured: Vector2i = config.get("link_grid_size")
		if configured.x > 0 and configured.y > 0:
			return configured
	return link_grid_size

func _configured_link_layout() -> String:
	var config := _selected_pattern_config()
	return str(config.get("link_layout")) if config else link_layout

func _configured_requirement_layout() -> String:
	var config := _selected_pattern_config()
	return str(config.get("stitch_requirement_layout")) if config else stitch_requirement_layout

func _current_level_name() -> String:
	var config := _selected_pattern_config()
	return config.level_name if config and not config.level_name.is_empty() else "第 %02d 关" % (runtime_level_index + 1)

func _grid_columns() -> int:
	return maxi(layout_grid_size.x, 1)

func _grid_rows() -> int:
	return maxi(layout_grid_size.y, 1)

func _pattern_columns() -> int:
	return maxi(_configured_grid_size().x, 1)

func _pattern_rows() -> int:
	return maxi(_configured_grid_size().y, 1)

func _link_columns() -> int:
	return _grid_columns()

func _link_rows() -> int:
	return _grid_rows()

func _configured_belt_position() -> Vector2i:
	if Engine.is_editor_hint() and not editor_layout_override.is_empty():
		return editor_layout_override.get("belt_grid_position", belt_grid_position)
	var config := _selected_pattern_config()
	return config.get("belt_grid_position") if config else belt_grid_position

func _configured_belt_size() -> Vector2i:
	if Engine.is_editor_hint() and not editor_layout_override.is_empty():
		return editor_layout_override.get("belt_grid_size", belt_grid_size)
	var config := _selected_pattern_config()
	return config.get("belt_grid_size") if config else belt_grid_size

func _belt_grid_cell_is_occupied(row: int, column: int) -> bool:
	if not _uses_shared_grid():
		return false
	var position := _configured_belt_position()
	var dimensions := _configured_belt_size()
	return column >= position.x and column < position.x + dimensions.x and row >= position.y and row < position.y + dimensions.y

func editor_shared_grid_cell_at_point(point: Vector2) -> Vector2i:
	_sync_layout()
	if not _uses_shared_grid() or not shared_grid_rect.has_point(point):
		return Vector2i(-1, -1)
	var cell := _shared_grid_cell_size()
	var local := point - shared_grid_rect.position
	return Vector2i(clampi(floori(local.x / cell), 0, maxi(layout_grid_size.x - 1, 0)), clampi(floori(local.y / cell), 0, maxi(layout_grid_size.y - 1, 0)))

func editor_is_belt_cell(cell: Vector2i) -> bool:
	return _belt_grid_cell_is_occupied(cell.y, cell.x)

func _editor_belt_resize_handle_rect() -> Rect2:
	_sync_layout()
	var position := _configured_belt_position()
	var dimensions := _configured_belt_size()
	var belt := _rect_from_layout_grid(position, dimensions)
	var handle_size := minf(16.0, maxf(_shared_grid_cell_size() * 0.8, 10.0))
	return Rect2(belt.end - Vector2.ONE * handle_size, Vector2.ONE * handle_size)

func editor_is_belt_resize_handle(point: Vector2) -> bool:
	return _editor_belt_resize_handle_rect().has_point(point)

func editor_belt_size_from_point(point: Vector2) -> Vector2i:
	_sync_layout()
	var position := _configured_belt_position()
	var current_size := _configured_belt_size()
	var cell := _shared_grid_cell_size()
	var local := point - shared_grid_rect.position
	var right := clampi(floori(local.x / cell) + 1, position.x + 5, layout_grid_size.x)
	var bottom := clampi(floori(local.y / cell) + 1, position.y + 5, layout_grid_size.y)
	return Vector2i(right - position.x, bottom - position.y)

func set_editor_layout_preview(new_grid_size: Vector2i, new_layout: String, new_belt_position: Vector2i, new_belt_size: Vector2i) -> void:
	if not Engine.is_editor_hint():
		return
		editor_layout_override = {
		"layout_grid_size": Vector2i(maxi(new_grid_size.x, 1), maxi(new_grid_size.y, 1)),
		"game_grid_layout": new_layout,
		"belt_grid_position": new_belt_position,
		"belt_grid_size": new_belt_size
	}
	_refresh_editor_preview()

func clear_editor_layout_preview() -> void:
	if editor_layout_override.is_empty():
		return
	editor_layout_override.clear()
	_refresh_editor_preview()

func _draw_editor_layout_overlay() -> void:
	if not _uses_shared_grid():
		return
	var grid := _shared_grid_rect()
	var cell := _shared_grid_cell_size()
	draw_rect(grid, Color(0.12, 0.24, 0.24, 0.035), true)
	for column in range(layout_grid_size.x + 1):
		var x := grid.position.x + float(column) * cell
		draw_line(Vector2(x, grid.position.y), Vector2(x, grid.end.y), Color(0.16, 0.32, 0.32, 0.18), 1.0)
	for row in range(layout_grid_size.y + 1):
		var y := grid.position.y + float(row) * cell
		draw_line(Vector2(grid.position.x, y), Vector2(grid.end.x, y), Color(0.16, 0.32, 0.32, 0.18), 1.0)
	var belt_position := _configured_belt_position()
	var belt_size := _configured_belt_size()
	var belt := _rect_from_layout_grid(belt_position, belt_size)
	draw_rect(belt, Color(0.08, 0.42, 0.52, 0.08), true)
	draw_rect(belt, Color(0.08, 0.42, 0.52, 0.48), false, 2.0)
	var handle_size := minf(16.0, maxf(cell * 0.8, 10.0))
	var handle := Rect2(belt.end - Vector2.ONE * handle_size, Vector2.ONE * handle_size)
	draw_rect(handle, Color("#176b7d"), true)
	for offset in [4.0, 8.0, 12.0]:
		if offset < handle.size.x:
			draw_line(handle.position + Vector2(offset, handle.size.y), handle.position + Vector2(handle.size.x, offset), Color.WHITE, 1.0)

func _draw_background() -> void:
	if background_texture:
		draw_texture_rect(background_texture, Rect2(Vector2.ZERO, VIRTUAL_SIZE), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, VIRTUAL_SIZE), Color("#f5f0e8"))
		for y in range(0, 844, 18):
			draw_line(Vector2(0, y), Vector2(390, y), Color(0.45, 0.40, 0.32, 0.025), 1.0)

func _draw_header() -> void:
	var score_ui_rect := _ui_layout_rect(score_ui_node_path, score_rect)
	var level_ui_rect := _ui_layout_rect(level_ui_node_path, level_rect)
	var pause_ui_rect := _ui_layout_rect(pause_ui_node_path, pause_rect)
	var score_font_size := clampi(int(score_ui_rect.size.y * 0.48), 10, 22)
	var level_font_size := clampi(int(level_ui_rect.size.y * 0.36), 10, 16)
	var pause_font_size := clampi(int(pause_ui_rect.size.y * 0.45), 12, 24)
	if score_panel_texture:
		draw_texture_rect(score_panel_texture, score_ui_rect, false)
	else:
		_draw_box(score_ui_rect, Color("#fffdf9"), 11, Color("#d8cfc1"), 2)
		var score_icon_radius := minf(score_ui_rect.size.y * 0.3, 14.0)
		var score_icon_center := score_ui_rect.position + Vector2(score_ui_rect.size.y * 0.52, score_ui_rect.size.y * 0.5)
		draw_circle(score_icon_center, score_icon_radius, Color("#f2c547"))
		_text("★", score_icon_center + Vector2(-score_icon_radius * 0.62, score_font_size * 0.34), score_font_size, Color("#fff7d9"))
	var score_baseline := score_ui_rect.position.y + score_ui_rect.size.y * 0.5 + score_font_size * 0.35
	_text("1,020", Vector2(score_ui_rect.position.x + score_ui_rect.size.x * 0.38, score_baseline), score_font_size, Color("#7b2f20"))
	if level_panel_texture:
		draw_texture_rect(level_panel_texture, level_ui_rect, false)
	else:
		_draw_box(level_ui_rect, Color("#2684c9"), 16, Color("#075b9e"), 3)
	var level_text := _current_level_name()
	var level_width := font.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, level_font_size).x
	_text(level_text, Vector2(level_ui_rect.position.x + (level_ui_rect.size.x - level_width) * 0.5, level_ui_rect.position.y + level_ui_rect.size.y * 0.5 + level_font_size * 0.35), level_font_size, Color("#fffdf9"))
	if pause_texture:
		draw_texture_rect(pause_texture, pause_ui_rect, false)
	else:
		_draw_box(pause_ui_rect, Color("#2684c9"), 16, Color("#075b9e"), 3)
	var pause_text := "▶" if game_paused else "Ⅱ"
	var pause_width := font.get_string_size(pause_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pause_font_size).x
	_text(pause_text, Vector2(pause_ui_rect.position.x + (pause_ui_rect.size.x - pause_width) * 0.5, pause_ui_rect.position.y + pause_ui_rect.size.y * 0.5 + pause_font_size * 0.35), pause_font_size, Color("#fffdf9"))

func _draw_conveyor_panel() -> void:
	if belt_texture:
		_draw_box(active_belt_panel_rect, Color(0.99, 0.98, 0.95, 0.22), 7, Color("#d8cfc1"))
	else:
		_draw_box(active_belt_panel_rect, Color(0.99, 0.98, 0.95, 0.94), 7, Color("#d8cfc1"))
	_draw_belt()
	_draw_board()
	_draw_dynamic_machines()
	_draw_weaving_threads()

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
	var grid_columns: int = _pattern_columns()
	var grid_rows: int = _pattern_rows()
	var cell_size: Vector2 = Vector2(board_rect.size.x / float(grid_columns), board_rect.size.y / float(grid_rows))
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
	var cell_size: Vector2 = Vector2(board_rect.size.x / float(_pattern_columns()), board_rect.size.y / float(_pattern_rows()))
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
	var cell_size: Vector2 = Vector2(board_rect.size.x / float(_pattern_columns()), board_rect.size.y / float(_pattern_rows()))
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
			_draw_yarn_at(item.color, point + Vector2(0, machine_yarn_radius * 0.6), machine_yarn_radius)
		if item.status == "stitching":
			draw_circle(point + Vector2(0, -dynamic_machine_size.y * 0.5 + 5), 4.0, Color("#fff4a8"))

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

func _draw_materials() -> void:
	if material_panel_texture:
		draw_texture_rect(material_panel_texture, materials_panel_rect, false)
	_draw_link_board()
	_draw_link_products()
	_draw_tool_slot(_ui_layout_rect(add_time_ui_node_path, Rect2(18, 788, 72, 42)), add_time_texture, "+")
	_draw_tool_slot(_ui_layout_rect(shuffle_ui_node_path, Rect2(141, 788, 72, 42)), shuffle_texture, "↗")
	_draw_tool_slot(_ui_layout_rect(auto_clear_ui_node_path, Rect2(264, 788, 72, 42)), auto_clear_texture, "✦")

func _draw_tool_slot(rect: Rect2, texture: Texture2D, fallback_icon: String) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	if tool_slot_background_texture:
		draw_texture_rect(tool_slot_background_texture, rect, false)
	else:
		_draw_box(rect, Color(1.0, 0.99, 0.96, 0.94), 8, Color("#d8cfc1"), 2)
	var icon_size := minf(rect.size.x, rect.size.y) - 10.0
	var icon_rect := Rect2(rect.get_center() - Vector2(icon_size, icon_size) * 0.5, Vector2.ONE * icon_size)
	if texture:
		_draw_texture_contain(texture, icon_rect)
	else:
		_draw_box(icon_rect, Color("#e0f7f8"), 6, Color("#1593a0"), 1)
		var symbol_size := clampi(int(icon_rect.size.y * 0.64), 12, 24)
		var symbol_width := font.get_string_size(fallback_icon, HORIZONTAL_ALIGNMENT_LEFT, -1, symbol_size).x
		_text(fallback_icon, icon_rect.position + Vector2((icon_rect.size.x - symbol_width) * 0.5, icon_rect.size.y * 0.5 + symbol_size * 0.35), symbol_size, Color("#087987"))

func _draw_link_board() -> void:
	var selected_id := str(state.get("selectedTileId", ""))
	var effect_duration := maxf(float(state.get("linkEffectDuration", 0.42)), 0.01)
	var effect_progress := clampf(float(state.get("linkEffectElapsed", 0.0)) / effect_duration, 0.0, 1.0)
	var selection_left := float(state.get("selectionPulseLeft", 0.0))
	var selection_progress := 1.0 - clampf(selection_left / LINK_SELECTION_PULSE_DURATION, 0.0, 1.0)
	var selection_scale := _pulse_scale(selection_progress, LINK_SELECTION_PULSE_AMPLITUDE) if selection_left > 0.0 else 1.0
	var elimination_scale := _pulse_scale(effect_progress, LINK_ELIMINATION_PULSE_AMPLITUDE)
	for tile_value in state.get("linkTiles", []):
		var tile: Dictionary = tile_value
		if bool(tile.get("removed", false)):
			continue
		var tile_rect: Rect2 = _link_cell_rect(int(tile.row), int(tile.column))
		var center: Vector2 = tile_rect.get_center()
		var yarn_radius: float = min(tile_rect.size.x, tile_rect.size.y) * 0.5
		var tile_id := str(tile.get("id", ""))
		var selected := tile_id == selected_id
		var pending := _is_pending_link_tile(tile_id)
		var icon_scale := elimination_scale if pending else (selection_scale if selected else 1.0)
		_draw_link_tile(str(tile.get("tile_key", tile.color)), center, yarn_radius, icon_scale, selected or pending)
	var path: Array = state.get("linkPath", [])
	if float(state.get("linkEffectLeft", 0.0)) > 0.0 and path.size() >= 2:
		var effect_key: String = str(state.get("linkEffectColor", "coral"))
		var effect_color: Color = _link_tile_color(effect_key)
		_draw_link_effect(path, effect_color, effect_progress)

func _draw_link_effect(path: Array, effect_color: Color, progress: float) -> void:
	var points := PackedVector2Array()
	for point_value in path:
		points.append(_link_point(Vector2i(point_value)))
	if points.size() < 2:
		return

	var eased_progress := _ease_out_cubic(progress)
	var strand_gap := lerpf(5.5, 0.8, eased_progress)
	var phase := progress * TAU * 2.8
	var strand_a := _link_effect_strand_points(points, strand_gap, phase, 1.0)
	var strand_b := _link_effect_strand_points(points, strand_gap, phase + PI, -1.0)

	# The glow uses the yarn color itself instead of a white underlay.
	var glow_color := effect_color.lightened(0.28)
	glow_color.a = 0.18 + 0.12 * sin(progress * PI)
	draw_polyline(strand_a, glow_color, 8.0, true)
	draw_polyline(strand_b, glow_color, 8.0, true)

	var strand_a_color := effect_color.lightened(0.20)
	strand_a_color.a = 0.88
	var strand_b_color := effect_color.darkened(0.16)
	strand_b_color.a = 0.92
	draw_polyline(strand_a, strand_a_color, 2.8, true)
	draw_polyline(strand_b, strand_b_color, 2.8, true)

	# Two moving yarn knots travel toward the middle and meet there.
	var knot_progress := clampf(progress * 2.0, 0.0, 1.0)
	var first_knot := _point_on_link_polyline(points, minf(knot_progress * 0.5, 0.5))
	var second_knot := _point_on_link_polyline(points, maxf(1.0 - knot_progress * 0.5, 0.5))
	var knot_radius := 3.0 + sin(progress * PI) * 2.0
	var knot_glow := effect_color.lightened(0.35)
	knot_glow.a = 0.45
	draw_circle(first_knot, knot_radius + 3.0, knot_glow)
	draw_circle(second_knot, knot_radius + 3.0, knot_glow)
	draw_circle(first_knot, knot_radius, strand_a_color)
	draw_circle(second_knot, knot_radius, strand_b_color)

	# Add a short crossing at the meeting point to sell the interwoven motion.
	var center := _point_on_link_polyline(points, 0.5)
	var center_tangent := _link_polyline_tangent(points, 0.5)
	var center_normal := Vector2(-center_tangent.y, center_tangent.x)
	var crossing_offset := sin(phase) * 6.0 * (1.0 - eased_progress * 0.35)
	var crossing_a := center - center_tangent * 10.0 - center_normal * crossing_offset
	var crossing_b := center + center_tangent * 10.0 + center_normal * crossing_offset
	var crossing_color := effect_color.lightened(0.30)
	crossing_color.a = 0.78 * (0.35 + 0.65 * sin(progress * PI))
	draw_line(crossing_a, crossing_b, crossing_color, 3.2, true)

func _link_effect_strand_points(points: PackedVector2Array, gap: float, phase: float, side: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in range(points.size()):
		var tangent := _link_polyline_tangent(points, float(index))
		var normal := Vector2(-tangent.y, tangent.x)
		var wave := sin(phase + float(index) * 1.7) * 1.6
		result.append(points[index] + normal * (side * gap + wave))
	return result

func _point_on_link_polyline(points: PackedVector2Array, ratio: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]
	var total_length := 0.0
	for index in range(points.size() - 1):
		total_length += points[index].distance_to(points[index + 1])
	if total_length <= 0.001:
		return points[0]
	var target_distance := clampf(ratio, 0.0, 1.0) * total_length
	var travelled := 0.0
	for index in range(points.size() - 1):
		var segment_length := points[index].distance_to(points[index + 1])
		if travelled + segment_length >= target_distance:
			return points[index].lerp(points[index + 1], (target_distance - travelled) / maxf(segment_length, 0.001))
		travelled += segment_length
	return points[points.size() - 1]

func _link_polyline_tangent(points: PackedVector2Array, position: float) -> Vector2:
	if points.size() < 2:
		return Vector2.RIGHT
	var index := clampi(int(round(position)), 0, points.size() - 1)
	var tangent := Vector2.ZERO
	if index > 0:
		tangent += points[index] - points[index - 1]
	if index < points.size() - 1:
		tangent += points[index + 1] - points[index]
	return tangent.normalized() if tangent.length_squared() > 0.001 else Vector2.RIGHT

func _ease_out_cubic(value: float) -> float:
	var inverse := 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - inverse * inverse * inverse

func _link_tile_color(tile_key: String) -> Color:
	var color_key := _tile_color_for_key(tile_key)
	return Color(COLORS[color_key].hex) if COLORS.has(color_key) else Color("#9b9d9c")

func _tile_color_for_key(tile_key: String) -> String:
	var info := _style_info_for_key(tile_key)
	return str(info.get("color", "coral"))

func _draw_link_tile(tile_key: String, center: Vector2, radius: float, icon_scale: float = 1.0, highlighted: bool = false) -> void:
	var tile_rect := Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	if link_tile_background_texture:
		draw_texture_rect(link_tile_background_texture, tile_rect, false)
	else:
		draw_circle(center, radius, Color(1.0, 0.99, 0.96, 0.96))
		draw_arc(center, radius - 1.0, 0.0, TAU, 24, Color(0.78, 0.73, 0.65, 0.62), 1.0, true)
	if highlighted and link_tile_selected_color.a > 0.0:
		_draw_rounded_tile_highlight(tile_rect, link_tile_selected_color)
	var custom_texture := _link_tile_texture(tile_key)
	if custom_texture:
		_draw_texture_contain(custom_texture, _scaled_rect(tile_rect.grow(-radius * 0.12), icon_scale))
		return
	var color: Color = _link_tile_color(tile_key)
	var icon_radius := radius * 0.74 * icon_scale
	draw_circle(center, icon_radius, color)
	var shape_index: int = maxi(_style_id_for_key(tile_key), 0)
	match shape_index % 5:
		0:
			draw_circle(center, icon_radius * 0.38, Color(1, 1, 1, 0.42))
		1:
			draw_line(center - Vector2(icon_radius * 0.48, 0), center + Vector2(icon_radius * 0.48, 0), Color(1, 1, 1, 0.52), 1.4, true)
			draw_line(center - Vector2(0, icon_radius * 0.48), center + Vector2(0, icon_radius * 0.48), Color(1, 1, 1, 0.52), 1.4, true)
		2:
			draw_arc(center, icon_radius * 0.55, 0.2, 2.7, 10, Color(1, 1, 1, 0.58), 1.5, true)
		3:
			draw_circle(center + Vector2(-icon_radius * 0.25, -icon_radius * 0.15), icon_radius * 0.16, Color(1, 1, 1, 0.62))
			draw_circle(center + Vector2(icon_radius * 0.25, icon_radius * 0.15), icon_radius * 0.16, Color(1, 1, 1, 0.62))
		_:
			draw_arc(center, icon_radius * 0.58, -1.2, 1.9, 10, Color(1, 1, 1, 0.58), 1.5, true)

func _draw_rounded_tile_highlight(rect: Rect2, color: Color) -> void:
	if color.a <= 0.0:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = color
	var border_color := color.lightened(0.22)
	border_color.a = minf(color.a + 0.28, 1.0)
	style.border_color = border_color
	style.set_border_width_all(maxi(1, int(minf(rect.size.x, rect.size.y) * 0.025)))
	var corner_radius := clampi(int(minf(rect.size.x, rect.size.y) * 0.18), 2, 12)
	style.set_corner_radius_all(corner_radius)
	draw_style_box(style, rect)

func _scaled_rect(rect: Rect2, scale_factor: float) -> Rect2:
	var safe_scale := maxf(scale_factor, 0.01)
	var scaled_size := rect.size * safe_scale
	return Rect2(rect.get_center() - scaled_size * 0.5, scaled_size)

func _pulse_scale(progress: float, amplitude: float) -> float:
	return 1.0 + sin(clampf(progress, 0.0, 1.0) * PI) * amplitude

func _link_tile_texture(tile_key: String) -> Texture2D:
	var texture_index := _style_id_for_key(tile_key)
	if texture_index >= 0 and texture_index < link_tile_textures.size():
		return link_tile_textures[texture_index]
	return null

func _normalize_style_counts(value: Array) -> Array[int]:
	var result: Array[int] = []
	for group_index in range(COLOR_KEYS.size()):
		var count: int = DEFAULT_LINK_TILE_STYLE_COUNTS[group_index]
		if group_index < value.size():
			count = clampi(int(value[group_index]), 1, 8)
		result.append(count)
	return result

func _style_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	var counts := _normalize_style_counts(link_tile_style_counts)
	var style_id := 0
	for group_index in range(COLOR_KEYS.size()):
		for _local_style in range(counts[group_index]):
			catalog.append({
				"style_id": style_id,
				"group_index": group_index,
				"color": COLOR_KEYS[group_index],
				"texture": link_tile_textures[style_id] if style_id < link_tile_textures.size() else null
			})
			style_id += 1
	return catalog

func _style_info_for_id(style_id: int) -> Dictionary:
	var catalog := _style_catalog()
	return catalog[style_id] if style_id >= 0 and style_id < catalog.size() else {}

func _style_info_for_key(tile_key: String) -> Dictionary:
	var normalized := tile_key.to_lower()
	var style_id := -1
	if normalized.begins_with("style_"):
		style_id = int(normalized.trim_prefix("style_"))
	else:
		style_id = LINK_TILE_KEYS.find(normalized)
	return _style_info_for_id(style_id)

func _style_id_for_key(tile_key: String) -> int:
	var info := _style_info_for_key(tile_key)
	return int(info.get("style_id", -1))

func _style_ids_for_group(group_index: int) -> Array[int]:
	var result: Array[int] = []
	for info in _style_catalog():
		if int(info.get("group_index", -1)) == group_index:
			result.append(int(info.get("style_id", -1)))
	return result

func _tile_style_id(tile: Dictionary) -> int:
	if tile.has("style_id"):
		return int(tile.get("style_id", -1))
	return _style_id_for_key(str(tile.get("tile_key", "")))

func _style_key_for_id(style_id: int) -> String:
	return "style_%d" % style_id

func _draw_link_products() -> void:
	for product in link_products:
		var point: Vector2 = product.start.lerp(product.target, clamp(float(product.progress), 0.0, 1.0))
		_draw_yarn_at(str(product.color), point, conveyor_product_yarn_radius)
		draw_circle(point, conveyor_product_yarn_radius + 2.0, Color(1, 1, 1, 0.55), false, 2.0)

func _link_cell_rect(row: int, column: int) -> Rect2:
	var cell_size := Vector2(active_link_board_rect.size.x / float(_link_columns()), active_link_board_rect.size.y / float(_link_rows()))
	var gap: float = min(cell_size.x, cell_size.y) * clampf(link_cell_gap_ratio, 0.0, 0.5) * 0.5
	return Rect2(active_link_board_rect.position + Vector2(column, row) * cell_size + Vector2(gap, gap), cell_size - Vector2(gap * 2.0, gap * 2.0))

func _link_grid_cell_rect(row: int, column: int) -> Rect2:
	var cell_size := Vector2(active_link_board_rect.size.x / float(_link_columns()), active_link_board_rect.size.y / float(_link_rows()))
	return Rect2(active_link_board_rect.position + Vector2(column, row) * cell_size, cell_size)

func _link_point(grid_point: Vector2i) -> Vector2:
	var cell_size := Vector2(active_link_board_rect.size.x / float(_link_columns()), active_link_board_rect.size.y / float(_link_rows()))
	return active_link_board_rect.position + Vector2((grid_point.x + 0.5) * cell_size.x, (grid_point.y + 0.5) * cell_size.y)

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
	var box: Rect2 = victory_panel_rect
	_draw_box(box, Color("#fffdf8"), 8, Color("#d6c5ad"))
	if state.status == "won":
		_draw_victory_pattern()
	else:
		draw_circle(box.position + Vector2(box.size.x * 0.5, 51), 27, Color("#fde8e3"))
		_text("!", box.position + Vector2(box.size.x * 0.5 - 8, 60), 25, Color("#c95249"))
	_text("MISSION COMPLETE" if state.status == "won" else "WORKTABLE FULL", Vector2(122, box.position.y + 174), 9, Color("#bd4c42"))
	_text("花园徽章完成" if state.status == "won" else "连连看棋盘无法继续", Vector2(105 if state.status == "won" else 83, box.position.y + 204), 24, Color("#243b3b"))
	_text("所有针脚都已经稳稳落在布面上。" if state.status == "won" else "请等待传送带空出位置后继续配对。", Vector2(73, box.position.y + 230), 10, Color("#81847b"))
	_text("完成针脚    %d / %d" % [state.stitchedCells.size(), state.activeCellIds.size()], Vector2(105, box.position.y + 260), 12, Color("#243b3b"))
	var action_visible: bool = state.status != "won" or victory_float_progress >= 1.0
	if action_visible:
		_draw_box(result_action_rect, Color("#243b3b"), 4)
		var result_action := "下一关" if state.status == "won" and runtime_level_index < _level_count() - 1 else "↻  再绣一次"
		var action_width: float = font.get_string_size(result_action, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		_text(result_action, result_action_rect.position + Vector2((result_action_rect.size.x - action_width) * 0.5, result_action_rect.size.y * 0.5 + 5), 13, Color("#fffdf8"))

func _start_victory_animation() -> void:
	victory_snapshot.clear()
	for cell_value in state.pattern:
		var cell: Dictionary = cell_value
		if bool(cell.get("active", false)) and str(cell.get("id", "")) in state.stitchedCells:
			victory_snapshot.append(cell.duplicate())
	victory_float_progress = 0.0
	victory_animation_active = not victory_snapshot.is_empty()
	if not victory_animation_active:
		victory_float_progress = 1.0

func _get_victory_pattern_bounds() -> Rect2i:
	if victory_snapshot.is_empty():
		return Rect2i(0, 0, 1, 1)
	var min_column := 999999
	var min_row := 999999
	var max_column := -999999
	var max_row := -999999
	for cell in victory_snapshot:
		min_column = mini(min_column, int(cell.get("column", 0)))
		min_row = mini(min_row, int(cell.get("row", 0)))
		max_column = maxi(max_column, int(cell.get("column", 0)))
		max_row = maxi(max_row, int(cell.get("row", 0)))
	return Rect2i(min_column, min_row, max_column - min_column + 1, max_row - min_row + 1)

func _draw_victory_pattern() -> void:
	if victory_snapshot.is_empty():
		return
	var bounds := _get_victory_pattern_bounds()
	var source_cell_size := Vector2(board_rect.size.x / float(_pattern_columns()), board_rect.size.y / float(_pattern_rows()))
	var target_cell_size := minf(victory_pattern_rect.size.x / float(bounds.size.x), victory_pattern_rect.size.y / float(bounds.size.y))
	var target_pattern_size := Vector2(bounds.size) * target_cell_size
	var target_origin := victory_pattern_rect.position + (victory_pattern_rect.size - target_pattern_size) * 0.5
	var progress := clampf(victory_float_progress, 0.0, 1.0)
	var eased_progress := progress * progress * (3.0 - 2.0 * progress)
	var lift_progress := sin(PI * minf(progress * 2.0, 1.0) * 0.5)
	for cell in victory_snapshot:
		var row := int(cell.get("row", 0))
		var column := int(cell.get("column", 0))
		var source_center := _board_cell_center(str(cell.get("id", "")))
		var target_center := target_origin + Vector2((column - bounds.position.x + 0.5) * target_cell_size, (row - bounds.position.y + 0.5) * target_cell_size)
		var center := source_center.lerp(target_center, eased_progress) + Vector2(0, -28.0 * lift_progress)
		var draw_size := source_cell_size.lerp(Vector2(target_cell_size, target_cell_size), eased_progress)
		var cell_rect := Rect2(center - draw_size * 0.5, draw_size)
		var color_key := str(cell.get("color", "coral"))
		var texture_index := COLOR_KEYS.find(color_key)
		var texture: Texture2D = stitched_block_textures[texture_index] if texture_index >= 0 and texture_index < stitched_block_textures.size() else null
		if texture:
			draw_texture_rect(texture, cell_rect, false, Color.WHITE)
		else:
			var fill := Color(COLORS[color_key].hex)
			draw_rect(cell_rect, fill, true)
			draw_line(cell_rect.position + Vector2(2, 2), cell_rect.end - Vector2(2, 2), Color(1, 1, 1, 0.52), maxf(1.0, draw_size.x * 0.06), true)
			draw_line(Vector2(cell_rect.end.x - 2, cell_rect.position.y + 2), Vector2(cell_rect.position.x + 2, cell_rect.end.y - 2), Color(1, 1, 1, 0.52), maxf(1.0, draw_size.x * 0.06), true)

func _draw_pause_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIRTUAL_SIZE), Color(0.14, 0.23, 0.23, 0.28))
	if pause_level_select_open:
		_draw_pause_level_select()
		return
	var box: Rect2 = Rect2(72, 286, 246, 248)
	_draw_box(box, Color("#fffdf8"), 10, Color("#d6c5ad"), 2)
	_text("游戏已暂停", box.position + Vector2(73, 42), 18, Color("#243b3b"))
	_text("点击右上角继续", box.position + Vector2(79, 66), 10, Color("#81847b"))
	var select_rect := _pause_level_select_button_rect()
	_draw_box(select_rect, Color("#243b3b"), 5)
	var select_text := "选择关卡"
	var select_width := font.get_string_size(select_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	_text(select_text, select_rect.position + Vector2((select_rect.size.x - select_width) * 0.5, 27), 13, Color("#fffdf8"))
	_text("选择后会立即重新开始所选关卡", box.position + Vector2(45, 219), 10, Color("#81847b"))

func _draw_pause_level_select() -> void:
	var panel := _pause_level_panel_rect()
	_draw_box(panel, Color("#fffdf8"), 10, Color("#d6c5ad"), 2)
	_text("选择关卡", panel.position + Vector2(112, 38), 19, Color("#243b3b"))
	_text("点击关卡后立即开始", panel.position + Vector2(91, 61), 10, Color("#81847b"))
	var visible_count := mini(_level_count(), 11)
	for index in range(visible_count):
		var level_rect := _pause_level_button_rect(index)
		var is_current := index == runtime_level_index
		_draw_box(level_rect, Color("#e7f3e9") if is_current else Color("#f5f0e8"), 5, Color("#5b9c72") if is_current else Color("#d6c5ad"), 1)
		var level_name := _level_display_name(index)
		_text("第 %02d 关" % [index + 1], level_rect.position + Vector2(14, 23), 12, Color("#243b3b"))
		_text(level_name, level_rect.position + Vector2(91, 23), 11, Color("#626975"))
	if _level_count() > visible_count:
		_text("还有更多关卡，请先在编辑器中减少关卡数量", panel.position + Vector2(43, panel.size.y - 34), 9, Color("#81847b"))
	else:
		_text("点击右上角返回暂停界面", panel.position + Vector2(78, panel.size.y - 34), 9, Color("#81847b"))

func _pause_level_select_button_rect() -> Rect2:
	return Rect2(98, 414, 194, 42)

func _pause_level_panel_rect() -> Rect2:
	return Rect2(42, 116, 306, 612)

func _pause_level_button_rect(index: int) -> Rect2:
	return Rect2(70, 190 + index * 42, 250, 34)

func _level_display_name(index: int) -> String:
	if index >= 0 and index < level_configs.size():
		var level := level_configs[index]
		var name := str(level.get("level_name"))
		return name if not name.is_empty() else "未命名关卡"
	return "当前单关配置"

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
	var loop_progress := fmod(progress, BELT_END)
	if loop_progress < 0.0:
		loop_progress += BELT_END
	var distance_left: float = loop_progress * total_length
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
	var configured_points := PackedVector2Array()
	var config := _selected_pattern_config()
	var use_grid_layout := true
	var configured_layout_grid_size := layout_grid_size
	var configured_belt_position := belt_grid_position
	var configured_belt_size := belt_grid_size
	if config:
		configured_layout_grid_size = config.get("layout_grid_size")
		configured_belt_position = config.get("belt_grid_position")
		configured_belt_size = config.get("belt_grid_size")
	use_grid_layout = use_grid_layout and _uses_shared_grid() and _can_use_grid_layout(configured_layout_grid_size, configured_belt_position, configured_belt_size)
	if use_grid_layout:
		configured_points = PackedVector2Array([
			Vector2(0.10, 0.12),
			Vector2(0.88, 0.12),
			Vector2(0.90, 0.88),
			Vector2(0.10, 0.88),
			Vector2(0.10, 0.34)
		])
	else:
		configured_points = belt_path_points
	for normalized_point in configured_points:
		points.append(belt_rect.position + Vector2(normalized_point.x * belt_rect.size.x, normalized_point.y * belt_rect.size.y))
	return points

func _path_segment_at_progress(progress: float) -> int:
	var points: PackedVector2Array = _belt_path_points()
	if points.size() < 2:
		return -1
	var total_length: float = _path_total_length(points)
	var loop_progress := fmod(progress, BELT_END)
	if loop_progress < 0.0:
		loop_progress += BELT_END
	var distance_left: float = loop_progress * total_length
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
			var cell_size: Vector2 = Vector2(board_rect.size.x / float(_pattern_columns()), board_rect.size.y / float(_pattern_rows()))
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
		if item.status != "stitching" and not _machine_group_finished(item) and str(item.get("target_cell_id", "")) == "":
			_plan_machine_target(item)
		item.progress += delta * 0.22 * float(state.get("conveyorSpeedMultiplier", 1.0))
		if item.status != "stitching" and _did_pass_progress(old_progress, item.progress, float(item.get("target_progress", -1.0))):
			_start_dynamic_stitch(item)
		# A machine with remaining assigned targets is allowed to continue into
		# another lap. It only leaves after its complete target group is done.
		if item.progress >= BELT_END and item.status != "stitching" and _machine_group_finished(item):
			finished.append(item)
	for item in finished:
		if item in state.conveyorQueue:
			state.conveyorQueue.erase(item)
		item.status = "finished"
		if not bool(item.get("has_target_group", false)):
			_show_toast("纺织机没有找到可编制点位")
	_try_finish_game()

func _try_finish_game() -> void:
	if state.status != "playing":
		return
	if state.stitchedCells.size() >= state.activeCellIds.size() and state.conveyorQueue.is_empty() and weaving_sessions.is_empty() and link_products.is_empty():
		state.status = "won"
		_start_victory_animation()

func _plan_machine_target(item: Dictionary) -> void:
	var candidates: Array[Dictionary] = []
	var target_ids: Array = item.get("target_cell_ids", [])
	var target_index := int(item.get("target_index", 0))
	while target_index < target_ids.size() and str(target_ids[target_index]) in state.stitchedCells:
		target_index += 1
	item.target_index = target_index
	item.target_cell_id = ""
	if target_index >= target_ids.size():
		item.target_progress = -1.0
		return
	var target_id := str(target_ids[target_index])
	var target := _cell_by_id(target_id)
	if not target.is_empty() and bool(target.get("active", false)):
		candidates.append(target)
	if candidates.is_empty():
		item.target_progress = -1.0
		item.target_index = target_index + 1
		return
	var best_candidate: Dictionary = candidates[0]
	var candidate_progress: float = _path_progress_for_point(_board_cell_center(best_candidate.id))
	var loop_progress := fmod(float(item.progress), BELT_END)
	if loop_progress < 0.0:
		loop_progress += BELT_END
	var forward_distance: float = _forward_distance(loop_progress, candidate_progress)
	item.target_progress = item.progress + forward_distance
	item.target_cell_id = best_candidate.id

func _machine_group_finished(item: Dictionary) -> bool:
	var target_ids: Array = item.get("target_cell_ids", [])
	return int(item.get("target_index", 0)) >= target_ids.size()

func _occupied_target_ids() -> Array[String]:
	var occupied: Array[String] = []
	for item in state.conveyorQueue:
		var target_id: String = str(item.get("target_cell_id", ""))
		if target_id != "":
			occupied.append(target_id)
	for product in link_products:
		var product_target_id: String = str(product.get("target_cell_id", ""))
		if product_target_id != "":
			occupied.append(product_target_id)
	return occupied

func _cell_by_id(cell_id: String) -> Dictionary:
	for cell in state.pattern:
		if cell.id == cell_id:
			return cell
	return {}

func _start_dynamic_stitch(item: Dictionary) -> void:
	if item.status == "stitching" or _machine_group_finished(item):
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
		"tile_key": str(item.get("tile_key", "")),
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
	item.target_index = int(item.get("target_index", 0)) + 1
	item.target_cell_id = ""
	item.target_progress = -1.0
	item.processed = false
	item.status = "moving"
	item.yarn_visible = true
	_show_toast("%s图案已完成" % COLORS[color].label)
	_try_finish_game()

func _create_link_tiles() -> Array[Dictionary]:
	return _create_auto_link_tiles(_base_pattern())

func _create_auto_link_tiles(pattern: Array[Dictionary]) -> Array[Dictionary]:
	var positions := _configured_link_spawn_positions()
	var active_cells: Array[Dictionary] = []
	for cell in pattern:
		if bool(cell.get("active", false)):
			active_cells.append(cell)
	if active_cells.is_empty():
		return []
	var required_point_count := active_cells.size() * 2
	if positions.size() != required_point_count:
		_show_toast("连连看点位数量不匹配：需要 %d 个，当前为 %d 个" % [required_point_count, positions.size()])
	var generated_tiles: Array[Dictionary] = []
	var stitch_groups := _build_stitch_groups(active_cells, active_cells.size())
	for group in stitch_groups:
		var color := str(group.get("color", "coral"))
		var group_index := COLOR_KEYS.find(color)
		var style_ids := _style_ids_for_group(group_index)
		var style_id := style_ids[rng.randi_range(0, style_ids.size() - 1)] if not style_ids.is_empty() else maxi(group_index, 0)
		var tile_key: String = _style_key_for_id(style_id)
		var group_id := str(group.get("id", ""))
		var target_ids: Array = group.get("target_cell_ids", [])
		for _copy in range(2):
			generated_tiles.append({
				"style_id": style_id,
				"tile_key": tile_key,
				"group_index": group_index,
				"color": color,
				"stitchable": true,
				"stitch_group_id": group_id,
				"target_cell_ids": target_ids.duplicate(),
				"removed": false
			})
	var shuffled_tiles: Array = _shuffle(generated_tiles)

	positions = _shuffle(positions)
	if shuffled_tiles.size() > positions.size():
		# Keep the scene loadable if an old level has too few manually placed points.
		_show_toast("连连看点位不足：需要 %d 个，当前只有 %d 个" % [shuffled_tiles.size(), positions.size()])
	var tiles: Array[Dictionary] = []
	var tile_count: int = mini(shuffled_tiles.size(), positions.size())
	for index in range(tile_count):
		var position: Vector2i = positions[index]
		var generated: Dictionary = shuffled_tiles[index]
		var tile_key: String = str(generated.get("tile_key", ""))
		var tile: Dictionary = {
			"id": "tile_%d_%d" % [position.x, position.y],
			"row": position.x,
			"column": position.y,
			"style_id": int(generated.get("style_id", _style_id_for_key(tile_key))),
			"group_index": int(generated.get("group_index", COLOR_KEYS.find(_tile_color_for_key(tile_key)))),
			"color": str(generated.get("color", _tile_color_for_key(tile_key))),
			"tile_key": tile_key,
			"stitchable": true,
			"stitch_group_id": str(generated.get("stitch_group_id", "")),
			"target_cell_ids": generated.get("target_cell_ids", []).duplicate(),
			"removed": false
		}
		tiles.append(tile)
	return tiles

func _build_stitch_groups(active_cells: Array[Dictionary], pair_count: int) -> Array[Dictionary]:
	var color_cells: Dictionary = {}
	for color in COLOR_KEYS:
		color_cells[color] = []
	for cell in active_cells:
		var color := str(cell.get("color", "coral"))
		if not color_cells.has(color):
			color = "coral"
		var cells: Array = color_cells[color]
		cells.append(str(cell.get("id", "")))
		color_cells[color] = cells
	var colors: Array[String] = []
	for color in COLOR_KEYS:
		if not Array(color_cells[color]).is_empty():
			colors.append(color)
	var assignments: Array[String] = []
	var assigned: Dictionary = {}
	for color in colors:
		assigned[color] = 0
	# Give every represented color one machine first. Remaining machines are
	# distributed by the color's remaining target weight.
	for color_index in range(mini(pair_count, colors.size())):
		var first_color := colors[color_index]
		assignments.append(first_color)
		assigned[first_color] = int(assigned.get(first_color, 0)) + 1
	for _pair_index in range(assignments.size(), pair_count):
		var chosen := colors[0] if not colors.is_empty() else "coral"
		var best_score := -1.0
		for color in colors:
			var cells: Array = color_cells[color]
			var score := float(cells.size()) / float(int(assigned.get(color, 0)) + 1)
			if score > best_score:
				best_score = score
				chosen = color
		assignments.append(chosen)
		assigned[chosen] = int(assigned.get(chosen, 0)) + 1
	var groups: Array[Dictionary] = []
	var group_index_by_color: Dictionary = {}
	for index in range(assignments.size()):
		var color := assignments[index]
		var group: Dictionary = {"id": "group_%d" % index, "color": color, "target_cell_ids": []}
		groups.append(group)
		var color_groups: Array = group_index_by_color.get(color, [])
		color_groups.append(index)
		group_index_by_color[color] = color_groups
	for color in colors:
		var cells: Array = _shuffle(Array(color_cells[color]))
		var color_groups: Array = group_index_by_color.get(color, [])
		if color_groups.is_empty():
			continue
		for cell_index in range(cells.size()):
			var group_index: int = int(color_groups[cell_index % color_groups.size()])
			var target_ids: Array = groups[group_index].get("target_cell_ids", [])
			target_ids.append(cells[cell_index])
			groups[group_index].target_cell_ids = target_ids
	return groups

func _configured_link_spawn_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var layout_text := _configured_game_grid_layout() if _uses_shared_grid() else _configured_link_layout()
	var rows_text: PackedStringArray = layout_text.replace("\r", "").split("\n")
	for row in range(_link_rows()):
		var source_row := rows_text[row] if row < rows_text.size() else ""
		for column in range(_link_columns()):
			if column >= source_row.length() or _belt_grid_cell_is_occupied(row, column):
				continue
			var raw_value := source_row.substr(column, 1)
			if raw_value == "0":
				positions.append(Vector2i(row, column))
	return positions

func _parse_shared_link_tiles(layout_text: String) -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	var rows_text: PackedStringArray = layout_text.replace("\r", "").split("\n")
	for row in range(_link_rows()):
		var source_row := rows_text[row] if row < rows_text.size() else ""
		for column in range(_link_columns()):
			if column >= source_row.length():
				continue
			if _belt_grid_cell_is_occupied(row, column):
				continue
			var raw_value := source_row.substr(column, 1)
			if raw_value != raw_value.to_lower():
				continue
			var tile_key := _link_key_from_char(raw_value)
			if tile_key.is_empty():
				continue
			tiles.append({
				"id": "tile_%d_%d" % [row, column],
				"row": row,
				"column": column,
				"color": _tile_color_for_key(tile_key),
				"tile_key": tile_key,
				"removed": false
			})
	return tiles

func _link_key_from_char(value: String) -> String:
	var normalized := value.to_lower()
	return normalized if LINK_TILE_KEYS.has(normalized) else ""

func _parse_link_tiles(layout_text: String) -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	var rows_text: PackedStringArray = layout_text.replace("\r", "").split("\n")
	for row in range(_link_rows()):
		var source_row := rows_text[row] if row < rows_text.size() else ""
		for column in range(_link_columns()):
			var tile_key := _link_key_from_char(source_row.substr(column, 1)) if column < source_row.length() else ""
			if tile_key.is_empty():
				continue
			tiles.append({
				"id": "tile_%d_%d" % [row, column],
				"row": row,
				"column": column,
				"color": _tile_color_for_key(tile_key),
				"tile_key": tile_key,
				"removed": false
			})
	return tiles

func _create_compatibility_link_tiles(pattern: Array[Dictionary]) -> Array[Dictionary]:
	var keys: Array = []
	for cell in pattern:
		var tile_key := str(cell.get("required_tile_key", ""))
		if tile_key.is_empty():
			tile_key = _default_tile_key_for_color(str(cell.get("color", "coral")))
		keys.append(tile_key)
		keys.append(tile_key)
	var available_positions: Array[Vector2i] = []
	for row in range(_link_rows()):
		for column in range(_link_columns()):
			available_positions.append(Vector2i(row, column))
	available_positions = _shuffle(available_positions)
	keys = _shuffle(keys)
	var tiles: Array[Dictionary] = []
	var tile_count: int = min(keys.size(), available_positions.size())
	for index in range(tile_count):
		var position: Vector2i = available_positions[index]
		var tile_key: String = str(keys[index])
		tiles.append({
			"id": "tile_%d_%d" % [position.x, position.y],
			"row": position.x,
			"column": position.y,
			"color": _tile_color_for_key(tile_key),
			"tile_key": tile_key,
			"removed": false
		})
	return tiles

func _link_tile_at_point(point: Vector2) -> Dictionary:
	for tile_value in state.get("linkTiles", []):
		var tile: Dictionary = tile_value
		if not bool(tile.get("removed", false)) and not _is_pending_link_tile(str(tile.get("id", ""))) and _link_grid_cell_rect(int(tile.row), int(tile.column)).has_point(point):
			return tile
	return {}

func _link_tile_by_id(tile_id: String) -> Dictionary:
	for tile_value in state.get("linkTiles", []):
		var tile: Dictionary = tile_value
		if str(tile.get("id", "")) == tile_id:
			return tile
	return {}

func _is_pending_link_tile(tile_id: String) -> bool:
	return tile_id in state.get("pendingLinkTileIds", [])

func _commit_link_removals() -> void:
	var pending_ids: Array = state.get("pendingLinkTileIds", [])
	if pending_ids.is_empty():
		return
	for tile_value in state.get("linkTiles", []):
		var tile: Dictionary = tile_value
		if str(tile.get("id", "")) in pending_ids:
			tile.removed = true
	state.pendingLinkTileIds = []

func _remaining_link_tile_count() -> int:
	var remaining := 0
	for tile_value in state.get("linkTiles", []):
		var tile: Dictionary = tile_value
		if not bool(tile.get("removed", false)):
			remaining += 1
	return remaining

func _has_active_conveyor_machines() -> bool:
	for item_value in state.get("conveyorQueue", []):
		var item: Dictionary = item_value
		if str(item.get("status", "")) != "finished":
			return true
	return false

func _select_link_tile(tile: Dictionary) -> void:
	if tile.is_empty() or state.status != "playing":
		return
	if float(state.get("linkEffectLeft", 0.0)) > 0.0:
		return
	var tile_id: String = str(tile.get("id", ""))
	var selected_id: String = str(state.get("selectedTileId", ""))
	if selected_id == "":
		state.selectedTileId = tile_id
		state.selectionPulseLeft = LINK_SELECTION_PULSE_DURATION
		_show_toast("请选择相同样式的方块")
		return
	if selected_id == tile_id:
		state.selectedTileId = ""
		state.selectionPulseLeft = 0.0
		return
	var first: Dictionary = _link_tile_by_id(selected_id)
	if first.is_empty():
		state.selectedTileId = tile_id
		state.selectionPulseLeft = LINK_SELECTION_PULSE_DURATION
		return
	if _tile_style_id(first) != _tile_style_id(tile):
		state.selectedTileId = tile_id
		state.selectionPulseLeft = LINK_SELECTION_PULSE_DURATION
		_show_toast("图标样式不同，请重新选择")
		return
	var first_pos := Vector2i(int(first.column), int(first.row))
	var second_pos := Vector2i(int(tile.column), int(tile.row))
	var path: Array = _find_link_path(first_pos, second_pos)
	if path.is_empty():
		# Keep the most recently clicked tile selected so an invalid attempt
		# naturally starts the next pair from the second tile.
		state.selectedTileId = tile_id
		state.selectionPulseLeft = LINK_SELECTION_PULSE_DURATION
		_show_toast("这两个线团暂时无法连接")
		return
	if _remaining_link_tile_count() == 2 and _has_active_conveyor_machines():
		state.conveyorSpeedMultiplier = 2.0
	var tile_key: String = str(first.get("tile_key", ""))
	var style_id := _tile_style_id(first)
	var style_info := _style_info_for_id(style_id)
	var color: String = str(style_info.get("color", first.get("color", "coral")))
	state.selectedTileId = ""
	state.selectionPulseLeft = 0.0
	state.pendingLinkTileIds = [selected_id, tile_id]
	state.linkPath = path
	state.linkEffectLeft = 0.42
	state.linkEffectElapsed = 0.0
	state.linkEffectDuration = 0.42
	state.linkEffectColor = tile_key
	var stitch_group := _take_stitch_group(style_id, first, tile)
	var product: Dictionary = {
		"id": next_ball_id,
		"style_id": style_id,
		"tile_key": tile_key,
		"color": color,
		"stitchable": true,
		"start": _link_point(second_pos),
		"target": _loop_point(0.0),
		"progress": 0.0,
		"status": "to_start",
		"target_cell_id": "",
		"stitch_group_id": str(stitch_group.get("id", "")),
		"target_cell_ids": stitch_group.get("target_cell_ids", []).duplicate()
	}
	next_ball_id += 1
	link_products.append(product)
	_show_toast("连线成功，%s线团前往传送带" % COLORS[color].label)

func _take_stitch_group(style_id: int, first: Dictionary, second: Dictionary) -> Dictionary:
	var claimed: Array = state.get("claimedStitchGroupIds", [])
	var candidates: Array[Dictionary] = [first, second]
	for tile_value in state.get("linkTiles", []):
		var candidate: Dictionary = tile_value
		if _tile_style_id(candidate) == style_id and candidate not in candidates:
			candidates.append(candidate)
	for candidate in candidates:
		var group_id := str(candidate.get("stitch_group_id", ""))
		if group_id.is_empty() or group_id in claimed:
			continue
		claimed.append(group_id)
		state.claimedStitchGroupIds = claimed
		return {
			"id": group_id,
			"target_cell_ids": candidate.get("target_cell_ids", []).duplicate()
		}
	# A malformed or legacy tile still produces a product, but with no target
	# group so it can safely leave the belt without touching another group.
	return {"id": "", "target_cell_ids": []}

func _find_link_path(first: Vector2i, second: Vector2i) -> Array:
	if first == second:
		return Array()
	var columns: int = _link_columns()
	var rows: int = _link_rows()
	var occupied: Dictionary = {}
	for tile_value in state.get("linkTiles", []):
		var tile: Dictionary = tile_value
		if bool(tile.get("removed", false)):
			continue
		var position := Vector2i(int(tile.column), int(tile.row))
		if position != first and position != second:
			occupied[_link_position_key(position)] = true
	if _uses_shared_grid():
		var belt_position := _configured_belt_position()
		var belt_size := _configured_belt_size()
		for row in range(_link_rows()):
			for column in range(_link_columns()):
				if column >= belt_position.x and column < belt_position.x + belt_size.x and row >= belt_position.y and row < belt_position.y + belt_size.y:
					occupied[_link_position_key(Vector2i(column, row))] = true
	var queue: Array[Dictionary] = [{"position": first, "direction": -1, "turns": 0, "path": [first]}]
	var best_turns: Dictionary = {}
	var directions: Array = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var position: Vector2i = current.position
		var direction: int = int(current.direction)
		var turns: int = int(current.turns)
		var current_path: Array = current.path
		if position == second:
			return current_path
		for next_direction in range(directions.size()):
			var next_position: Vector2i = position + directions[next_direction]
			if next_position.x < -1 or next_position.x > columns or next_position.y < -1 or next_position.y > rows:
				continue
			if occupied.has(_link_position_key(next_position)):
				continue
			var next_turns: int = turns
			if direction >= 0 and direction != next_direction:
				next_turns += 1
			if next_turns > 2:
				continue
			var state_key := "%d,%d,%d" % [next_position.x, next_position.y, next_direction]
			if best_turns.has(state_key) and int(best_turns[state_key]) <= next_turns:
				continue
			best_turns[state_key] = next_turns
			var next_path: Array = current_path.duplicate()
			next_path.append(next_position)
			queue.append({"position": next_position, "direction": next_direction, "turns": next_turns, "path": next_path})
	return Array()

func _link_position_key(position: Vector2i) -> String:
	return "%d,%d" % [position.x, position.y]

func _update_link_products(delta: float) -> void:
	var arrived: Array[Dictionary] = []
	for product in link_products:
		product.progress = min(1.0, float(product.get("progress", 0.0)) + delta / LINK_PRODUCT_DURATION)
		if product.progress >= 1.0:
			arrived.append(product)
	for product in arrived:
		link_products.erase(product)
		var machine: Dictionary = _make_dynamic_machine(product)
		state.conveyorQueue.append(machine)


func _lose_game(message: String) -> void:
	state.status = "lost"
	_show_toast(message)

func _make_dynamic_machine(ball: Dictionary) -> Dictionary:
	return {
		"id": ball.id,
		"style_id": int(ball.get("style_id", _style_id_for_key(str(ball.get("tile_key", ""))))),
		"group_index": COLOR_KEYS.find(str(ball.get("color", "coral"))),
		"tile_key": str(ball.get("tile_key", "")),
		"color": ball.color,
		"stitchable": bool(ball.get("stitchable", true)),
		"progress": 0.0,
		"status": "moving",
		"target_progress": -1.0,
		"target_cell_id": str(ball.get("target_cell_id", "")),
		"target_cell_ids": ball.get("target_cell_ids", []).duplicate(),
		"target_index": 0,
		"has_target_group": bool(ball.get("stitchable", false)),
		"yarn_visible": true,
		"processed": false
	}

func _show_toast(message: String) -> void:
	toast_text = message
	toast_left = 2.1

func _handle_virtual_input(point: Vector2) -> void:
	if state.is_empty():
		return
	# Route all paused-screen clicks before the result/gameplay branches so the
	# level buttons cannot be swallowed by the pause toggle or result overlay.
	if game_paused:
		if pause_level_select_open:
			if _ui_layout_rect(pause_ui_node_path, pause_rect).has_point(point):
				pause_level_select_open = false
				_show_toast("已返回暂停界面")
				return
			for index in range(mini(_level_count(), 11)):
				if _pause_level_button_rect(index).has_point(point):
					runtime_level_index = index
					_reset_game()
					_show_toast("已切换到第 %02d 关" % [index + 1])
					return
			return
		if _pause_level_select_button_rect().has_point(point):
			pause_level_select_open = true
			return
		if _ui_layout_rect(pause_ui_node_path, pause_rect).has_point(point):
			game_paused = false
			_show_toast("继续绣制")
			return
		return
	if state.status != "playing":
		var action_ready: bool = state.status != "won" or victory_float_progress >= 1.0
		if action_ready and result_action_rect.has_point(point):
			if state.status == "won" and runtime_level_index < _level_count() - 1:
				runtime_level_index += 1
			_reset_game()
		return
	if _ui_layout_rect(pause_ui_node_path, pause_rect).has_point(point):
		game_paused = true
		pause_level_select_open = false
		_show_toast("游戏已暂停")
		return
	if active_link_board_rect.has_point(point):
		var tile: Dictionary = _link_tile_at_point(point)
		if not tile.is_empty():
			_select_link_tile(tile)

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
	link_products.clear()
	victory_snapshot.clear()
	victory_float_progress = 0.0
	victory_animation_active = false
	next_ball_id = 1
	game_paused = false
	pause_level_select_open = false
	toast_text = ""
	var level: Dictionary = _create_level()
	state = {
		"pattern": level.pattern,
		"activeCellIds": level.activeCellIds,
		"levelSeed": level.levelSeed,
		"stitchedCells": [],
		"conveyorQueue": [],
		"linkProducts": link_products,
		"weavingSessions": weaving_sessions,
		"linkTiles": level.linkTiles,
		"selectedTileId": "",
		"pendingLinkTileIds": [],
		"claimedStitchGroupIds": [],
		"linkPath": [],
		"linkEffectLeft": 0.0,
		"linkEffectElapsed": 0.0,
		"linkEffectDuration": 0.42,
		"selectionPulseLeft": 0.0,
		"conveyorSpeedMultiplier": 1.0,
		"linkEffectColor": "coral",
		"status": "won" if level.activeCellIds.is_empty() else "playing"
	}
	if state.status == "won":
		_start_victory_animation()
	toast_left = 0.0

func _create_level() -> Dictionary:
	var seed_value: int = randi()
	rng.seed = seed_value
	var level_pattern: Array[Dictionary] = _base_pattern()
	var link_tiles: Array[Dictionary] = _create_link_tiles()
	var active_ids: Array[String] = []
	for cell in level_pattern:
		if bool(cell.get("active", false)) and not str(cell.get("required_tile_key", "")).is_empty():
			active_ids.append(cell.id)
	return {"levelSeed": seed_value, "pattern": level_pattern, "activeCellIds": active_ids, "linkTiles": link_tiles}

func _base_pattern() -> Array[Dictionary]:
	# The stitch pattern is stored independently from the shared placement grid.
	return _parse_pattern_layout(_configured_pattern_layout())

func _parse_pattern_layout(layout_text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rows_text: PackedStringArray = layout_text.replace("\r", "").split("\n")
	var requirement_text := _configured_requirement_layout()
	var requirement_rows: PackedStringArray = requirement_text.replace("\r", "").split("\n")
	var has_requirements := not requirement_text.strip_edges().is_empty()
	var auto_mode := _uses_auto_generated_link_tiles()
	for row in range(_pattern_rows()):
		var source_row := rows_text[row] if row < rows_text.size() else ""
		var requirement_row := requirement_rows[row] if row < requirement_rows.size() else ""
		for column in range(_pattern_columns()):
			if column >= source_row.length():
				continue
			var color: String = str(CHAR_TO_COLOR.get(source_row.substr(column, 1).to_lower(), ""))
			if color.is_empty():
				continue
			var required_key := ""
			if auto_mode:
				required_key = _default_tile_key_for_color(color)
			elif column < requirement_row.length():
				required_key = _link_key_from_char(requirement_row.substr(column, 1))
			if required_key.is_empty() and not has_requirements and not auto_mode:
				required_key = _default_tile_key_for_color(color)
			result.append({
				"id": "%d-%d" % [row, column],
				"row": row,
				"column": column,
				"color": color,
				"required_tile_key": required_key,
				"active": not required_key.is_empty()
			})
	return result

func _default_tile_key_for_color(color: String) -> String:
	var group_index := COLOR_KEYS.find(color)
	if group_index < 0:
		return "0"
	var offset := 0
	var counts := _normalize_style_counts(link_tile_style_counts)
	for index in range(group_index):
		offset += counts[index]
	return _style_key_for_id(offset) if offset >= 0 else "0"

func _shuffle(items: Array) -> Array:
	var result: Array = items.duplicate()
	for index in range(result.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temp: Variant = result[index]
		result[index] = result[swap_index]
		result[swap_index] = temp
	return result
