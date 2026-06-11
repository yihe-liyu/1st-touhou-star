extends BackgroundScript
class_name Stage01Decor
## 示例：Stage 1 背景装饰物脚本
##
## 使用方法：
##   1. 在 stage01_background.tscn 里新建一个空 Node 节点
##   2. 挂上这个脚本
##   3. 在 Inspector 拖入 tree_texture 和 rock_texture 贴图
##   4. 运行 —— 自动生成装饰物 + Boss 出场变暗
##
## 原理：
##   - 本脚本挂在背景场景 (StageBackground) 的子节点上
##   - StageManager.load_stage() 自动发现所有 BackgroundScript 并调用 start_background()
##   - 每次 _on_step(api) 被调用, 返回 api.seconds(N) 表示 N 秒后再调
##   - 与关卡脚本 (StageScript) 并行运行, 互不阻塞
##
## 协程约定（详见 CoroutineRunner）：
##   return api.seconds(N)  → 等待 N 秒后再次调用 _on_step
##   return api.frames(N)   → 等待 N 帧后再次调用
##   return true            → 下一帧立即再次调用
##   return false / null    → 协程结束, 不再调用


# ═══════════════════════════════════════════
# 节点引用
# ═══════════════════════════════════════════

## 背景场景根节点 (StageBackground)
## 通过它访问 camera (Camera3D) 和 world_environment (雾/环境光)
## $".." = 上一级节点 = StageBackground
@onready var bg: StageBackground = $".."

## 地面 BackgroundPlane
## 装饰物通过 follow = ground 绑定到地面, 自动同步滚动速度
## $"../Ground" = 兄弟节点 Ground
@onready var ground: BackgroundPlane = $"../Ground"


# ═══════════════════════════════════════════
# Inspector 配置
# ═══════════════════════════════════════════

## 树的贴图 (带 Alpha 通道的 PNG)
@export var tree_texture: Texture2D

## 石头贴图
@export var rock_texture: Texture2D


# ═══════════════════════════════════════════
# 内部状态
# ═══════════════════════════════════════════

## 当前步数 — 控制阶段切换
## 0~29  → 阶段 0: 生成装饰物
## 30    → 阶段 1: Boss 出场雾变暗
## 31    → 结束
var _i: int = 0


# ═══════════════════════════════════════════
# 协程入口
# ═══════════════════════════════════════════

func _on_step(api: StageAPI) -> Variant:

	# ─── 阶段 0: 生成装饰物 (0~29 步, 共约 12 秒) ───
	if _i < 60:
		# 树 —— 每步生成一棵, 绑定地面
		api.spawn_decor(
			_make_billboard(Vector2(8, 8), tree_texture),
			# 随机位置: X ±400, Z -30~ -60 (地面区)
			Vector3(randf_range(-400, 400), 4, randf_range(-60, -30)),
			ground   # ← 跟地面同步滚动
		)

		# 石头 —— 每 3 步散落一块 (比树稀疏)
		if _i % 3 == 0:
			api.spawn_decor(
				_make_billboard(Vector2(3, 3), rock_texture),
				Vector3(randf_range(-400, 400), 4, randf_range(-50, -20)),
				ground
			)

		_i += 1
		return api.seconds(0.2)    # 0.2 秒后生成下一棵


	# ─── 阶段 1: Boss 出场 (第 30 步) ───
	# 雾变暗紫 + 密度上升 + 相机收窄 FOV
	if _i == 60:
		_i += 1

		# 拿 Environment 对象 —— 雾的所有属性都在这里
		var env := bg.world_environment.environment

		# parallel tween: 三个属性同时渐变, 持续 2 秒
		var t := bg.create_tween().set_parallel(true)

		# 雾颜色: 灰白 → 暗紫
		t.tween_property(env, "fog_light_color", Color(0.15, 0.05, 0.25), 2.0)
		# 雾密度: 0 → 0.06 (远处逐渐看不清)
		t.tween_property(env, "fog_density", 0.06, 2.0)
		# 相机 FOV: 70 → 55 (微微推近, 增加压迫感)
		t.tween_property(bg.camera, "fov", 55.0, 2.0)

		# 等 2.1 秒确保 tween 播完
		return api.seconds(2.1)


	# ─── 结束 ───
	return false


# ═══════════════════════════════════════════
# 工具方法
# ═══════════════════════════════════════════

## 用贴图快速造一个 Billboard (始终面朝相机的平面)
##
## 实际项目应该预建 .tscn 场景文件, 这里只是为了示例方便.
##
## @param size   平面宽高 (世界单位)
## @param tex    贴图 (建议带 Alpha)
## @return       可传给 api.spawn_decor() 的 PackedScene
func _make_billboard(size: Vector2, tex: Texture2D) -> PackedScene:
	var mi := MeshInstance3D.new()

	# PlaneMesh — 默认 FACE_Z (平放地面)
	var pm := PlaneMesh.new()
	pm.size = size
	pm.orientation = PlaneMesh.FACE_Z
	mi.mesh = pm

	# StandardMaterial3D — 不参与光照, 带 Alpha 通道
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.material = mat

	# 打包成 PackedScene — api.spawn_decor() 需要这个类型
	var ps := PackedScene.new()
	ps.pack(mi)
	return ps
