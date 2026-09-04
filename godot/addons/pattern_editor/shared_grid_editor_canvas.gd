@tool
extends Control

signal grid_cell_pressed(row: int, column: int)
signal grid_cells_moved(from_row: int, from_column: int, to_row: int, to_column: int)
signal belt_position_changed(position: Vector2i)
signal belt_size_changed(size: Vector2i)

var grid_size := Vector2i(10, 25)
var belt_position := Vector2i.ZERO
var belt_size := Vector2i(5, 5)
var grid_data: Array = []
var selected_cell := Vector2i(-1, -1)
var link_textures: Array = []
var link_tile_background_texture: Texture2D
var dragging_belt := false
var resizing_belt := false
var drag_offset := Vector2i.ZERO
var pressed_cell := Vector2i(-1, -1)
var dragging_grid := false
var painting_grid := false
var dragged_content := "."
var rejected_drag_cell := Vector2i(-1, -1)
var drag_cell := Vector2i(-1, -1)

func configure(new_grid_size: Vector2i, new_belt_position: Vector2i, new_belt_size: Vector2i, new_grid_data: Array, new_selected_cell: Vector2i, new_link_textures: Array = [], new_link_tile_background_texture: Texture2D = null) -> void:
	grid_size = Vector2i(maxi(new_grid_size.x, 1), maxi(new_grid_size.y, 1))
	belt_size = Vector2i(maxi(new_belt_size.x, 5), maxi(new_belt_size.y, 5))
	belt_position = _clamp_position(new_belt_position, belt_size)
	grid_data = new_grid_data
	selected_cell = new_selected_cell
	link_textures = new_link_textures
	link_tile_background_texture = new_link_tile_background_texture
	queue_redraw()

func _cell_size() -> float:
	return minf(size.x / float(maxi(grid_size.x, 1)), size.y / float(maxi(grid_size.y, 1)))

func _grid_origin() -> Vector2:
	var cell := _cell_size()
	return (size - Vector2(grid_size) * cell) * 0.5

func _grid_cell_rect(row: int, column: int) -> Rect2:
	var cell := _cell_size()
	return Rect2(_grid_origin() + Vector2(column, row) * cell, Vector2.ONE * cell)

func _belt_rect() -> Rect2:
	var cell := _cell_size()
	return Rect2(_grid_origin() + Vector2(belt_position) * cell, Vector2(belt_size) * cell)

func _belt_resize_handle_rect() -> Rect2:
	var belt := _belt_rect()
	var handle_size := minf(16.0, maxf(_cell_size() * 0.8, 10.0))
	return Rect2(belt.end - Vector2.ONE * handle_size, Vector2.ONE * handle_size)

func _size_from_point(point: Vector2) -> Vector2i:
	var cell := _cell_size()
	var local := point - _grid_origin()
	var right := clampi(floori(local.x / cell) + 1, belt_position.x + 5, grid_size.x)
	var bottom := clampi(floori(local.y / cell) + 1, belt_position.y + 5, grid_size.y)
	return Vector2i(right - belt_position.x, bottom - belt_position.y)

