extends Node2D
class_name CurvedLaser
## 生长型曲线激光 —— 头部沿 Curve2D 前进，尾巴拖在后面

const GROW: int = 0
const ACTIVE: int = 1
const FADE: int = 2
const DEAD: int = 3

# 曲线 & 运动
var guide_curve: Curve2D          # 引导曲线（头部沿此走）
var curve_length: float           # 曲线总长（归一化 = 1）
var head_t: float = 0.0           # 头部当前位置 (0~1)
var tail_t: float = 0.0           # 尾巴根部位置 (0~1)

# 配置
var data: CurvedLaserData
var age: float = 0.0
var phase: int = GROW
var head_speed: float = 0.0       # 可动态改变

# 旋转
var rotation_speed: float = 0.0   # rad/s, 如果 > 0 则每帧旋转 guide_curve
var origin_point: Vector2         # 旋转锚点（敌人的位置）
var elapsed_angle: float = 0.0

# 节点
var line: Line2D
var material: ShaderMaterial

# 采样精度
const CURVE_SAMPLES: int = 120


func init(p_data: CurvedLaserData, p_origin: Vector2, p_curve: Curve2D,
		p_rot_speed: float = 0.0):
	data = p_data
	origin_point = p_origin
	guide_curve = p_curve
	rotation_speed = p_rot_speed
	curve_length = _calc_curve_length()
	
	age = 0.0
	head_t = 0.0
	tail_t = 0.0
	head_speed = 1.0 / maxf(data.grow_duration, 0.01)
	phase = GROW
	elapsed_angle = 0.0
	
	_setup_line()
	_apply_phase()


func _setup_line():
	if not material:
		material = ShaderMaterial.new()
		material.shader = preload("res://gdshader/laser_glow.gdshader")
	
	line = Line2D.new()
	line.width = data.base_width
	line.default_color = data.laser_color
	line.material = material
	line.texture_mode = Line2D.LINE_TEXTURE_NONE
	
	# 宽度曲线：根部粗 → 尖部细
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, 1.0))     # root = full width
	wc.add_point(Vector2(0.4, 0.7))     # 40% 处: 70%
	wc.add_point(Vector2(0.8, 0.35))    # 80% 处: 35%
	wc.add_point(Vector2(1.0, data.tip_width / data.base_width))  # tip
	line.width_curve = wc
	
	add_child(line)


func _calc_curve_length() -> float:
	var total := 0.0
	var prev := guide_curve.sample(0.0)
	for i in range(1, CURVE_SAMPLES + 1):
		var t := float(i) / CURVE_SAMPLES
		var pos := guide_curve.sample(t)
		total += prev.distance_to(pos)
		prev = pos
	return total


func step(delta: float):
	if phase == DEAD:
		return
	
	age += delta
	
	# 旋转
	if rotation_speed != 0.0:
		elapsed_angle += rotation_speed * delta
		# 重建旋转后的曲线
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
			elif data.tail_follow_head:
				# 头部继续前进？不，常规 Touhou 激光激活时不前进
				pass
		
		FADE:
			if age >= data.grow_duration + data.active_duration + data.fade_duration:
				phase = DEAD
				_apply_phase()
			else:
				var fade_t := (age - data.grow_duration - data.active_duration) / data.fade_duration
				material.set_shader_parameter("alpha", 1.0 - fade_t)
	
	_update_points()


func _update_rotated_curve():
	var new_curve := Curve2D.new()
	for i in range(CURVE_SAMPLES + 1):
		var t := float(i) / CURVE_SAMPLES
		var orig := guide_curve.sample(t)
		var to := orig - origin_point
		var rotated := origin_point + to.rotated(elapsed_angle)
		new_curve.add_point(rotated)
	guide_curve = new_curve


func _update_points():
	# 从 tail_t 到 head_t 采样曲线点
	if head_t <= tail_t or curve_length <= 0:
		line.clear_points()
		return
	
	var count := maxi(int((head_t - tail_t) * CURVE_SAMPLES), 2)
	line.clear_points()
	for i in range(count):
		var t := tail_t + (head_t - tail_t) * float(i) / float(count - 1)
		line.add_point(guide_curve.sample(t))
	
	# 更新颜色：根部实心，尖部透明
	var hue := data.laser_color
	line.default_color = hue
	line.gradient = _build_gradient()


func _build_gradient() -> Gradient:
	var g := Gradient.new()
	var color := data.laser_color
	
	match phase:
		GROW:
			# 头部正在长出来，是最新点
			g.add_point(0.0, Color(color, 1.0))          # 根: 实
			g.add_point(0.85, Color(color, 0.8))         # 中后: 半透
			g.add_point(1.0, Color(color, 0.0))          # 尖 (新生): 透明
		ACTIVE:
			g.add_point(0.0, Color(color, 1.0))
			g.add_point(1.0, Color(color, 0.3))
		FADE:
			var fade_alpha := 1.0 - (age - data.grow_duration - data.active_duration) / data.fade_duration
			g.add_point(0.0, Color(color, fade_alpha))
			g.add_point(1.0, Color(color, fade_alpha * 0.3))
	
	return g


func _apply_phase():
	if phase == GROW:
		material.set_shader_parameter("alpha", 1.0)
		material.set_shader_parameter("warning", 1.0)
		material.set_shader_parameter("glow_intensity", data.glow_intensity * 0.5)
	elif phase == ACTIVE:
		material.set_shader_parameter("alpha", 1.0)
		material.set_shader_parameter("warning", 0.0)
		material.set_shader_parameter("glow_intensity", data.glow_intensity)
	elif phase == FADE:
		material.set_shader_parameter("warning", 0.0)
	elif phase == DEAD:
		material.set_shader_parameter("alpha", 0.0)


func is_hitting_player(player_pos: Vector2, hit_radius: float = 2.0) -> bool:
	if phase != ACTIVE:
		return false
	
	var threshold := data.hitbox_width + hit_radius
	
	# 对曲线段采样检测
	for i in range(CURVE_SAMPLES):
		var t := tail_t + (head_t - tail_t) * float(i) / float(CURVE_SAMPLES - 1)
		var a := guide_curve.sample(t)
		
		if i < CURVE_SAMPLES - 1:
			var t2 := tail_t + (head_t - tail_t) * float(i + 1) / float(CURVE_SAMPLES - 1)
			var b := guide_curve.sample(t2)
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
