## 工作台预览画布（@tool）—— 自带 _draw，绘制聚焦生命周期树
## 世界坐标（东方框 64,32 ~ 832,928）→ 画布坐标自动缩放适配 + 居中
## 性能：子弹用 MultiMesh 批量渲染（一次 draw call 画上千颗）；轨迹自适应降级
@tool
extends Control
class_name WorkbenchCanvas

var focus: LifecycleNode
var trail_length: int = 24   ## 拖尾帧数（0 = 关闭）
var show_trail: bool = true  ## 拖尾开关
var playing: bool = false    ## 播放中不画轨迹（运动时无意义，暂停看弹道）
var reset_flash: float = 0.0  ## 重置提示剩余时长

const WORLD := Rect2(64, 32, 768, 896)  # 东方框世界坐标

var _scale := 1.0
var _offset := Vector2.ZERO

var _bullet_groups: Dictionary = {}  # 贴图路径 → MultiMeshInstance2D（分组批量）
const MAX_BULLETS := 4096
const _DEFAULT_TEX := preload("res://assets/Textures/effect/glow_dot.png")


func _ready() -> void:
	pass  # MultiMesh 组按需懒创建（_get_bullet_group）


## 世界坐标 → 画布坐标（缩放 + 居中）
func _to_screen(p: Vector2) -> Vector2:
	return _offset + p * _scale


func _update_view() -> void:
	var margin := 12.0
	var avail: Vector2 = size - Vector2(margin, margin) * 2.0
	# 防御：画布太小/布局未就绪时回退 1:1，绝不产生负缩放（内容飞出）
	if avail.x <= 4.0 or avail.y <= 4.0:
		_scale = 1.0
		_offset = -WORLD.position
		return
	_scale = minf(avail.x / WORLD.size.x, avail.y / WORLD.size.y)
	_offset = (size - WORLD.size * _scale) / 2.0 - WORLD.position * _scale


func _world_rect() -> Rect2:
	return Rect2(_offset + WORLD.position * _scale, WORLD.size * _scale)


func _draw() -> void:
	if focus == null:
		return
	_update_view()
	var wrect := _world_rect()
	# 东方框背景
	draw_rect(wrect, Color(0.08, 0.08, 0.16), true)
	draw_rect(wrect, Color(0.3, 0.3, 0.5, 0.4), false, 1.5)
	# 网格（世界坐标每 64px）
	for x in range(64, 832, 64):
		draw_line(_to_screen(Vector2(x, 32)), _to_screen(Vector2(x, 928)), Color(1, 1, 1, 0.04))
	for y in range(32, 928, 64):
		draw_line(_to_screen(Vector2(64, y)), _to_screen(Vector2(832, y)), Color(1, 1, 1, 0.04))
	# 所有活动节点（DFS 全树）
	var alive: Array = focus.collect_alive()
	var bullets: Array = []
	for node in alive:
		if node is LifecycleBullet:
			bullets.append(node as LifecycleBullet)
		elif node != focus:
			_draw_node_marker(node)
	# 轨迹：只在暂停时画（看弹道）；播放中跳过（性能）
	var n := bullets.size()
	var trail_n := trail_length
	if n > 400: trail_n = mini(trail_n, 12)
	if n > 1200: trail_n = mini(trail_n, 6)
	if n > 2500: trail_n = 0
	if not playing and show_trail and trail_n > 0:
		for b in bullets:
			for i in trail_n:
				var tp: Vector2 = _to_screen(b.position_at(maxf(0.0, b.local_time - i * LifecycleNode.TICK)))
				draw_circle(tp, 1.5, Color(1.0, 0.3, 0.2, 0.15))
	# 子弹批量（按贴图分组，每组一次 draw call）
	_sync_bullet_groups(bullets)
	# 重置提示（画布中央，短暂显示）
	if reset_flash > 0.0:
		var alpha: float = clampf(reset_flash / 0.4, 0.0, 1.0)
		var txt := "↺ 已重置 t=0"
		var fs := 22
		var wd := txt.length() * fs * 0.6
		draw_string(ThemeDB.fallback_font, Vector2((size.x - wd) / 2.0, size.y / 2.0),
			txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.9, 0.4, alpha))


## 子弹 → 按贴图分组 MultiMesh（每组一次 draw call）
func _sync_bullet_groups(bullets: Array) -> void:
	# 按贴图分组
	var groups: Dictionary = {}  # tex → [bullets]
	for b in bullets:
		var tex: Texture2D = (b as LifecycleBullet).texture if (b as LifecycleBullet).texture else _DEFAULT_TEX
		var key: String = tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
		if not groups.has(key):
			groups[key] = {tex = tex, bullets = []}
		groups[key].bullets.append(b)
	# 填充各组 MultiMesh
	var seen: Array = []
	for key in groups:
		var g: Dictionary = groups[key]
		var mmi: MultiMeshInstance2D = _get_bullet_group(g.tex)
		seen.append(mmi)
		var mm: MultiMesh = mmi.multimesh
		var list: Array = g.bullets
		var count := mini(list.size(), MAX_BULLETS)
		mm.instance_count = count
		var r: float = 2.5 * _scale
		for i in count:
			var p: Vector2 = _to_screen((list[i] as LifecycleBullet).position())
			mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(r, r), 0.0, p))
			mm.set_instance_color(i, Color(1.0, 1.0, 1.0))
	# 隐藏没用的组
	for mmi in _bullet_groups.values():
		if not seen.has(mmi):
			(mmi.multimesh as MultiMesh).instance_count = 0


## 按贴图取（或创建）MultiMesh 组
func _get_bullet_group(tex: Texture2D) -> MultiMeshInstance2D:
	var key: String = tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _bullet_groups.has(key):
		return _bullet_groups[key]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.instance_count = 0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(32, 32)
	mm.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/bullet_batch.gdshader")
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("region", Vector4(0, 0, 1, 1))
	mat.set_shader_parameter("tint_mode", 0)  # 乘法：贴图 × 实例色
	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = mm
	mmi.material = mat
	add_child(mmi)
	_bullet_groups[key] = mmi
	return mmi


## 通用节点标记（非子弹实体）：小方块 + 存活框
func _draw_node_marker(_node: LifecycleNode) -> void:
	var pos := _to_screen(Vector2(448, 480))
	var half := 6.0 * _scale
	draw_rect(Rect2(pos - Vector2(half, half), Vector2(half * 2, half * 2)), Color(0.4, 0.7, 1.0, 0.5))
	draw_rect(Rect2(pos - Vector2(half, half), Vector2(half * 2, half * 2)), Color(0.4, 0.7, 1.0), false, 1.0)
