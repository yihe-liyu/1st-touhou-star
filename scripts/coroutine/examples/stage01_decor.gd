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

# ═══════════════════════════════════════════
# 内部状态
# ═══════════════════════════════════════════

var _t: int = 0   # 总步数 (≈ 帧数, 因为 stage API 按帧推进)


# ═══════════════════════════════════════════
# 协程入口
# ═══════════════════════════════════════════

# ═══════════════════════════════════════════
# 初始化 — 场景 _ready 阶段调用, 渲染之前
# ═══════════════════════════════════════════

func _on_init(api: StageAPI) -> void:
	if bg.world_environment:
		var env := bg.world_environment.environment
		env.fog_light_color = Color.BLACK
		env.fog_density = 0.5
	if bg.camera:
		bg.camera.fov = 55.0

	# 黑雾里预生成树和石头, 雾散时已经在场
	for i in range(80):
		var x = randf_range(-50, 50)
		var z = randf_range(-180, 20)
		_spawn(api, tree_tex, Vector2(8, 8), 4.0, x, z)


# ═══════════════════════════════════════════
# 协程入口
# ═══════════════════════════════════════════

func _on_step(api: StageAPI) -> Variant:
	_t += 1

	# ── 开头：黑雾已由 _on_init 设好, 从这里开始渐渐化开 ──
	# ── 雾化开: 相机升高 + 慢旋 ──
	if _t == 2:
		bg.pan_camera(Vector3(0, 5, -3), 6.0, Tween.EASE_IN_OUT, Tween.TRANS_CUBIC)
		bg.rotate_camera(Vector3(deg_to_rad(-22), 0, deg_to_rad(6)), 6.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
		return api.frames(1)

	if _t == 30:
		_fog_to(Color(0.08, 0.06, 0.10), 0.10, 58.0, 1.5)
		return api.frames(1)
	if _t == 75:
		_fog_to(Color(0.18, 0.15, 0.20), 0.05, 62.0, 1.5)
		return api.frames(1)
	if _t == 120:
		_fog_to(Color(0.28, 0.28, 0.32), 0.025, 68.0, 1.5)
		return api.frames(1)

	if _t % 3 == 0:
		var x = randf_range(-70, 70)
		var z = randf_range(-220, -180)
		_spawn(api, tree_tex, Vector2(8, 8), 4.0, x, z)

	# ── 雾压回 (30s~35s): Boss 逼近 ──
	if _t == 900:
		# Boss 压紫：雾+后处理+旋转 同时起
		var t0 := bg.create_tween().set_parallel(true)
		t0.tween_property(bg.world_environment.environment, "fog_light_color", Color(0.25, 0.10, 0.35), 5.0)
		t0.tween_property(bg.world_environment.environment, "fog_density", 0.10, 5.0)
		bg.tween_post_processing(0.80, 1.0, 0.7, 3.0, Tween.EASE_IN, Tween.TRANS_QUAD)
		bg.rotate_camera(Vector3(deg_to_rad(-35), 0, deg_to_rad(-5)), 3.0, Tween.EASE_IN_OUT, Tween.TRANS_CUBIC)
		# FOV 先缩后冲 + 地面加速 → 冲刺感
		var t_fov := bg.create_tween()
		t_fov.tween_property(bg.camera, "fov", 55.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
		t_fov.tween_property(bg.camera, "fov", 75.0, 3.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		var t_accel := bg.create_tween()
		t_accel.tween_method(_camera_accel, 1.0, 6.0, 4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		return api.frames(1)

	#if _t == 1050:
		#return false  # 结束

	return api.frames(1)


# ═══════════════════════════════════════════
# 内部辅助
# ═══════════════════════════════════════════

func _spawn(api: StageAPI, tex: Texture2D, size: Vector2, y: float, x: float, z: float):
	api.spawn_decor(
		_make(tex, size),
		Vector3(x, y, z),
		ground
	)

func _spawn_cluster(api: StageAPI, tex: Texture2D, size: Vector2, y: float, center_x: float, center_z: float, spread: float):
	for i in range(6):
		api.spawn_decor(
			_make(tex, size),
			Vector3(center_x + randf_range(-spread, spread), y, center_z + randf_range(-spread * 0.5, spread * 0.5)),
			ground
		)

func _camera_accel(mult: float):
	ground.scroll_speed = Vector2(0, -0.1 * mult)

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
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.material = mat
	mi.mesh = pm
	var ps := PackedScene.new()
	ps.pack(mi)
	return ps
