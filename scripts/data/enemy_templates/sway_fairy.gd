extends CoroutineScript
## 敌人模板参考 —— 整体脚本路线
##
## 移动和弹幕都在脚本里（工作台只做：选模板 + 调参数 + 看效果）。
## var 即工作台参数（反射自动暴露，改参 → 应用 → 从该处续跑）：
##   target_y       飞入深度（像素）
##   sway           水平摆荡幅度（像素）
##   bullet_n       自机狙散射弹数
##   fire_interval  发射间隔（秒）
##
## 复制本文件改名字/逻辑 = 新敌人，注册进 EnemyTemplateRegistry 即出现在工作台。

var target_y: float = 260.0
var sway: float = 80.0
var bullet_n: int = 5
var fire_interval: float = 0.6


## 延迟初始化（等父节点完成 add_child 链）
func _ready() -> void:
	call_deferred("_init_enemy")


func _init_enemy() -> void:
	var parent := get_parent()
	if not parent:
		return
	# ── 移动：飞入 + 水平摆荡（tween，随物理帧）──
	var tween := parent.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(parent, "global_position:y", target_y, 1.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(parent, "global_position:x", parent.global_position.x + sway, 1.2) \
		.set_trans(Tween.TRANS_SINE)
	tween.set_loops()  # 整条 tween 循环（摆荡往复）
	# ── 弹幕：自机狙散射（脚本内写，自由度全开）──
	var tl := start_timeline()
	tl.at(0.0).every(fire_interval).do(func():
		var bullet := BulletData.new() \
			.tex("小玉").speed(320).color(Color(0.4, 0.7, 1.0)).blend(true).enemy()
		var player := ctx.player.get_player()
		var dir := Vector2.DOWN
		if is_instance_valid(player):
			dir = (player.global_position - target.position).normalized()
		ctx.bullets.shoot_spread(bullet, bullet_n, deg_to_rad(30), dir, target.global_position)
	)
