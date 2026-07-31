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
const LASER_DAMAGE: float = 1.0           # 每段伤害（支持小数，累积到整才扣血）
const LASER_DRIFT_SPEED: float = 2000.0    # 激光流动速度（px/s）
const LASER_SPACING_OVERLAP: float = 0.6   # 段间距 = 段宽 × 0.6（轻微重叠→视觉密实）
## 频率自动跟随速度：每漂移一个间距喷一段，任何速度都无缝

var _laser_index: int = 0                 # 喷出的段序号（贴图按 %SEGMENTS 循环）
var _spawn_accumulator: float = 0.0       # 漂移累积量（达到间距即喷一段）


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
		# 非 focus：流水激光（按间距喷段，频率自动跟随漂移速度 → 任何速度都无缝）
		var player: Player = ctx.player.get_player()
		if not is_instance_valid(player):
			return ctx.clock.wait_frames(OPTION_INTERVAL)
		var dt := 1.0 / Engine.physics_ticks_per_second
		_spawn_accumulator += LASER_DRIFT_SPEED * dt
		var spacing: float = SEG_W * LASER_SPACING_OVERLAP
		while _spawn_accumulator >= spacing:
			_spawn_accumulator -= spacing
			# 每个子机各喷一段（多道激光，各自锚定自己的子机）
			if _options.size() > 0:
				for opt in _options:
					_spawn_laser_segment(player, opt)
			else:
				_spawn_laser_segment(player, null)
		# 临时调试：每秒打印一次场上段数
		if Engine.get_physics_frames() % 60 == 0:
			print("[Laser] total_bullets=%d options=%d" % [BulletManager.active_bullets.size(), _options.size()])
		return dt  # 每帧都调用，驱动累积


## 把长贴图切成第 i 段（AtlasTexture 切片）
func _make_laser_segment(i: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = LASER_TEX
	at.region = Rect2(i * SEG_W, 0, SEG_W, 32)
	return at


## 从指定子机喷出一段激光：段在发射口生成，向上漂移，间距=漂移×间隔（自动无缝）
func _spawn_laser_segment(player: Player, source: Node2D) -> void:
	# 发射口 = 指定子机（无效时回退自机）
	if source == null or not is_instance_valid(source):
		source = player

	var seg := _make_laser_segment(_laser_index % SEGMENTS)  # 贴图循环
	var b := BulletData.new().player()
	b.texture = seg
	b.damage = LASER_DAMAGE
	b.hit_effect = preload("res://scenes/effect/hit_effect_marisa.tscn")
	# 矩形判定覆盖整段（32x32）
	b.hitbox_shape = BulletData.HitboxShape.RECTANGLE
	b.hitbox_size = Vector2(SEG_W, SEG_W)
	b.coroutine_script = LASER_FOLLOW

	# 段在发射口生成（offset=0），drift 从 0 独立累积 → 根部永远在子机
	var bullet := ctx.bullets.shoot_single(b, source.global_position, Vector2.UP)
	if bullet:
		bullet.rotation = -PI / 2.0  # 横向切片竖过来（原图 512x32 横向 → 竖直激光）
		bullet.extra["anchor_node"] = source
		bullet.extra["laser_offset"] = Vector2.ZERO
		bullet.extra["drift_speed"] = LASER_DRIFT_SPEED

	_laser_index += 1
