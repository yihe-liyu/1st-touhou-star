extends CoroutineScript
## 沿初始发射方向加速（径向扩散弹）
## 用法：挂到 BulletData.coroutine_script 上
## 首次 tick 记录子弹发射方向（初始速度方向 = 发射角度），此后沿该方向恒定加速

var accel_rate: float = 150.0  ## 加速度（px/s²），可用 param("accel_rate", v) 注入
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
	# 击中上版边：删除自己 + 生成竖直向下匀速弹（保留速度大小）
	if bullet.global_position.y <= GameConfig.FIELD_TOP:
		_spawn_downward(bullet, _ctx)
		return false
	bullet.velocity += _dir * accel_rate * dt
	bullet.global_position += bullet.velocity * dt
	bullet.rotation = bullet.velocity.angle()
	return true


## 生成竖直向下匀速弹（保留速度大小与外观），回收自己
func _spawn_downward(bullet: Bullet, _ctx: StageContext) -> void:
	var speed := bullet.velocity.length()
	var data := BulletData.new()
	data.faction = BulletData.Faction.ENEMY
	data.texture = bullet.sprite.texture
	data.tint = bullet.sprite.modulate
	data.tint_mode = bullet.tint_mode as BulletData.TintMode
	data.damage = bullet.damage
	data.hitbox_shape = bullet.hitbox_shape as BulletData.HitboxShape
	data.hitbox_radius = bullet.hitbox_radius
	data.hitbox_size = bullet.hitbox_size
	data.velocity = Vector2(0, speed)  # 保留速度大小，方向竖直向下
	data.accel = Vector2.ZERO          # 匀速（无加速度）
	data.coroutine_script = null       # 纯直线弹（bullet 自身移动）
	_ctx.bullets.shoot_single(data, Vector2(bullet.global_position.x, GameConfig.FIELD_TOP), Vector2.DOWN)
	BulletManager.return_bullet(bullet)
