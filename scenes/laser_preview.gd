extends Node2D

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.12)
	bg.size = Vector2(1280, 960)
	bg.position = Vector2(0, 0)
	add_child(bg)
	var engine := LaserEngine.new()
	engine.setup(self)
	# ① 正弦波预设（红色）
	var w := LaserPresets.wave(Vector2(100, 150), Vector2(1, 0), 1000.0, 60.0, 200.0)
	engine.spawn(w, Color(1.0, 0.2, 0.15), {"grow": false, "lifetime": 30, "core_width": 18.0})
	# ② 螺旋预设（蓝色，生长型）
	var sp := LaserPresets.spiral(Vector2(640, 500), 250.0, 1.5, 0.0)
	engine.spawn(sp, Color(0.3, 0.6, 1.0), {"grow": true, "grow_speed": 400.0, "tail": 220.0, "lifetime": 30, "core_width": 14.0})
	# ③ 扇形扫预设（绿色）
	var sw := LaserPresets.sweep(Vector2(640, 850), Vector2(0, -1), PI * 0.7, 350.0)
	engine.spawn(sw, Color(0.2, 1.0, 0.5), {"grow": false, "lifetime": 30, "core_width": 16.0})
	await get_tree().create_timer(2.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/laser_presets.png")
	print("已保存")
	get_tree().quit()
