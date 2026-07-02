extends CoroutineScript
## 子弹竖直向下加速：每帧 velocity.y += gravity * dt
## 用法：挂到 BulletData.coroutine_script 上

var gravity: float = 200.0

func _tick(_ctx: StageContext) -> Variant:
	if not is_instance_valid(target) or not target is Bullet:
		return false
	var bullet: Bullet = target
	var dt := get_physics_process_delta_time()
	bullet.velocity.y += gravity * dt
	bullet.global_position += bullet.velocity * dt
	bullet.rotation = bullet.velocity.angle()
	return true
