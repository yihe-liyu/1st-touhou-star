extends Node
## 基线测试：1500 颗无协程直线弹（纯 Bullet._physics_process）
func _ready():
	var data: BulletData = BulletData.new().enemy().tex("小玉").speed(20.0).blend(true)
	# 不设 coroutine_script → 直线弹路径
	for i in 1500:
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 1500.0)
		BulletManager.shoot_enemy_bullet(data, Vector2(448, 480), dir)
	print("[stress] 已生成 1500 颗无协程直线弹")
