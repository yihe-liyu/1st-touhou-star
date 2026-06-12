extends BackgroundScript
class_name Stage01Decor


# ═══════════════════════════════════════════
# 节点引用
# ═══════════════════════════════════════════

@onready var bg: StageBackground = $".."
@onready var ground: BackgroundPlane = $"../Ground"


# ═══════════════════════════════════════════
# Inspector 配置
# ═══════════════════════════════════════════

@export var tree_tex: Texture2D
@export var rock_tex: Texture2D
@export var pillar_tex: Texture2D
@export var grass_tex: Texture2D


# ═══════════════════════════════════════════
# 内部状态
# ═══════════════════════════════════════════

var _t: int = 0   # 总步数 (≈ 帧数, 因为 stage API 按帧推进)


# ═══════════════════════════════════════════
# 协程入口
# ═══════════════════════════════════════════

func _on_step(api: StageAPI) -> Variant:
	_t += 1

	# ── 开头: 黑雾弥漫, 什么都看不见 ──
	if _t == 1:
		var env := bg.world_environment.environment
		env.fog_light_color = Color.BLACK
		env.fog_density = 0.15
		bg.camera.fov = 55.0

		# 黑雾里先生成背景树和石头, 雾散时已经在那儿了
		for i in range(20):
			_spawn(api, tree_tex, Vector2(8, 8), 4.0, -400, 400, -260, -30)
		_spawn_cluster(api, rock_tex, Vector2(2.5, 2.5), 2.5, 0, -40, 120)
		_spawn_cluster(api, rock_tex, Vector2(2.5, 2.5), 2.5, -300, -50, 80)
		_spawn_cluster(api, rock_tex, Vector2(2.5, 2.5), 2.5, 250, -45, 100)

		return api.frames(1)

	# ── 渐渐化开 (1s~6s) ──
	if _t == 30:
		_fog_to(Color(0.08, 0.06, 0.10), 0.10, 58.0, 1.5)
		return api.frames(1)
	if _t == 75:
		_fog_to(Color(0.18, 0.15, 0.20), 0.05, 62.0, 1.5)
		return api.frames(1)
	if _t == 120:
		_fog_to(Color(0.30, 0.30, 0.30), 0.01, 68.0, 1.5)
		return api.frames(1)

	# ── 地面装饰物阶段 (5s~30s) ──
	if _t >= 150 and _t < 900:

		# 树 (稀疏, 每 1s — 开头已有 20 棵)
		if _t % 30 == 0:
			_spawn(api, tree_tex, Vector2(8, 8), 4.0, -400, 400, -260, -30)

		# 柱子 (稀疏, 每 1.5s)
		if _t % 45 == 0:
			_spawn(api, pillar_tex, Vector2(3, 10), 5.0, -350, 350, -250, -25)

		# 石头 (每 0.6s)
		if _t % 18 == 0:
			_spawn(api, rock_tex, Vector2(2.5, 2.5), 2.5, -400, 400, -255, -25)

		# 草丛 (密集, 每 0.15s, 只在地面边缘)
		if _t % 5 == 0:
			var side = 1 if _t % 10 < 5 else -1   # 左右交替
			api.spawn_decor(
				_make(grass_tex, Vector2(1.5, 1.5)),
				Vector3(side * randf_range(300, 400), 1.5, randf_range(-255, -235)),
				ground
			)

		return api.frames(1)


	# ── 雾压回 (30s~35s): Boss 逼近 ──
	if _t == 900:
		_fog_to(Color(0.12, 0.04, 0.20), 0.08, 55.0, 5.0)
		return api.frames(1)

	if _t == 1050:
		return false  # 结束

	return api.frames(1)


# ═══════════════════════════════════════════
# 内部辅助
# ═══════════════════════════════════════════

func _spawn(api: StageAPI, tex: Texture2D, size: Vector2, y: float, x_min: float, x_max: float, z_min: float, z_max: float):
	api.spawn_decor(
		_make(tex, size),
		Vector3(randf_range(x_min, x_max), y, randf_range(z_min, z_max)),
		ground
	)

func _spawn_cluster(api: StageAPI, tex: Texture2D, size: Vector2, y: float, center_x: float, center_z: float, spread: float):
	for i in range(6):
		api.spawn_decor(
			_make(tex, size),
			Vector3(center_x + randf_range(-spread, spread), y, center_z + randf_range(-spread * 0.5, spread * 0.5)),
			ground
		)

func _fog_to(color: Color, density: float, fov: float, sec: float):
	var env := bg.world_environment.environment
	var t := bg.create_tween().set_parallel(true)
	t.tween_property(env, "fog_light_color", color, sec)
	t.tween_property(env, "fog_density", density, sec)
	t.tween_property(bg.camera, "fov", fov, sec)

func _make(tex: Texture2D, size: Vector2) -> PackedScene:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.orientation = PlaneMesh.FACE_Z
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.material = mat
	mi.mesh = pm
	var ps := PackedScene.new()
	ps.pack(mi)
	return ps
