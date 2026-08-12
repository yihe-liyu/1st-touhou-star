extends CoroutineScript

const FLY_AWAY = preload("res://data/stages/stage01/enemy/fly_away.gd")

## 匀速下移速度（px/s），外部可用 param("move_speed", v) 覆盖
var move_speed: float = 120.0

## 延迟初始化（等父节点完成 add_child 链）
func _ready() -> void:
	call_deferred("_init_enemy")


func _init_enemy() -> void:
	var parent := get_parent()
	if not parent:
		return

	# 弹幕
	var bullet: BulletData = BulletData.new().enemy().blend(true)

	var tl := start_timeline()

	tl.at(1.0).every(2.4).times(3).do(func():
		bullet.tex("棱弹").color(Color.FUCHSIA)
		bullet.coroutine_script = null
		var dir = Vector2.ONE.rotated(RNG.randf_range(-PI, PI))
		for i in diff_pick([1, 1, 2, 2]):
			bullet.velocity = Vector2(0, 150 + i * 50)
			ctx.bullets.shoot_spread(bullet, diff_pick([10, 14, 20, 28]),
				TAU, dir,
				target.global_position, AssetRegistry.sounds["shoot"])
	)

	# 退场
	tl.at(8.0).do(func():
		var fly: CoroutineScript = FLY_AWAY.new()
		target.add_child(fly)
		fly.start(ctx, target)
		auto_stop = true
	)


## 移动：匀速下移（恒定速度，配合 timeline 边下边射；8s 后由退场飘走）
func _tick(_ctx: StageContext) -> Variant:
	if target and is_instance_valid(target):
		target.global_position.y += move_speed * get_dt()
	return super._tick(_ctx)
