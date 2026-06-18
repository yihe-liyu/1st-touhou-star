extends Node3D
class_name DecorBatcher
## 装饰物批渲染 —— 把相同纹理的装饰物合并到一个 MultiMesh

class DecorEntry:
	var position: Vector3
	var scale: Vector2
	var follow: BackgroundPlane
	var alive: bool = true

var _groups: Dictionary = {}  # tex_resource_path → {mmi, mm, entries: Array[DecorEntry]}
var _dirty: bool = false

const MAX_FREE_RATIO := 0.3  # 死实例超 30% 时整理

func spawn(tex: Texture2D, pos: Vector3, tex_scale: Vector2, follow: BackgroundPlane) -> void:
	var key := tex.resource_path
	if not _groups.has(key):
		_create_group(key, tex)
	var g: Dictionary = _groups[key]
	var e := DecorEntry.new()
	e.position = pos
	e.scale = tex_scale
	e.follow = follow
	g.entries.append(e)
	_dirty = true

func _process(delta: float) -> void:
	var dead_count := 0
	var total := 0
	
	for key in _groups:
		var g: Dictionary = _groups[key]
		var entries: Array[DecorEntry] = g.entries
		var mm: MultiMesh = g.mm
		total += entries.size()
		
		# 更新位置
		for e in entries:
			if not e.alive:
				dead_count += 1
				continue
			if e.follow:
				var ratio_x: float = 1.0
				var ratio_y: float = 1.0
				if e.follow.tiling.x > 0:
					ratio_x = e.follow.plane_size.x / e.follow.tiling.x
				if e.follow.tiling.y > 0:
					ratio_y = e.follow.plane_size.y / e.follow.tiling.y
				e.position += Vector3(
					e.follow.scroll_speed.x * ratio_x,
					0,
					-e.follow.scroll_speed.y * ratio_y
				) * delta
			# 超出视野
			if e.position.z > 100 or e.position.z < -400:
				e.alive = false
				dead_count += 1
		
		# 按深度排序（远 → 近，保证透明叠加正确）
		entries.sort_custom(func(a: DecorEntry, b: DecorEntry): return a.position.z < b.position.z)
		
		# 同步到 MultiMesh
		var n: int = entries.size()
		if mm.instance_count != n:
			mm.instance_count = n
		for i in n:
			var e: DecorEntry = entries[i]
			if e.alive:
				var t := Transform3D().scaled(Vector3(e.scale.x, e.scale.y, 1.0))
				t.origin = e.position
				mm.set_instance_transform(i, t)
			else:
				mm.set_instance_transform(i, Transform3D())
	
	# 定期清理死实例
	if total > 0 and float(dead_count) / float(total) > MAX_FREE_RATIO:
		_compact()

func _compact() -> void:
	for key in _groups:
		var g: Dictionary = _groups[key]
		var entries: Array[DecorEntry] = g.entries
		var alive: Array[DecorEntry] = []
		for e in entries:
			if e.alive:
				alive.append(e)
		g.entries = alive

func _create_group(key: String, tex: Texture2D) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 0
	
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1, 1)
	mesh.orientation = QuadMesh.FACE_Z
	
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.8
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	mm.mesh = mesh
	
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	
	_groups[key] = {mmi = mmi, mm = mm, entries = [] as Array[DecorEntry]}

func clear() -> void:
	for key in _groups:
		var g: Dictionary = _groups[key]
		g.mmi.queue_free()
	_groups.clear()
