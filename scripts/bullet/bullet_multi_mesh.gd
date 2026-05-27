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
		if not is_instance_valid(bullet) or not bullet.visible:
			continue
		var tex = bullet.batch_texture()
		if not tex:
			continue
		var key = tex.resource_path + "|" + str(bullet.faction)
		if not active_groups.has(key):
			active_groups[key] = {tex = tex, faction = bullet.faction, bullets = []}
		active_groups[key].bullets.append(bullet)

	# 更新每个分组的 MultiMesh
	for key in active_groups:
		var g = active_groups[key]
		var bullets: Array = g.bullets
		var eg = _get_or_create_group(key, g.tex, g.faction, bullets.size())

		var mm: MultiMesh = eg.mm
		mm.instance_count = bullets.size()
		eg.mmi.visible = true

		for i in bullets.size():
			var b = bullets[i]
			var t = Transform2D(b.rotation, b.scale, 0.0, b.global_position)
			mm.set_instance_transform_2d(i, t)

	# 隐藏没有在用的分组
	for key in _groups:
		if not active_groups.has(key):
			_groups[key].mmi.visible = false
			_groups[key].mm.instance_count = 0

func _get_or_create_group(key: String, tex: Texture2D, faction: int, min_size: int) -> Dictionary:
	if _groups.has(key):
		var entry = _groups[key]
		if entry.mm.instance_count < min_size:
			entry.mm.instance_count = min_size
		return entry

	# ── 把 AtlasTexture 解析为独立纹理 ──
	var use_tex = tex
	var use_region := Vector4(0.0, 0.0, 1.0, 1.0)
	if tex is AtlasTexture:
		var atex = tex as AtlasTexture
		# 方法1：直接裁剪出独立纹理（最可靠）
		var src_image = atex.atlas.get_image()
		if src_image:
			var region_image = src_image.get_region(atex.region)
			use_tex = ImageTexture.create_from_image(region_image)
		else:
			# 方法2：传给 shader 自己算 UV 偏移
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
	mm.use_colors = false
	mm.instance_count = max(min_size, 64)

	# ── 创建 2D 四边形网格 ──
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal = Vector3(0, 0, 1)
	st.set_normal(normal)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-0.5, -0.5, 0))
	st.set_normal(normal)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(Vector3(0.5, -0.5, 0))
	st.set_normal(normal)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(Vector3(0.5, 0.5, 0))
	st.set_normal(normal)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-0.5, -0.5, 0))
	st.set_normal(normal)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(Vector3(0.5, 0.5, 0))
	st.set_normal(normal)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(Vector3(-0.5, 0.5, 0))
	var mesh = st.commit()

	# ── CanvasItem shader 材质 ──
	var shader = Shader.new()
	# 是否需要 region 偏移？
	var need_region = (use_region != Vector4(0.0, 0.0, 1.0, 1.0))

	var shader_code = """
shader_type canvas_item;
uniform sampler2D tex;
"""
	if need_region:
		shader_code += "uniform vec4 region;\n"
	shader_code += """
void fragment() {
	vec2 uv = UV;
"""
	if need_region:
		shader_code += "\tuv = region.xy + UV * region.zw;\n"
	shader_code += "\tCOLOR = texture(tex, uv);\n}\n"

	var shader = Shader.new()
	shader.code = shader_code
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tex", use_tex)
	if need_region:
		mat.set_shader_parameter("region", use_region)
	mesh.material = mat
	mm.mesh = mesh

	# ── MultiMeshInstance2D ──
	var mmi = MultiMeshInstance2D.new()
	mmi.multimesh = mm
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
