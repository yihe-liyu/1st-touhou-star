extends BackgroundScript
class_name Stage01Decor
## 示例背景脚本 —— 挂在 stage01_background.tscn 里即可
## StageManager 自动发现并启动

# ── 节点引用（@onready ✅, 在 tscn 场景树里） ──
@onready var bg: StageBackground = $".."
@onready var ground: BackgroundPlane = $"../Ground"

# 贴图（在 Inspector 拖）
@export var tree_texture: Texture2D
@export var rock_texture: Texture2D

var _i: int = 0


func _on_step(api: StageAPI) -> Variant:
	# ── 阶段 0: 开场, 连续生装饰物 ──
	if _i < 30:
		# 树
		api.spawn_decor(
			_make_plane(Vector2(8, 8), tree_texture),
			Vector3(randf_range(-400, 400), 0, randf_range(-60, -30)),
			ground
		)
		# 石头 (散落)
		if _i % 3 == 0:
			api.spawn_decor(
				_make_plane(Vector2(3, 3), rock_texture),
				Vector3(randf_range(-400, 400), 0, randf_range(-50, -20)),
				ground
			)
		_i += 1
		return api.seconds(0.4)

	# ── 阶段 1: Boss 出场, 雾变暗 ──
	if _i == 30:
		_i += 1
		var env := bg.world_environment.environment
		var t := bg.create_tween().set_parallel(true)
		t.tween_property(env, "fog_light_color", Color(0.15, 0.05, 0.25), 2.0)
		t.tween_property(env, "fog_density", 0.06, 2.0)
		t.tween_property(bg.camera, "fov", 55.0, 2.0)
		return api.seconds(2.1)  # 等 tween 播完

	return false  # 结束


# ── 工具：用贴图造一个简单的 MeshInstance3D 包装成 PackedScene ──
func _make_plane(size: Vector2, tex: Texture2D) -> PackedScene:
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
