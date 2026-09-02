@tool
extends Resource
class_name StitchLevelPattern

const DEFAULT_LAYOUT := "cc..dd..cc\nc..yyyy..c\n..yyyyyy..\n.yyggggyy.\nyyggbbggyy\nyyggbbggyy\n.yyggggyy.\n..yyyyyy..\nc..yyyy..c\ncc..dd..cc"

@export var level_name: String = "新关卡"
@export var grid_size: Vector2i = Vector2i(10, 10)
@export_multiline var layout: String = DEFAULT_LAYOUT
