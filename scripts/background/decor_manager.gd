# DecorManager.gd — 分层装饰物管理器（替代 DecorBatcher）
class_name DecorManager
extends Node3D

# ═══ 内部 ═══

class DecorEntry:
	var position: Vector3
	var scale: Vector2
	var follow: BackgroundPlane
	var spawn_time: float
	var lifetime: float   ## -1 = 永久
	var alive: bool = true
	var faded: bool = false  ## 淡出中

	func age(elapsed: float) -> float:
		return elapsed - spawn_time


class _LayerGroup:
	var multi_mesh: MultiMesh
	var mmi: MultiMeshInstance3D
	var entries: Array[DecorEntry] = []
	var dirty: bool = false
	var layer: DecorLayer


var _groups: Dictionary = {}  ## String(layer_name) → _LayerGroup
var _elapsed: float = 0.0
var _camera: Camera3D

# ═══ API ═══

func add_layer(layer: DecorLayer) -> void:
	var key := layer.name if layer.name != "" else layer.texture.resource_path
	if _groups.has(key):
		return
	var g := _LayerGroup.new()
	g.layer = layer
	_build_mesh(g, layer)
	_groups[key] = g


func remove_layer(layer_name: String) -> void:
	var g: _LayerGroup = _groups.get(layer_name)
	if not g: return
	g.mmi.queue_free()
	_groups.erase(layer_name)


func spawn(layer_name: String, pos: Vector3, tex_scale: Vector2, follow: BackgroundPlane, lifetime: float = -1.0) -> DecorEntry:
	var g: _LayerGroup = _groups.get(layer_name)
	if not g: return null
	var e := DecorEntry.new()
	e.position = pos
	e.scale = tex_scale
	e.follow = follow
	e.spawn_time = _elapsed
	e.lifetime = lifetime
	g.entries.append(e)
	g.dirty = true
	return e


func batch_spawn(layer_name: String, count: int, x_range: Vector2, follow: BackgroundPlane, lifetime: float = -1.0) -> void:
	var g: _LayerGroup = _groups.get(layer_name)
	if not g: return
	var band := g.layer.spawn_band
	var y_off := g.layer.y_offset
	var y_var := g.layer.y_variance
	var s_min := g.layer.size_min
	var s_max := g.layer.size_max
	
	for _i in count:
		var e := DecorEntry.new()
		e.position = Vector3(
			RNG.randf_range(x_range.x, x_range.y),
			y_off + RNG.randf_range(-y_var, y_var),
			RNG.randf_range(band.x, band.y)
		)
		e.scale = Vector2(
			RNG.randf_range(s_min.x, s_max.x),
			RNG.randf_range(s_min.y, s_max.y)
		)
		e.follow = follow
		e.spawn_time = _elapsed
		e.lifetime = lifetime
		g.entries.append(e)
	g.dirty = true


func remove(entry: DecorEntry) -> void:
	entry.alive = false


func clear_layer(layer_name: String) -> void:
	var g: _LayerGroup = _groups.get(layer_name)
	if not g: return
	g.entries.clear()
	g.dirty = true


# ═══ 生命周期 ═══

func _ready() -> void:
	_find_camera()


func _process(delta: float) -> void:
	_elapsed += delta

	for key in _groups:
		var g: _LayerGroup = _groups[key]
		if not g: continue

		var alive_entries: Array[DecorEntry] = []
		var needs_flush := g.dirty
		g.dirty = false

		for e in g.entries:
			# 生命周期检查
			if e.lifetime > 0.0 and e.age(_elapsed) >= e.lifetime:
				e.alive = false

			if not e.alive:
				continue

			alive_entries.append(e)

			# 跟随平面滚动
			if e.follow:
				var scrolled: Vector3 = e.follow.get_scrolled_position(e.position, g.layer.scroll_mult)
				if scrolled != e.position:
					e.position = scrolled
					needs_flush = true

		# 替换为活着的条目
		g.entries = alive_entries

		# 刷新 MultiMesh
		if needs_flush:
			_flush_group(g)


func _find_camera() -> void:
	var parent := get_parent()
	if not parent: return
	_camera = parent.get_node_or_null("Camera3D") as Camera3D
	if not _camera:
		# 从场景根搜索
		var root := get_tree().current_scene
		if root:
			_camera = root.find_child("Camera3D", true, false) as Camera3D


# ═══ 内部 ═══

func _build_mesh(g: _LayerGroup, layer: DecorLayer) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 0

	var mesh := QuadMesh.new()
	mesh.size = Vector2(1, 1)
	mesh.orientation = QuadMesh.FACE_Z

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = layer.texture
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match layer.alpha_mode:
		DecorLayer.AlphaMode.SCISSOR:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = layer.alpha_threshold
		DecorLayer.AlphaMode.BLEND:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if layer.billboard else BaseMaterial3D.BILLBOARD_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	mm.mesh = mesh

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

	g.multi_mesh = mm
	g.mmi = mmi


func _flush_group(g: _LayerGroup) -> void:
	var count := g.entries.size()
	g.multi_mesh.instance_count = count
	if count == 0:
		return

	for i in count:
		var e := g.entries[i]
		var t := Transform3D.IDENTITY
		t.origin = e.position
		t = t.scaled(Vector3(e.scale.x, e.scale.y, 1.0))
		# Billboard 模式下朝向相机
		if _camera and g.layer.billboard:
			t = t.looking_at(_camera.global_position, Vector3.UP)
		g.multi_mesh.set_instance_transform(i, t)
