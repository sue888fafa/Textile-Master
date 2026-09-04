@tool
extends Control

signal layout_changed(belt_position: Vector2i, link_position: Vector2i)

var grid_size := Vector2i(20, 20)
var belt_position := Vector2i(1, 2)
var belt_size := Vector2i(18, 8)
var link_position := Vector2i(1, 11)
var link_size := Vector2i(18, 8)
var dragging := ""
var drag_offset := Vector2i.ZERO

func configure(new_grid_size: Vector2i, new_belt_position: Vector2i, new_belt_size: Vector2i, new_link_position: Vector2i, new_link_size: Vector2i) -> void:
	grid_size = Vector2i(maxi(new_grid_size.x, 1), maxi(new_grid_size.y, 1))
	belt_size = Vector2i(maxi(new_belt_size.x, 5), maxi(new_belt_size.y, 5))
	link_size = Vector2i(maxi(new_link_size.x, 1), maxi(new_link_size.y, 1))
	belt_position = _clamp_position(new_belt_position, belt_size)
	link_position = _clamp_position(new_link_position, link_size)
	queue_redraw()

func _cell_size() -> Vector2:
	return Vector2(size.x / float(maxi(grid_size.x, 1)), size.y / float(maxi(grid_size.y, 1)))

func _grid_rect(position: Vector2i, dimensions: Vector2i) -> Rect2:
	var cell := _cell_size()
	return Rect2(Vector2(position) * cell, Vector2(dimensions) * cell)

func _draw() -> void:
	var cell := _cell_size()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#f5f1e8"))
	for column in range(grid_size.x + 1):
		var x := float(column) * cell.x
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.25, 0.30, 0.30, 0.18), 1.0)
	for row in range(grid_size.y + 1):
		var y := float(row) * cell.y
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.25, 0.30, 0.30, 0.18), 1.0)
	var belt_rect := _grid_rect(belt_position, belt_size)
	var link_rect := _grid_rect(link_position, link_size)
	var overlaps := _rectangles_overlap(belt_position, belt_size, link_position, link_size)
	var belt_border := Color("#c95249") if overlaps else Color("#176b7d")
	var link_border := Color("#c95249") if overlaps else Color("#a8781d")
	draw_rect(belt_rect, Color(0.20, 0.48, 0.57, 0.27), true)
	draw_rect(belt_rect, belt_border, false, 2.0)
	draw_rect(link_rect, Color(0.82, 0.58, 0.22, 0.25), true)
	draw_rect(link_rect, link_border, false, 2.0)
	draw_string(ThemeDB.fallback_font, belt_rect.position + Vector2(4, 14), "传送带", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#174a55"))
	draw_string(ThemeDB.fallback_font, link_rect.position + Vector2(4, 14), "连连看", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#6d4b11"))
	if overlaps:
		draw_string(ThemeDB.fallback_font, Vector2(4, size.y - 6), "区域重叠：不能应用", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#c95249"))

func _rectangles_overlap(first_position: Vector2i, first_size: Vector2i, second_position: Vector2i, second_size: Vector2i) -> bool:
	var first_end := first_position + first_size
	var second_end := second_position + second_size
	return first_position.x < second_end.x and first_end.x > second_position.x and first_position.y < second_end.y and first_end.y > second_position.y

func _position_from_point(point: Vector2) -> Vector2i:
	var cell := _cell_size()
	return Vector2i(clampi(floori(point.x / cell.x), 0, grid_size.x - 1), clampi(floori(point.y / cell.y), 0, grid_size.y - 1))

func _clamp_position(position: Vector2i, dimensions: Vector2i) -> Vector2i:
	return Vector2i(clampi(position.x, 0, maxi(grid_size.x - dimensions.x, 0)), clampi(position.y, 0, maxi(grid_size.y - dimensions.y, 0)))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var point: Vector2 = event.position
			var belt_rect := _grid_rect(belt_position, belt_size)
			var link_rect := _grid_rect(link_position, link_size)
			if belt_rect.has_point(point):
				dragging = "belt"
				drag_offset = _position_from_point(point) - belt_position
				accept_event()
			elif link_rect.has_point(point):
				dragging = "link"
				drag_offset = _position_from_point(point) - link_position
				accept_event()
		else:
			dragging = ""
			accept_event()
	elif event is InputEventMouseMotion and not dragging.is_empty():
		var new_position := _position_from_point(event.position) - drag_offset
		if dragging == "belt":
			belt_position = _clamp_position(new_position, belt_size)
		else:
			link_position = _clamp_position(new_position, link_size)
		layout_changed.emit(belt_position, link_position)
		queue_redraw()
		accept_event()
