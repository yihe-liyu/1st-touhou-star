extends CoroutineScript
## 红杂鱼:向下减速 + 自机狙散射

var target_y: float = 300
var bullet_speed: int = 400
var bullet_count: int = 3
var bullet_spread: float = 0.2
var shoot_interval: float = 0.8


## 被 EnemyService.spawn(key, pos, params) 调用
## params 可覆盖 {target_y, bullet_speed, bullet_count, ...}
func setup_custom(params: Dictionary) -> void:
	if params.has("target_y"): target_y = params.target_y
	if params.has("bullet_speed"): bullet_speed = params.bullet_speed
	if params.has("bullet_count"): bullet_count = params.bullet_count


## 延迟初始化（等父节点完成 add_child 链）
func _ready() -> void:
	call_deferred("_init_enemy")


func _init_enemy() -> void:
	var parent := get_parent()
	if not parent:
		return

	# 外观
	parent.add_child(AssetRegistry.enemy_visuals["s_red"].instantiate())

	# 移动:向下减速
	parent.create_tween().tween_property(parent, "global_position",
		Vector2(parent.global_position.x, target_y), 1.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# 弹幕
	var bullet: BulletData = BulletData.new().tex("小玉").color(Color.RED).enemy().blend(true)
	bullet.velocity = Vector2(0, bullet_speed)

	var tl := start_timeline()
	tl.at(0.0).every(shoot_interval).do(func():
		var p := ctx.player.get_player()
		if not p or not is_instance_valid(p): return
		var dir := (p.global_position - target.position).normalized()
		ctx.bullets.shoot_spread(bullet, bullet_count, bullet_spread, dir,
			target.global_position, AssetRegistry.sounds["shoot"])
	)
