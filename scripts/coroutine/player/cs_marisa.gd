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
const LASER_GROW_FRAMES: int = 2          # 每多少帧喷出一段（喷射频率）

var _laser_index: int = 0                 # 喷出的段序号（贴图按 %SEGMENTS 循环）
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
		# 非 focus：固定长度流水激光（16 段从子机向上延伸，根部永不飞走）
		if _laser_index >= SEGMENTS:
			return ctx.clock.wait_frames(OPTION_INTERVAL)  # 已满，保持
		var player: Player = ctx.player.get_player()
		if not is_instance_valid(player):
			return ctx.clock.wait_frames(OPTION_INTERVAL)
		_spawn_laser_segment(player, _laser_index)
		_laser_index += 1
		return ctx.clock.wait_frames(LASER_GROW_FRAMES)


## 把长贴图切成第 i 段（AtlasTexture 切片）
func _make_laser_segment(i: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = LASER_TEX
	at.region = Rect2(i * SEG_W, 0, SEG_W, 32)
	return at


## 在固定槽位生成一段激光（offset = 子机上方 -i*32，根部永远在子机）
func _spawn_laser_segment(player: Player, i: int) -> void:
	# 发射口 = 第一个子机（无子机时回退自机）
	var source: Node2D = _options[0] if _options.size() > 0 else player
	if not is_instance_valid(source):
		source = player

	var seg := _make_laser_segment(i)
	var b := BulletData.new().player()
	b.texture = seg
	b.damage = LASER_DAMAGE
	b.hit_effect = preload("res://scenes/effect/hit_effect_marisa.tscn")
	# 矩形判定覆盖整段（32x32），保证激光无空隙
	b.hitbox_shape = BulletData.HitboxShape.RECTANGLE
	b.hitbox_size = Vector2(SEG_W, SEG_W)
	b.coroutine_script = LASER_FOLLOW

	var offset := Vector2(0, -i * SEG_W)
	var bullet := ctx.bullets.shoot_single(b, source.global_position + offset, Vector2.UP)
	if bullet:
		bullet.extra["anchor_node"] = source    # 锚定发射口（根部在子机）
		bullet.extra["laser_offset"] = offset    # 固定槽位偏移
		bullet.extra["segment_index"] = i        # 贴图滚动基准
		_last_laser_seg = bullet

	_laser_index = max(_laser_index, i + 1)
