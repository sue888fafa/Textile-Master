@tool
extends Control

## Editable 2D handle for the stitch area. Main owns the gameplay drawing;
## this node supplies the scene-editable position and size.

@export var editor_border_color: Color = Color(0.10, 0.55, 0.58, 0.82)
@export var editor_fill_color: Color = Color(0.10, 0.55, 0.58, 0.035)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if size.x <= 1.0 or size.y <= 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), editor_fill_color, true)
	draw_rect(Rect2(Vector2.ZERO, size), editor_border_color, false, 2.0)
	var handle_size := minf(12.0, maxf(minf(size.x, size.y) * 0.12, 6.0))
	var handle := Rect2(size - Vector2.ONE * handle_size, Vector2.ONE * handle_size)
	draw_rect(handle, editor_border_color, true)
	for offset in [3.0, 6.0, 9.0]:
		if offset < handle.size.x:
			draw_line(handle.position + Vector2(offset, handle.size.y), handle.position + Vector2(handle.size.x, offset), Color.WHITE, 1.0)