func _draw() -> void:
	var cell := _cell_size()
	var origin := _grid_origin()
	var grid_rect := Rect2(origin, Vector2(grid_size) * cell)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#f5f1e8"))
	draw_rect(grid_rect, Color("#fffdf8"), true)
	for column in range(grid_size.x + 1):
		var x := origin.x + float(column) * cell
		draw_line(Vector2(x, origin.y), Vector2(x, grid_rect.end.y), Color(0.25, 0.30, 0.30, 0.24), 1.0)
	for row in range(grid_size.y + 1):
		var y := origin.y + float(row) * cell
		draw_line(Vector2(origin.x, y), Vector2(grid_rect.end.x, y), Color(0.25, 0.30, 0.30, 0.24), 1.0)
	for row in range(mini(grid_size.y, grid_data.size())):
		var row_data: Array = grid_data[row]
		for column in range(mini(grid_size.x, row_data.size())):
			var value := str(row_data[column])
			if value.is_empty() or value == ".":
				continue
			var cell_rect := _grid_cell_rect(row, column).grow(-1.5)
			if value in ["C", "Y", "G", "L", "D"]:
				draw_rect(cell_rect, _stitch_color(value), true)
				draw_rect(cell_rect, Color("#ffffff"), false, 1.0)
				draw_string(ThemeDB.fallback_font, cell_rect.position + Vector2(3, cell_rect.size.y - 3), value, HORIZONTAL_ALIGNMENT_LEFT, -1, maxf(8.0, cell * 0.32), Color.WHITE)
			else:
				if link_tile_background_texture:
					draw_texture_rect(link_tile_background_texture, cell_rect, false)
				var texture_index := "0123456789abcdefghijklmnopqrstuv".find(value.to_lower())
				if texture_index >= 0 and texture_index < link_textures.size() and link_textures[texture_index]:
					_draw_texture_contain(link_textures[texture_index], cell_rect.grow(-cell * 0.12))
				else:
					draw_circle(cell_rect.get_center(), cell_rect.size.x * 0.27, _link_color(value))
	var belt := _belt_rect()
	var belt_conflict := _belt_has_content()
	draw_rect(belt, Color(0.72, 0.19, 0.16, 0.24) if belt_conflict else Color(0.08, 0.42, 0.52, 0.16), true)
	draw_rect(belt, Color("#c95249") if belt_conflict else Color("#176b7d"), false, 2.0)
	draw_string(ThemeDB.fallback_font, belt.position + Vector2(3, minf(14.0, belt.size.y - 3.0)), "传送带", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#174a55"))
	var handle := _belt_resize_handle_rect()
	draw_rect(handle, Color("#176b7d") if not belt_conflict else Color("#c95249"), true)
	for offset in [4.0, 8.0, 12.0]:
		if offset < handle.size.x:
			draw_line(handle.position + Vector2(offset, handle.size.y), handle.position + Vector2(handle.size.x, offset), Color.WHITE, 1.0)
	if selected_cell.x >= 0 and selected_cell.y >= 0 and selected_cell.y < grid_size.y and selected_cell.x < grid_size.x:
		draw_rect(_grid_cell_rect(selected_cell.y, selected_cell.x).grow(-1.0), Color("#fff0a1"), false, 2.0)

func _stitch_color(value: String) -> Color:
	return {"C": Color("#e86b5b"), "O": Color("#f27618"), "Y": Color("#e6b93f"), "V": Color("#8bb900"), "G": Color("#5b9c72"), "L": Color("#16b7c5"), "A": Color("#16b7c5"), "D": Color("#1474d4"), "P": Color("#8f2bd8"), "R": Color("#ed2164")}.get(value, Color("#9b9d9c"))

func _link_color(value: String) -> Color:
	var index := "0123456789abcdefghijklmnopqrstuv".find(value.to_lower())
	var colors := ["#e92b3d", "#f27618", "#f2c515", "#8bb900", "#17bd3d", "#12b8cf", "#2168df", "#8f2bd8", "#ed2164", "#8abd12", "#e88b2a", "#e7a12b", "#e33d43", "#69a82f", "#2b75bd", "#f0c247", "#f1ad26", "#dc4b8d", "#d18b55", "#4c9c54", "#e667a8", "#288fc2", "#e25291", "#ef8425", "#8b48cf", "#f0b52c", "#e78b26", "#ed7d22", "#e77799", "#7449bd", "#d84c9d", "#418ed0"]
	return Color(colors[index]) if index >= 0 else Color("#9b9d9c")

func _draw_texture_contain(texture: Texture2D, rect: Rect2) -> void:
	if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
		return
	var source_size := Vector2(texture.get_width(), texture.get_height())
	var scale_factor := minf(rect.size.x / source_size.x, rect.size.y / source_size.y)
	var draw_size := source_size * scale_factor
	draw_texture_rect(texture, Rect2(rect.position + (rect.size - draw_size) * 0.5, draw_size), false)

func _position_from_point(point: Vector2) -> Vector2i:
	var cell := _cell_size()
	var local := point - _grid_origin()
	return Vector2i(clampi(floori(local.x / cell), 0, grid_size.x - 1), clampi(floori(local.y / cell), 0, grid_size.y - 1))

func _is_point_in_grid(point: Vector2) -> bool:
	return Rect2(_grid_origin(), Vector2(grid_size) * _cell_size()).has_point(point)

func _clamp_position(position: Vector2i, dimensions: Vector2i) -> Vector2i:
	return Vector2i(clampi(position.x, 0, maxi(grid_size.x - dimensions.x, 0)), clampi(position.y, 0, maxi(grid_size.y - dimensions.y, 0)))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var point: Vector2 = event.position
			if _belt_resize_handle_rect().has_point(point):
				resizing_belt = true
				pressed_cell = Vector2i(-1, -1)
				dragging_grid = false
				painting_grid = false
				accept_event()
			elif _belt_rect().has_point(point):
				dragging_belt = true
				resizing_belt = false
				pressed_cell = Vector2i(-1, -1)
				dragging_grid = false
				painting_grid = false
				drag_offset = _position_from_point(point) - belt_position
				accept_event()
			else:
				if not _is_point_in_grid(point):
					return
				pressed_cell = _position_from_point(point)
				drag_cell = pressed_cell
				dragged_content = _content_at(pressed_cell)
				rejected_drag_cell = Vector2i(-1, -1)
				dragging_grid = false
				painting_grid = false
				accept_event()
		else:
			dragging_belt = false
			resizing_belt = false
			if pressed_cell.x >= 0 and not dragging_grid and not painting_grid:
				grid_cell_pressed.emit(pressed_cell.y, pressed_cell.x)
			pressed_cell = Vector2i(-1, -1)
			drag_cell = Vector2i(-1, -1)
			dragged_content = "."
			rejected_drag_cell = Vector2i(-1, -1)
			dragging_grid = false
			painting_grid = false
			accept_event()
	elif event is InputEventMouseMotion and resizing_belt:
		var new_size := _size_from_point(event.position)
		if new_size != belt_size:
			belt_size = new_size
			belt_size_changed.emit(belt_size)
			queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and dragging_belt:
		var new_position := _position_from_point(event.position) - drag_offset
		belt_position = _clamp_position(new_position, belt_size)
		belt_position_changed.emit(belt_position)
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and pressed_cell.x >= 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var grid_point := _position_from_point(event.position)
		if grid_point == pressed_cell:
			return
		if not dragging_grid and not painting_grid:
			if _content_at(pressed_cell) != ".":
				dragging_grid = true
			else:
				painting_grid = true
				grid_cell_pressed.emit(pressed_cell.y, pressed_cell.x)
		if dragging_grid:
			if grid_point == drag_cell:
				return
			rejected_drag_cell = Vector2i(-1, -1)
			var from_cell := drag_cell
			grid_cells_moved.emit(from_cell.y, from_cell.x, grid_point.y, grid_point.x)
			if rejected_drag_cell != from_cell:
				drag_cell = grid_point
				pressed_cell = grid_point
		elif painting_grid:
			grid_cell_pressed.emit(grid_point.y, grid_point.x)
			pressed_cell = grid_point
		accept_event()

func _content_at(position: Vector2i) -> String:
	if position.y < 0 or position.y >= grid_data.size():
		return "."
	var row_data: Array = grid_data[position.y]
	if position.x < 0 or position.x >= row_data.size():
		return "."
	var value := str(row_data[position.x])
	return value if not value.is_empty() else "."

func _belt_has_content() -> bool:
	for row in range(belt_position.y, belt_position.y + belt_size.y):
		if row < 0 or row >= grid_data.size():
			continue
		var row_data: Array = grid_data[row]
		for column in range(belt_position.x, belt_position.x + belt_size.x):
			if column < 0 or column >= row_data.size():
				continue
			var value := str(row_data[column])
			if not value.is_empty() and value != ".":
				return true
	return false

func reject_grid_move(original_cell: Vector2i) -> void:
	rejected_drag_cell = original_cell
	pressed_cell = original_cell
	drag_cell = original_cell
	queue_redraw()
