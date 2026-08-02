extends Node
## 验证：魔理沙激光段 velocity = 移动方向（击中特效继承）
const LASER_FOLLOW = preload("res://scripts/coroutine/player/marisa_laser_follow.gd")

func _ready():
	var bscript := GDScript.new()
	bscript.source_code = "extends Node2D\nvar extra := {}\nvar velocity := Vector2.ZERO"
	bscript.reload()
	var anchor := Node2D.new()
	anchor.global_position = Vector2(448, 600)
	add_child(anchor)
	var bullet_node: Node2D = Node2D.new()
	bullet_node.set_script(bscript)
	bullet_node.global_position = Vector2(448, 600)
	add_child(bullet_node)
	bullet_node.extra = {
		"anchor_node": anchor,
		"laser_offset": Vector2.ZERO,
		"drift_speed": 300.0,
		"drift_angle": deg_to_rad(30.0),  # 30° 右偏
	}
	var lf := LASER_FOLLOW.new()
	var ctx := StageContext.new(lf)
	lf.start_fast(ctx, bullet_node)
	for i in 3:
		lf.tick_fast(1.0 / 60.0)
	# 期望 velocity = (sin30, -cos30) ≈ (0.5, -0.866)
	print("[verify] 激光段 velocity=%s（期望 ≈ (0.5, -0.866)）" % str(bullet_node.velocity))
	get_tree().quit()
