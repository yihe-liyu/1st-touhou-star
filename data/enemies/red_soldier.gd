extends EnemyScript
## 红杂鱼:向下减速 + 自机狙散射

var target_y: float = 300
var bullet_speed: int = 400
var bullet_count: int = 3
var bullet_spread: float = 0.2
var shoot_interval: float = 0.8

func setup(_enemy: Enemy, _ctx: StageContext) -> void:
	super(_enemy, _ctx)

	# 外观
	enemy.add_child(AssetRegistry.enemy_visuals["s_red"].instantiate())

	# 移动:向下减速
	enemy.create_tween().tween_property(enemy, "global_position",
		Vector2(enemy.global_position.x, target_y), 1.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# 弹幕
	var bullet: BulletData = BulletData.new().tex("小玉").color(Color.RED).enemy().blend(true)
	bullet.velocity = Vector2(0, bullet_speed)

	var tl := start_timeline()
	tl.at(0.0).every(shoot_interval).do(func():
		var p := ctx.player.get_player()
		if not p or not is_instance_valid(p): return
		var dir := (p.global_position - enemy.global_position).normalized()
		ctx.bullets.shoot_spread(bullet, bullet_count, bullet_spread, dir,
			enemy.global_position, AssetRegistry.sounds["shoot"])
	)

	start()
