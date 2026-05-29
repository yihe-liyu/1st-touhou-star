extends CanvasLayer
# 全局 miss 特效管理器

var _debug_rect: ColorRect


func _ready() -> void:
	layer = 100  # 最顶层
	_debug_rect = ColorRect.new()
	_debug_rect.color = Color.RED
	_debug_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_debug_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_debug_rect)
	print("[MissEffectManager] ready, CanvasLayer layer=", layer)


func add_circle(_world_pos: Vector2, _duration: float = 0.6, _max_radius: float = 500.0, _start_radius: float = 30.0) -> void:
	print("[MissEffectManager] add_circle")
