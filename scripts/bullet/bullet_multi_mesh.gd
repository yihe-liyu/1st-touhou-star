# BulletMultiMesh — 用 MultiMeshInstance2D 批量渲染子弹
# 所有子弹合并为 1 次 draw call（按纹理 × 阵营分组）
extends Node2D
class_name BulletMultiMesh

## 是否启用 MultiMesh 批渲染
@export var enabled: bool = true

var _groups: Dictionary = {}  # "tex_path|faction" → {mmi, mm, mesh}

func _ready():
	set_process(enabled)

func _process(_delta):
	if not enabled:
		return
	_sync()

func _sync():
	# 收集活跃子弹，按 texture + faction 分组
	var active_groups: Dictionary = {}
	for bullet in BulletManager.active_bullets:
		if not is_instance_valid(bullet) or not bullet.visible or not bullet.is_ready:
			continue
		var tex = bullet.batch_texture()
		if not tex:
			continue
		var key = tex.resource_path + "|" + str(bullet.faction) + "|" + str(bullet.tint_mode)
		if not active_groups.has(key):
			active_groups[key] = {tex = tex, faction = bullet.faction, tint_mode = bullet.tint_mode, bullets = []}
		active_groups[key].bullets.append(bullet)

	# 更新每个分组的 MultiMesh
	for key in active_groups:
		var g = active_groups[key]
		var bullets: Array = g.bullets
		var eg = _get_or_create_group(key, g.tex, g.faction, g.tint_mode, bullets.size())

		var mm: MultiMesh = eg.mm
		mm.instance_count = bullets.size()
		eg.mmi.visible = true

		for i in bullets.size():
			var b = bullets[i]
			var t = Transform2D(b.rotation, b.scale, 0.0, b.global_position)
			mm.set_instance_transform_2d(i, t)
			mm.set_instance_color(i, b.sprite.modulate)

	# 隐藏没有在用的分组
	for key in _groups:
		if not active_groups.has(key):
			_groups[key].mmi.visible = false
			_groups[key].mm.instance_count = 0

func clear():
	for grp in _groups.values():
		if is_instance_valid(grp.mmi):
			grp.mmi.queue_free()
	_groups.clear()

func _get_or_create_group(key: String, tex: Texture2D, faction: int, tint_mode: int, min_size: int) -> Dictionary:
	if _groups.has(key):
		var existing = _groups[key]
		if existing.mm.instance_count < min_size:
			existing.mm.instance_count = min_size
		return existing

	# ── 处理 AtlasTexture → 用图集 + UV 偏移 ──
	var use_tex = tex
	var use_region := Vector4(0.0, 0.0, 1.0, 1.0)
	if tex is AtlasTexture:
		var atex = tex as AtlasTexture
		use_tex = atex.atlas
		var atlas_size = atex.atlas.get_size()
		var r = atex.region
		use_region = Vector4(
			r.position.x / atlas_size.x,
			r.position.y / atlas_size.y,
			r.size.x / atlas_size.x,
			r.size.y / atlas_size.y
		)

	# ── 创建 MultiMesh ──
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.instance_count = max(min_size, 64)

	# ── 创建 2D 四边形网格 ──
	# 尺寸匹配纹理像素大小
	var tex_size = use_tex.get_size()
	var quad_w = tex_size.x
	var quad_h = tex_size.y
	if tex is AtlasTexture:
		var r = (tex as AtlasTexture).region
		quad_w = r.size.x
		quad_h = r.size.y

	var mesh = QuadMesh.new()
	mesh.size = Vector2(quad_w, quad_h)

	# ── 材质（用 shader 文件，不要运行时拼字符串）──
	var shader = preload("res://gdshader/bullet_batch.gdshader")
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tex", use_tex)
	mat.set_shader_parameter("region", use_region)
	mat.set_shader_parameter("tint_mode", tint_mode)
	mm.mesh = mesh

	# ── MultiMeshInstance2D ──
	var mmi = MultiMeshInstance2D.new()
	mmi.multimesh = mm
	mmi.material = mat
	match faction:
		Bullet.FACTION_ENEMY:
			mmi.z_index = 10
		Bullet.FACTION_PLAYER:
			mmi.z_index = 5
		Bullet.FACTION_BOMB:
			mmi.z_index = 100
	add_child(mmi)

	var entry = {mmi = mmi, mm = mm, mesh = mesh}
	_groups[key] = entry
	return entry
