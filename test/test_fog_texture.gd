extends GutTest
## 雾纹理无缝性回归测试：screen_fog 用 fract(q) 平铺采样 noise_tex，
## 若纹理左右/上下边缘不连续会出可见接缝线（曾 0.39~0.44 随机跳变 → 修复后 <0.03）

func test_cloud_texture_seamless():
	var fog := ScreenFogFX.new()
	var tex: ImageTexture = fog._make_cloud_texture(128)
	fog.free()
	var img := tex.get_image()

	var lr := 0.0
	var tb := 0.0
	for y in 128:
		lr += absf(img.get_pixel(0, y).r - img.get_pixel(127, y).r)
		tb += absf(img.get_pixel(y, 0).r - img.get_pixel(y, 127).r)
	assert_lt(lr / 128.0, 0.03, "左右边缘接缝应≈无缝（当前 %.4f）" % (lr / 128.0))
	assert_lt(tb / 128.0, 0.03, "上下边缘接缝应≈无缝（当前 %.4f）" % (tb / 128.0))
