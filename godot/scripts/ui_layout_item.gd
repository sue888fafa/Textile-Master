@tool
extends Control

## Scene-editable layout marker for HUD and tool slots.
## Main owns the runtime drawing; this node provides a visible 2D handle.

@export_enum("金币", "关卡", "暂停", "增时", "打乱", "自动消除") var item_type: int = 0:
	set(value):
		item_type = value
		queue_redraw()
@export var editor_border_color: Color = Color(0.10, 0.55, 0.58, 0.82)
@export var editor_fill_color: Color = Color(0.10, 0.55, 0.58, 0.035)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint() or size.x <= 1.0 or size.y <= 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), editor_fill_color, true)
	draw_rect(Rect2(Vector2.ZERO, size), editor_border_color, false, 2.0)
	var labels: Array[String] = ["金币", "关卡", "暂停", "增时", "打乱", "自动消除"]
	var label: String = labels[clampi(item_type, 0, labels.size() - 1)]
	var preview_size := clampi(int(minf(size.x, size.y) * 0.24), 8, 14)
	draw_string(ThemeDB.fallback_font, Vector2(4, preview_size + 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, preview_size, editor_border_color)
	var handle_size := minf(12.0, maxf(minf(size.x, size.y) * 0.2, 6.0))
	var handle := Rect2(size - Vector2.ONE * handle_size, Vector2.ONE * handle_size)
	draw_rect(handle, editor_border_color, true)
	for offset in [3.0, 6.0, 9.0]:
		if offset < handle.size.x:
			draw_line(handle.position + Vector2(offset, handle.size.y), handle.position + Vector2(handle.size.x, offset), Color.WHITE, 1.0)
