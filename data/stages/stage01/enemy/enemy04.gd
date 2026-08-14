extends CoroutineScript

const RADIAL_ACCEL = preload("res://data/stages/stage01/bullet/radial_accel_bullet.gd")

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

	tl.at(2.0).every(4).times(2).do(func():
		bullet.tex("棱弹").color(Color.FUCHSIA)
		bullet.coroutine_script = RADIAL_ACCEL  # 沿各自发射角度加速扩散
		var dir = Vector2.ONE.rotated(RNG.randf_range(-PI, PI))
		for i in diff_pick([1, 1, 2, 2]):
			bullet.velocity = Vector2(0, 75 + i * 75)
			ctx.bullets.shoot_spread(bullet, diff_pick([15, 20, 20, 30]),
				TAU, dir,
				target.global_position, AssetRegistry.sounds["shoot"])
	)

	auto_stop = true


## 移动：匀速下移直到离开屏幕（弹幕 timeline 并行推进，发完后移动不中断）
func _tick(_ctx: StageContext) -> Variant:
	if target and is_instance_valid(target):
		target.global_position.y += move_speed * get_dt()
		# 离开屏幕（下缘 + 90px 宽限）：销毁
		if target.global_position.y > GameConfig.VIEW_HEIGHT + 32.0:
			target.queue_free()
			return false
	# 弹幕 timeline 照常推进（事件发完即停，但移动持续到出屏）
	if _tl:
		_tl.tick(get_dt())
	return true
