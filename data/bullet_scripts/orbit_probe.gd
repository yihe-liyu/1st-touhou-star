extends CoroutineScript
## 往返探测弹 v2（匀减速滑行版）
## 青弹以初速发射，加速度恒为 -decel（沿初方向反向）：
##   减速滑行到停（最远点）→ 继续反向加速飞回 → 沿初方向位移过零（回到生成位置）
##   → 分裂 90° 红弹 → 自身消失
## 全程加速度方向不变，无需掉头/取反；往返由 decel 决定（v0/decel 秒内完成）
## auto_stop = true

var decel: float = 150.0     # 反向加速度（px/s²）：越大滑行越短、往返越快
var split_speed: float = 80.0    # 分裂红弹初速（慢，配合缓慢加速出屏）
var split_accel: float = 60.0    # 红弹加速度（缓慢加速）
var split_dir: float = 90.0      # 分裂方向：相对初方向旋转角度（度）

enum State { OUT, BACK }
var _state: int = State.OUT
var _dir0: Vector2 = Vector2.ZERO  # 发射初方向（首帧记录）
var _dist: float = 0.0             # 沿初方向累计位移（OUT 正增 / BACK 递减）


func _tick(p_ctx: StageContext):
	var bullet: Bullet = target
	if not bullet:
		return false
	var dt := get_dt()
	if _dir0 == Vector2.ZERO:
		_dir0 = bullet.velocity.normalized()
	# 加速度恒为反向（沿 -dir0）→ 减速滑行 → 停 → 反向加速飞回
	bullet.velocity -= _dir0 * decel * dt
	_dist += bullet.velocity.dot(_dir0) * dt
	match _state:
		State.OUT:
			if bullet.velocity.dot(_dir0) <= 0.0:
				_state = State.BACK  # 减速到停，开始飞回
		State.BACK:
			if _dist <= 1.0:  # 位移过零 = 回到生成位置附近
				_spawn_split(p_ctx)
				BulletManager.return_bullet(bullet)
				return false
	bullet.global_position += bullet.velocity * dt
	return true


## 分裂：90° 红弹，低速 + 缓慢加速（出屏后引擎自动回收）
func _spawn_split(p_ctx: StageContext) -> void:
	var dir := _dir0.rotated(deg_to_rad(split_dir))
	var red := BulletData.new() \
		.tex("棱弹") \
		.speed(split_speed) \
		.accelerate(dir.x * split_accel, dir.y * split_accel) \
		.color(Color(1.0, 0.30, 0.25, 1.0)) \
		.blend(true) \
		.enemy()
	p_ctx.bullets.shoot_spread(red, 1, 0, dir, target.global_position, AssetRegistry.sounds["kira"])
