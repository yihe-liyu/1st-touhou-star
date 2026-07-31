extends PlayerShootScript
class_name MarisaShoot

const OPTION_VISUAL = preload("res://scripts/coroutine/player/ov_marisa.gd")
const LASER_FOLLOW = preload("res://scripts/coroutine/player/marisa_laser_follow.gd")
const LASER_TEX = preload("res://assets/Textures/player/marisa_option_bullet1.png")

const MAIN_INTERVAL: int = 3
const OPTION_INTERVAL: int = 6

## 非 focus 分段激光参数
const SEG_W: int = 32                    # 每段宽度（原图 512x32 切成 16 段）
const SEGMENTS: int = 16               # 段数（512 宽 / 32 段宽）
const LASER_DAMAGE: int = 1              # 每段伤害（每段独立判定，命中即回收）
const LASER_DRIFT_SPEED: float = 1000.0   # 激光整体向上漂移速度（px/s）
const LASER_GROW_FRAMES: int = 2          # 每多少帧长出一段（生长动画速度）

var _laser_index: int = 0                 # 当前生长到第几段
var _last_laser_seg: Node = null          # 上一段（继承漂移用）


func _option_setup() -> Dictionary:
	return {
		visual_script = OPTION_VISUAL,
		power_thresholds = [0, 100, 200, 300],
		counts = [1, 2, 3, 4],
		offsets_focus = [
			[Vector2(0, -40)],
			[Vector2(-10, -40), Vector2(10, -40)],
			[Vector2(-20, -30), Vector2(0, -40), Vector2(20, -30)],
			[Vector2(-30, -30), Vector2(-10, -40), Vector2(10, -40), Vector2(30, -30)],
		],
		offsets_spread = [
			[Vector2(0, -80)],
			[Vector2(-40, -80), Vector2(40, -80)],
			[Vector2(-40, -60), Vector2(0, -80), Vector2(40, -60)],
			[Vector2(-60, -60), Vector2(-20, -80), Vector2(20, -80), Vector2(60, -60)],
		],
	}


func _main_shoot(_ctx: StageContext, player: Player) -> float:
	var b := BulletData.new().tex("marisa_main").speed(4000).player()
	b.color(Color(1, 1, 1, 0.5))
	b.damage = 6
	b.hit_effect = preload("res://scenes/effect/hit_effect_marisa.tscn")
	ctx.bullets.shoot_spread(b, 1, 0.0, Vector2.UP, player.global_position + Vector2(-15, 0))
	ctx.bullets.shoot_spread(b, 1, 0.0, Vector2.UP, player.global_position + Vector2(15, 0))
	return ctx.clock.wait_frames(MAIN_INTERVAL)


func _option_shoot(_ctx: StageContext, _count: int) -> float:
	if Input.is_action_pressed("focus"):
		# focus：高速直线星弹（集中火力）
		var b := BulletData.new().tex("marisa_option_bullet1").speed(5000).player()
		b.color(Color(1, 1, 1, 0.5))
		b.damage = 2
		b.hit_effect = preload("res://scenes/effect/hit_effect_marisa.tscn")
		_shoot_options(ctx, b, 1, 0.0, Vector2.UP, Vector2.ZERO)
		return ctx.clock.wait_frames(4)
	else:
		# 非 focus：分段激光（逐段生长 + 继承漂移 → 始终无缝）
		var player: Player = ctx.player.get_player()
		if not is_instance_valid(player):
			return ctx.clock.wait_frames(OPTION_INTERVAL)
		_grow_laser_segment(player)
		return ctx.clock.wait_frames(LASER_GROW_FRAMES)


## 把长贴图切成第 i 段（AtlasTexture 切片）
func _make_laser_segment(i: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = LASER_TEX
	at.region = Rect2(i * SEG_W, 0, SEG_W, 32)
	return at


## 生长一段激光：新段继承上一段已漂移量 → 无缝衔接
func _grow_laser_segment(player: Player) -> void:
	# 上一段已消失（命中/出屏）→ 从头开始生长
	if _last_laser_seg == null or not is_instance_valid(_last_laser_seg):
		_laser_index = 0

	var i: int = _laser_index
	if i >= SEGMENTS:
		# 一轮长满，从头再来（新一轮激光）
		_laser_index = 0
		i = 0
		_last_laser_seg = null

	# 继承上一段的漂移量（若上一段还在），保证新段贴住上一段上方
	var inherit_drift: float = 0.0
	if _last_laser_seg != null and is_instance_valid(_last_laser_seg):
		var ex: Variant = _last_laser_seg.get("extra")
		if ex is Dictionary:
			inherit_drift = ex.get("drift", 0.0)

	var seg := _make_laser_segment(i)
	var b := BulletData.new().player()
	b.texture = seg
	b.damage = LASER_DAMAGE
	b.hit_effect = preload("res://scenes/effect/hit_effect_marisa.tscn")
	# 矩形判定覆盖整段（32x32），保证激光无空隙
	b.hitbox_shape = BulletData.HitboxShape.RECTANGLE
	b.hitbox_size = Vector2(SEG_W, SEG_W)
	b.coroutine_script = LASER_FOLLOW

	var base: Vector2 = player.global_position
	var offset := Vector2(0, -i * SEG_W)
	var bullet := ctx.bullets.shoot_single(b, base + offset, Vector2.UP)
	if bullet:
		bullet.extra["laser_offset"] = offset
		bullet.extra["drift_speed"] = LASER_DRIFT_SPEED
		bullet.extra["drift_offset"] = inherit_drift  # 继承漂移 → 无缝
		_last_laser_seg = bullet

	_laser_index += 1
