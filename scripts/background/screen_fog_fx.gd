class_name ScreenFogFX
extends Node

## 全屏蒙眼雾组件：CanvasLayer + ColorRect + screen_fog shader（canvas_item）
## 太阳屏幕位置每帧 unproject（相机动雾跟动）
## 由演出脚本调用 setup(sun) 创建（practice 模式不调 → 无雾层，与旧行为一致）
## setup() 幂等：重复调用不重复创建（重跑安全）
## 全部参数 @export → 场景里选中本节点即可在 Inspector 调（每关可配不同雾）

# ── 雾纹理（setup 时 CPU 生成一次）──
@export var texture_size: int = 512          ## 云斑纹理分辨率（原 256 写死 → 提高消除像素感）
@export var texture_contrast: float = 1.8    ## 云斑对比度（原写死 1.8）

# ── 整体蒙眼 ──
@export var fog_dark: float = 0.65           ## 整体蒙眼浓度
@export var fog_color: Color = Color(0.02, 0.02, 0.03)  ## 雾色（暗蓝灰）
@export var flow_speed: float = 0.03         ## 流动速度
@export var noise_scale: float = 1.0         ## 云斑大小

# ── 太阳处 ──
@export var sun_fog_radius: float = 0.1      ## 太阳处雾团范围
@export var sun_fog_extra: float = 1.0       ## 太阳处额外浓度

# ── 精细化效果 ──
@export var detail_scale: float = 3.0        ## 第二层噪声频率倍率
@export var detail_strength: float = 0.35    ## 第二层混合权重（0=关）
@export var vignette_strength: float = 0.15  ## 边缘渐晕（0=关）
@export var breath_amplitude: float = 0.03   ## 呼吸感幅度（0=关）
@export var ring_strength: float = 0.0       ## 太阳漏光亮环（0=关）
@export var ring_radius: float = 0.16        ## 亮环半径
@export var ring_width: float = 0.03         ## 亮环宽度

var _rect: ColorRect
var _mat: ShaderMaterial
var sun: Node3D
var _bg: StageBackground


func setup(p_sun: Node3D = null) -> void:
	if _rect:
		return
	sun = p_sun
	var layer := CanvasLayer.new()
	layer.name = "FogLayer"
	layer.layer = 5  # 背景 SubViewport 内叠在 3D 之上
	add_child(layer)
	var rect := ColorRect.new()
	rect.name = "FogRect"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/screen_fog.gdshader")
	mat.set_shader_parameter("noise_tex", _make_cloud_texture(texture_size))
	rect.material = mat
	layer.add_child(rect)
	_rect = rect
	_mat = mat
	_apply_params()


func _process(_delta: float) -> void:
	if not _mat:
		return
	var bg := _get_bg()
	if not bg or not bg.camera:
		return
	if sun and is_instance_valid(sun):
		var sp: Vector2 = bg.camera.unproject_position(sun.global_position)
		var vp: Vector2 = bg.get_viewport().get_visible_rect().size
		if vp.x > 0 and vp.y > 0:
			_mat.set_shader_parameter("sun_pos", sp / vp)


## 把 @export 参数写入 shader（setup 时调用一次；改参数后重跑/重挂即生效）
func _apply_params() -> void:
	if not _mat:
		return
	_mat.set_shader_parameter("fog_dark", fog_dark)
	_mat.set_shader_parameter("fog_color", fog_color)
	_mat.set_shader_parameter("flow_speed", flow_speed)
	_mat.set_shader_parameter("noise_scale", noise_scale)
	_mat.set_shader_parameter("sun_fog_radius", sun_fog_radius)
	_mat.set_shader_parameter("sun_fog_extra", sun_fog_extra)
	_mat.set_shader_parameter("detail_scale", detail_scale)
	_mat.set_shader_parameter("detail_strength", detail_strength)
	_mat.set_shader_parameter("vignette_strength", vignette_strength)
	_mat.set_shader_parameter("breath_amplitude", breath_amplitude)
	_mat.set_shader_parameter("ring_strength", ring_strength)
	_mat.set_shader_parameter("ring_radius", ring_radius)
	_mat.set_shader_parameter("ring_width", ring_width)


func _get_bg() -> StageBackground:
	if _bg and is_instance_valid(_bg):
		return _bg
	_bg = get_parent() as StageBackground
	return _bg


## 值噪声云斑纹理（fbm 多频叠加，格点按周期取模 → 四方无缝可平铺）：有机雾斑，非正弦波浪
## 分辨率 texture_size（默认 512）越高云斑边缘越平滑、无像素感
func _make_cloud_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var layers: Array[int] = [6, 12, 24]
	var weights: Array[float] = [0.55, 0.30, 0.15]
	var noise_seed := 20240808
	for y in range(size):
		for x in range(size):
			var v := 0.0
			for i in layers.size():
				var f := float(layers[i]) / size
				v += _value_noise(x * f, y * f, layers[i], noise_seed + i) * weights[i]
			# 增强对比（云斑更分明）
			v = clampf((v - 0.5) * texture_contrast + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)


## 平滑值噪声：格点随机 + 双线性平滑插值；格点按 period 取模 → 纹理四方无缝
## （u/v 范围 [0, period)，晶格 0..period-1，邻居晶格 period 折回 0）
func _value_noise(u: float, v: float, period: int, s: int) -> float:
	var x0 := int(floor(u))
	var y0 := int(floor(v))
	var fx: float = u - floor(u)
	var fy: float = v - floor(v)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _noise_hash(x0 % period, y0 % period, s)
	var b := _noise_hash((x0 + 1) % period, y0 % period, s)
	var c := _noise_hash(x0 % period, (y0 + 1) % period, s)
	var d2 := _noise_hash((x0 + 1) % period, (y0 + 1) % period, s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d2, fx), fy)


func _noise_hash(x: int, y: int, s: int) -> float:
	# sin 小数 hash（经典 GLSL 技巧）：无溢出、确定性、0~1
	var n: float = sin(float(x * 127.1 + y * 311.7 + s * 74.7)) * 43758.5453
	return n - floor(n)
