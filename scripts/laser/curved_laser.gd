extends Node2D
class_name CurvedLaser
## 生长型曲线激光 —— 头部沿 Curve2D 前进，尾巴拖在后面

const GROW: int = 0
const ACTIVE: int = 1
const FADE: int = 2
const DEAD: int = 3

const CURVE_SAMPLES: int = 120

# 曲线 & 运动
var guide_curve: Curve2D          # 引导曲线（头部沿此走）
var head_t: float = 0.0           # 头部当前位置 (0~1)
var tail_t: float = 0.0           # 尾巴根部位置 (0~1)

# 配置
var data: CurvedLaserData
var age: float = 0.0
var phase: int = GROW
var head_speed: float = 0.0

# 旋转
var rotation_speed: float = 0.0
var origin_point: Vector2
var elapsed_angle: float = 0.0

# 节点
var line: Line2D
var _shader_mat: ShaderMaterial


func init(p_data: CurvedLaserData, p_origin: Vector2, p_curve: Curve2D,
		p_rot_speed: float = 0.0):
	data = p_data
	origin_point = p_origin
	rotation_speed = p_rot_speed
	guide_curve = p_curve

	age = 0.0
	head_t = 0.0
	tail_t = 0.0
	head_speed = 1.0 / maxf(data.grow_duration, 0.01)
	phase = GROW
	elapsed_angle = 0.0

	_setup_line()
	_apply_phase()
	print("[Laser] init: origin=", origin_point, " rot=", rotation_speed, " points=", guide_curve.get_point_count())


func _sample_curve(t: float) -> Vector2:
	## 采样引导曲线 t∈[0,1]，使用 Curve2D.sample(idx, sub_t)
	var count := guide_curve.get_point_count()
	if count < 2:
		return guide_curve.get_point_position(0) if count > 0 else Vector2.ZERO

	var total_segs := count - 1
	var idx_f := t * total_segs
	var idx := int(idx_f)
	var sub_t := idx_f - idx

	if idx >= total_segs:
		return guide_curve.get_point_position(count - 1)

	return guide_curve.sample(idx, sub_t)


func _setup_line():
	if not _shader_mat:
		_shader_mat = ShaderMaterial.new()
		_shader_mat.shader = preload("res://gdshader/laser_glow.gdshader")

	line = Line2D.new()
	line.z_index = 50
	line.width = data.base_width
	line.default_color = data.laser_color
	# BUGFIX: Line2D needs a texture to render with width_curve
	var tex := GradientTexture1D.new()
	tex.width = 1
	tex.gradient = Gradient.new()
	tex.gradient.add_point(0.0, Color.WHITE)
	tex.gradient.add_point(1.0, Color.WHITE)
	line.texture = tex
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	# TEMP: disable shader to test line rendering
	# line.material = _shader_mat

	_shader_mat.set_shader_parameter("laser_color", data.laser_color)

	# 宽度曲线：根部粗 → 尖部细
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, 1.0))
	wc.add_point(Vector2(0.4, 0.7))
	wc.add_point(Vector2(0.8, 0.35))
	wc.add_point(Vector2(1.0, data.tip_width / data.base_width))
	line.width_curve = wc

	add_child(line)


func step(delta: float):
	if phase == DEAD:
		return

	age += delta

	# 旋转
	if rotation_speed != 0.0:
		elapsed_angle += rotation_speed * delta
		_update_rotated_curve()

	match phase:
		GROW:
			head_t += head_speed * delta
			tail_t = maxf(head_t - data.max_tail, 0.0)
			if head_t >= 1.0:
				head_t = 1.0
				tail_t = maxf(1.0 - data.max_tail, 0.0)
				phase = ACTIVE
				_apply_phase()

		ACTIVE:
			if age >= data.grow_duration + data.active_duration:
				phase = FADE
				_apply_phase()

		FADE:
			if age >= data.grow_duration + data.active_duration + data.fade_duration:
				phase = DEAD
				_apply_phase()
			else:
				var fade_t := (age - data.grow_duration - data.active_duration) / data.fade_duration
				_shader_mat.set_shader_parameter("alpha", 1.0 - fade_t)

	_update_points()


func _update_rotated_curve():
	# 重建旋转后的曲线
	var new_curve := Curve2D.new()
	for i in range(CURVE_SAMPLES + 1):
		var t := float(i) / CURVE_SAMPLES
		var orig := _sample_curve(t)
		var to := orig - origin_point
		var rotated := origin_point + to.rotated(elapsed_angle)
		new_curve.add_point(rotated)
	guide_curve = new_curve


func _update_points():
	if head_t <= tail_t or guide_curve.get_point_count() < 2:
		line.clear_points()
		return

	var count := maxi(int((head_t - tail_t) * CURVE_SAMPLES), 2)
	line.clear_points()
	for i in range(count):
		var t := tail_t + (head_t - tail_t) * float(i) / float(count - 1)
		line.add_point(_sample_curve(t))

	line.default_color = data.laser_color
	line.gradient = _build_gradient()


func _build_gradient() -> Gradient:
	var g := Gradient.new()
	var color := data.laser_color

	match phase:
		GROW:
			g.add_point(0.0, Color(color, 1.0))
			g.add_point(0.85, Color(color, 0.8))
			g.add_point(1.0, Color(color, 0.0))
		ACTIVE:
			g.add_point(0.0, Color(color, 1.0))
			g.add_point(1.0, Color(color, 0.3))
		FADE:
			var fa := 1.0 - (age - data.grow_duration - data.active_duration) / data.fade_duration
			g.add_point(0.0, Color(color, fa))
			g.add_point(1.0, Color(color, fa * 0.3))

	return g


func _apply_phase():
	match phase:
		GROW:
			_shader_mat.set_shader_parameter("alpha", 1.0)
			_shader_mat.set_shader_parameter("warning", 1.0)
			_shader_mat.set_shader_parameter("glow_intensity", data.glow_intensity * 0.5)
		ACTIVE:
			_shader_mat.set_shader_parameter("alpha", 1.0)
			_shader_mat.set_shader_parameter("warning", 0.0)
			_shader_mat.set_shader_parameter("glow_intensity", data.glow_intensity)
		FADE:
			_shader_mat.set_shader_parameter("warning", 0.0)
		DEAD:
			_shader_mat.set_shader_parameter("alpha", 0.0)


func is_hitting_player(player_pos: Vector2, hit_radius: float = 2.0) -> bool:
	if phase != ACTIVE:
		return false

	var threshold := data.hitbox_width + hit_radius

	# 曲线段采样检测
	for i in range(CURVE_SAMPLES):
		var t := tail_t + (head_t - tail_t) * float(i) / float(CURVE_SAMPLES - 1)
		var a := _sample_curve(t)

		if i < CURVE_SAMPLES - 1:
			var t2 := tail_t + (head_t - tail_t) * float(i + 1) / float(CURVE_SAMPLES - 1)
			var b := _sample_curve(t2)
			var closest := _closest_point_on_segment(player_pos, a, b)
			if player_pos.distance_to(closest) < threshold:
				return true

	return false


func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var ap := p - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return a
	var t := clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t
