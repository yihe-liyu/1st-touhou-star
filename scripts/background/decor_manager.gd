# DecorManager.gd — 分层装饰物管理器（自定义 MultiMesh）
class_name DecorManager
extends Node3D

# ═══ 内部 ═══

class DecorEntry:
	var position: Vector3
	var scale: Vector2
	var follow: BackgroundPlane
	var spawn_time: float
	var lifetime: float = -1.0
	var alive: bool = true


class _LayerGroup:
	var multi_mesh: MultiMesh
	var mmi: MultiMeshInstance3D
	var entries: Array[DecorEntry] = []
	var layer: DecorLayer


var _groups: Dictionary = {}
var _elapsed: float = 0.0
var _camera: Camera3D


# ═══ API ═══

func add_layer(layer: DecorLayer) -> void:
	var key := layer.name if layer.name != "" else layer.texture.resource_path
	if _groups.has(key): return
	var g := _LayerGroup.new()
	g.layer = layer
	_build_mesh(g, layer)
	_groups[key] = g


func spawn(layer_name: String, pos: Vector3, tex_scale: Vector2, follow: BackgroundPlane, lifetime: float = -1.0) -> void:
	var g: _LayerGroup = _groups.get(layer_name)
	if not g: return
	var e := DecorEntry.new()
	e.position = pos
	e.scale = tex_scale
	e.follow = follow
	e.spawn_time = _elapsed
	e.lifetime = lifetime
	g.entries.append(e)


func batch_spawn(layer_name: String, count: int, x_range: Vector2, follow: BackgroundPlane, lifetime: float = -1.0) -> void:
	var g: _LayerGroup = _groups.get(layer_name)
	if not g: return
	var layer := g.layer
	var band := layer.spawn_band
	var y_var := layer.y_variance
	var s_min := layer.size_min
	var s_max := layer.size_max
	for _i in count:
		var tex_scale := Vector2(RNG.randf_range(s_min.x, s_max.x), RNG.randf_range(s_min.y, s_max.y))
		var pos := Vector3(RNG.randf_range(x_range.x, x_range.y), tex_scale.y / 2.0 + RNG.randf_range(-y_var, y_var), RNG.randf_range(band.x, band.y))
		var e := DecorEntry.new()
		e.position = pos
		e.scale = tex_scale
		e.follow = follow
		e.spawn_time = _elapsed
		e.lifetime = lifetime
		g.entries.append(e)


# ═══ 生命周期 ═══

func _ready() -> void:
	_find_camera()


func _process(delta: float) -> void:
	_elapsed += delta
	for key in _groups:
		var g: _LayerGroup = _groups[key]
		var entries: Array[DecorEntry] = g.entries
		for e in entries:
			# 跟随地面滚动
			if e.follow:
				var rx: float = e.follow.plane_size.x / maxf(e.follow.tiling.x, 1.0)
				var ry: float = e.follow.plane_size.y / maxf(e.follow.tiling.y, 1.0)
				e.position += Vector3(
					e.follow.scroll_speed.x * rx,
					0,
					-e.follow.scroll_speed.y * ry
				) * delta
			# 生命周期 / 超视野
			if e.lifetime > 0 and (e.spawn_time > 0 and _elapsed - e.spawn_time >= e.lifetime):
				e.alive = false
			if e.position.z > 100 or e.position.z < -400:
				e.alive = false
		var alive: Array[DecorEntry] = []
		for e in entries:
			if e.alive: alive.append(e)
		g.entries = alive
		g.entries.sort_custom(func(a, b): return a.position.z < b.position.z)
		_flush_mm(g)
		_flush_mm(g)


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
	if layer.alpha_mode == DecorLayer.AlphaMode.BLEND:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = layer.alpha_threshold
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


func _flush_mm(g: _LayerGroup) -> void:
	var entries := g.entries
	var n := entries.size()
	var mm := g.multi_mesh
	if mm.instance_count != n:
		mm.instance_count = n
	for i in n:
		var e := entries[i]
		if e.alive:
			var t := Transform3D().scaled(Vector3(e.scale.x, e.scale.y, 1.0))
			t.origin = e.position
			mm.set_instance_transform(i, t)
		else:
			mm.set_instance_transform(i, Transform3D())


func _find_camera() -> void:
	var bg := get_parent()
	if not bg: return
	var subviewport := bg.get_parent()
	if subviewport:
		_camera = subviewport.get_node_or_null("Camera3D") as Camera3D
	if not _camera:
		var root := get_tree().current_scene
		if root:
			_camera = root.find_child("Camera3D", true, false) as Camera3D
