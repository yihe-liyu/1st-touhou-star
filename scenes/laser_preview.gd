extends Node2D

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.12)
	bg.size = Vector2(1280, 960)
	bg.position = Vector2(0, 0)
	add_child(bg)
	var engine := LaserEngine.new()
	engine.setup(self)
	# ① 红色直线 y=150
	engine.spawn_line(Vector2(100, 150), Vector2(1100, 150), Color(1.0, 0.2, 0.15), {"grow": false, "lifetime": 30, "core_width": 24.0})
	# ② 蓝色 S 形曲线（生长型）
	var curve := Curve2D.new()
	curve.add_point(Vector2(100, 400))
	curve.add_point(Vector2(400, 280), Vector2(-80, 0), Vector2(80, 0))
	curve.add_point(Vector2(800, 420), Vector2(-80, 0), Vector2(80, 0))
	curve.add_point(Vector2(1100, 300))
	engine.spawn_curve(curve, Color(0.3, 0.6, 1.0), {"grow": true, "grow_speed": 300.0, "tail": 260.0, "lifetime": 30, "core_width": 18.0})
	# ③ 绿色摆动曲线
	var wave := Curve2D.new()
	for i in 30:
		var x := 100.0 + float(i) * 34.0
		var y := 650.0 + sin(float(i) * 0.55) * 70.0
		wave.add_point(Vector2(x, y))
	engine.spawn_curve(wave, Color(0.2, 1.0, 0.5), {"grow": false, "lifetime": 30, "core_width": 16.0})
	await get_tree().create_timer(3.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/laser_preview.png")
	print("已保存")
	get_tree().quit()
