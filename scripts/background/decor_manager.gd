# DecorManager.gd — 分层装饰物管理器（包装 DecorBatcher）
class_name DecorManager
extends Node3D

var _batcher: DecorBatcher
var _layers: Array[DecorLayer] = []


func _ready() -> void:
	_batcher = DecorBatcher.new()
	_batcher.name = "DecorBatcher"
	add_child(_batcher)


func add_layer(layer: DecorLayer) -> void:
	_layers.append(layer)


func remove_layer(layer_name: String) -> void:
	for i in _layers.size():
		if _layers[i].name == layer_name:
			_layers.remove_at(i)
			return


func spawn(layer_name: String, pos: Vector3, tex_scale: Vector2, follow: BackgroundPlane, _lifetime: float = -1.0) -> void:
	for layer in _layers:
		if layer.name == layer_name:
			_batcher.spawn(layer.texture, pos, tex_scale, follow)
			return


func batch_spawn(layer_name: String, count: int, x_range: Vector2, follow: BackgroundPlane, _lifetime: float = -1.0) -> void:
	var layer: DecorLayer
	for l in _layers:
		if l.name == layer_name:
			layer = l
			break
	if not layer: return

	var band := layer.spawn_band
	var y_off := layer.y_offset
	var y_var := layer.y_variance
	var s_min := layer.size_min
	var s_max := layer.size_max

	for _i in count:
		var pos := Vector3(
			RNG.randf_range(x_range.x, x_range.y),
			y_off + RNG.randf_range(-y_var, y_var),
			RNG.randf_range(band.x, band.y)
		)
		var tex_scale := Vector2(
			RNG.randf_range(s_min.x, s_max.x),
			RNG.randf_range(s_min.y, s_max.y)
		)
		_batcher.spawn(layer.texture, pos, tex_scale, follow)


func clear_layer(_layer_name: String) -> void:
	# DecorBatcher 不支持单层清理，留空
	pass
