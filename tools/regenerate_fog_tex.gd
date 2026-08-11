extends SceneTree
## 蒙眼雾/太阳纹理预生成工具（一次性脚本）
## 用法: godot --headless --path . -s tools/regenerate_fog_tex.gd
## 改 ScreenFogFX.texture_size/texture_contrast 或 BackgroundSun.texture_size 后重跑本脚本

func _init() -> void:
	var fx := ScreenFogFX.new()
	var img: Image = fx._make_cloud_image(512, 1.8)
	var err := ResourceSaver.save(img, "res://assets/Textures/background/stage01/cloud_noise.tres")
	print("cloud_noise.tres saved: err=", err)

	var sun := BackgroundSun.new()
	var disc: Image = sun._make_sun_disc(256)
	err = ResourceSaver.save(disc, "res://assets/Textures/background/stage01/sun_disc.tres")
	print("sun_disc.tres saved: err=", err)
	quit(0)
