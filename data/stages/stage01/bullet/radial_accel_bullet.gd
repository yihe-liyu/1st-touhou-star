extends CoroutineScript
## 沿初始发射方向加速（径向扩散弹）
## 用法：挂到 BulletData.coroutine_script 上
## 首次 tick 记录子弹发射方向（初始速度方向 = 发射角度），此后沿该方向恒定加速

var accel_rate: float = 250.0  ## 加速度（px/s²），可用 param("accel_rate", v) 注入
var _dir := Vector2.ZERO       ## 发射方向（首次 tick 记录并固定）


func _tick(_ctx: StageContext) -> Variant:
	if not is_instance_valid(target) or not target is Bullet:
		return false
	var bullet: Bullet = target
	var dt := get_dt()
	if _dir == Vector2.ZERO:
		_dir = bullet.velocity.normalized()  # 初始速度方向 = 发射角度
	if _dir == Vector2.ZERO:
		return true  # 无初速子弹保持静止
	bullet.velocity += _dir * accel_rate * dt
	bullet.global_position += bullet.velocity * dt
	bullet.rotation = bullet.velocity.angle()
	return true
