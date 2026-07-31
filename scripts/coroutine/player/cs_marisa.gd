extends PlayerShootScript
class_name MarisaShoot

const OPTION_VISUAL = preload("res://scripts/coroutine/player/ov_marisa.gd")
const LASER_FOLLOW = preload("res://scripts/coroutine/player/marisa_laser_follow.gd")
const LASER_TEX = preload("res://assets/Textures/player/marisa_option_bullet1.png")

const MAIN_INTERVAL: int = 3
const OPTION_INTERVAL: int = 6

## 非 focus 分段激光参数
const SEG_W: int = 32                    # 每段宽度（原图 512x32 切成 16 段）
const SEGMENTS: int = 512 / SEG_W        # 段数 = 16
const LASER_DAMAGE: int = 2              # 每段伤害（每段独立判定，命中即回收）


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
		# 非 focus：分段激光（锚定自机，段间无缝）
		var player: Player = ctx.player.get_player()
		if not is_instance_valid(player):
			return ctx.clock.wait_frames(OPTION_INTERVAL)
		for i in SEGMENTS:
			var seg := _make_laser_segment(i)
			var b := BulletData.new().player()
			b.texture = seg
			b.damage = LASER_DAMAGE
			b.hit_effect = preload("res://scenes/effect/hit_effect_marisa.tscn")
			# 矩形判定覆盖整段（32x32），保证激光无空隙
			b.hitbox_shape = BulletData.HitboxShape.RECTANGLE
			b.hitbox_size = Vector2(SEG_W, SEG_W)
			b.coroutine_script = LASER_FOLLOW
			# 以自机为锚点叠段（与跟随协程的锚点一致，避免第一帧跳变）
			var base: Vector2 = player.global_position
			var offset := Vector2(0, -i * SEG_W)
			var bullet := ctx.bullets.shoot_single(b, base + offset, Vector2.UP)
			if bullet:
				bullet.extra["laser_offset"] = offset
		return ctx.clock.wait_frames(OPTION_INTERVAL)


## 把长贴图切成第 i 段（AtlasTexture 切片）
func _make_laser_segment(i: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = LASER_TEX
	at.region = Rect2(i * SEG_W, 0, SEG_W, 32)
	return at
