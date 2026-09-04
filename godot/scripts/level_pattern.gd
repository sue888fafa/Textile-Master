@tool
extends Resource
class_name StitchLevelPattern

const DEFAULT_LAYOUT := "cc..dd..cc\nc..yyyy..c\n..yyyyyy..\n.yyggggyy.\nyyggbbggyy\nyyggbbggyy\n.yyggggyy.\n..yyyyyy..\nc..yyyy..c\ncc..dd..cc"

@export var level_name: String = "新关卡"
@export_storage var pattern_grid_size: Vector2i = Vector2i(10, 10):
	set(value):
		pattern_grid_size = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
@export_storage var pattern_layout: String = DEFAULT_LAYOUT
@export_storage var link_grid_size: Vector2i = Vector2i(12, 12):
	set(value):
		link_grid_size = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
@export_storage var link_layout: String = ""

@export_category("Shared Game Grid")
@export_multiline var game_grid_layout: String = ""
@export_multiline var stitch_requirement_layout: String = ""
@export_storage var auto_generate_link_tiles: bool = true
# Kept on each level so style choices can be serialized with standalone levels.
@export_storage var link_tile_textures: Array[Texture2D] = []
@export var link_tile_style_counts: Array[int] = [6, 6, 6, 6, 6, 6, 6, 6, 6]:
	set(value):
		var normalized: Array[int] = []
		for group_index in range(9):
			var count := 6 if group_index >= value.size() else int(value[group_index])
			normalized.append(clampi(count, 1, 8))
		link_tile_style_counts = normalized
@export_storage var valid_link_tile_count: int = -1

@export_category("Layout Editing")
@export var layout_grid_size: Vector2i = Vector2i(10, 25)
@export var belt_grid_position: Vector2i = Vector2i(0, 0)
@export var belt_grid_size: Vector2i = Vector2i(8, 8)
@export_storage var link_board_grid_position: Vector2i = Vector2i.ZERO
@export_storage var link_board_grid_size: Vector2i = Vector2i.ZERO
@export_storage var layout_configured: bool = false

# Kept as hidden storage for scenes created by the first editor version.
@export_storage var grid_size: Vector2i = Vector2i.ZERO
@export_storage var layout: String = ""
