extends Node2D
class_name CurvedLaser
## 梭形生长型曲线激光 —— 头部一直前进，尾巴跟随，出屏消失

const ALIVE: int = 0
const FADE: int = 1
const DEAD: int = 2

const CURVE_SAMPLES: int = 60  # 旋转曲线采样点数（120→60）

# 曲线 & 运动
var guide_curve: Curve2D
var head_dist: float = 0.0        # 头部走过的总距离 px
var tail_dist: float = 0.0        # 尾巴位置 px
var curve_total_length: float     # 引导曲线原始总长 px
var end_dir: Vector2              # 曲线终点方向（外插用）

# 配置
var data: CurvedLaserData
var age: float = 0.0
var phase: int = ALIVE
var _fade_age: float = 0.0

# 旋转
var rotation_speed: float = 0.0
var origin_point: Vector2
var elapsed_angle: float = 0.0

# 节点
var line: Line2D
var _shader_mat: ShaderMaterial
var _screen_size: Rect2


func init(p_data: CurvedLaserData, p_origin: Vector2, p_curve: Curve2D,
		p_rot_speed: float = 0.0):
	data = p_data
	origin_point = p_origin
	rotation_speed = p_rot_speed
	guide_curve = p_curve
	
	# 计算曲线总长和末方向
	curve_total_length = _calc_curve_length()
	var count := guide_curve.get_point_count()
	if count >= 2:
		var last := guide_curve.get_point_position(count - 1)
		var prev := guide_curve.get_point_position(count - 2)
		end_dir = (last - prev).normalized()
	else:
		end_dir = Vector2.DOWN
	
	# 获取屏幕范围（加一点 tolerance）
	if is_inside_tree():
		_screen_size = get_viewport().get_visible_rect()

	age = 0.0
	head_dist = 0.0
	tail_dist = 0.0
	phase = ALIVE
	elapsed_angle = 0.0
	_fade_age = 0.0

	_setup_line()
	_apply_phase()
	_spawn_fog()


func _calc_curve_length() -> float:
	var total := 0.0
	var count := guide_curve.get_point_count()
	if count < 2:
		return 1.0
	var prev := guide_curve.get_point_position(0)
	for i in range(1, count):
		var pos := guide_curve.get_point_position(i)
		total += prev.distance_to(pos)
		prev = pos
	return total


func _sample_curve(dist: float) -> Vector2:
	## 采样引导曲线上距离起点 dist px 处的点，超出则外插
	if dist <= 0.0:
		return guide_curve.get_point_position(0)
	
	if dist >= curve_total_length:
		# 外插：沿终点方向继续延伸
		var last := guide_curve.get_point_position(guide_curve.get_point_count() - 1)
		return last + end_dir * (dist - curve_total_length)
	
	# 沿曲线遍历找到 dist 对应的点
	var walked := 0.0
	var count := guide_curve.get_point_count()
	var prev := guide_curve.get_point_position(0)
	for i in range(1, count):
		var pos := guide_curve.get_point_position(i)
		var seg := prev.distance_to(pos)
		if walked + seg >= dist:
			var t := (dist - walked) / seg
			return prev.lerp(pos, t)
		walked += seg
		prev = pos
	
	return guide_curve.get_point_position(count - 1)


func _setup_line():
	if not _shader_mat:
		_shader_mat = ShaderMaterial.new()
		_shader_mat.shader = preload("res://gdshader/laser_glow.gdshader")

	line = Line2D.new()
	line.z_index = 50
	line.width = data.mid_width
	line.default_color = data.laser_color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND

	var tex := GradientTexture1D.new()
	tex.width = 1
	tex.gradient = Gradient.new()
	tex.gradient.add_point(0.0, Color.WHITE)
	tex.gradient.add_point(1.0, Color.WHITE)
	line.texture = tex
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.material = _shader_mat

	_shader_mat.set_shader_parameter("laser_color", data.laser_color)

	# **梭形宽度曲线**：两端细 → 中间粗 → 尖端细
	var ratio := data.end_width / data.mid_width
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, ratio))      # 尾端：细
	wc.add_point(Vector2(0.25, 0.7))
	wc.add_point(Vector2(0.5, 1.0))         # 中间：最粗
	wc.add_point(Vector2(0.75, 0.7))
	wc.add_point(Vector2(1.0, ratio))       # 头端：细
	line.width_curve = wc

	add_child(line)


func step(delta: float):
	if phase == DEAD:
		return

	age += delta

	if rotation_speed != 0.0:
		elapsed_angle += rotation_speed * delta
		_update_rotated_curve()

	match phase:
		ALIVE:
			# 头部一直前进
			head_dist += data.grow_speed * delta
			tail_dist = maxf(head_dist - data.tail_distance, 0.0)
			
			if data.max_lifetime > 0.0:
				if age >= data.max_lifetime:
					phase = FADE
					_fade_age = 0.0
					_apply_phase()
			else:
				# 只有头尾都出屏了才算真正离开屏幕
				var head_pos := _sample_curve(head_dist)
				var tail_pos := _sample_curve(tail_dist)
				var head_off := _is_offscreen(head_pos)
				var tail_off := _is_offscreen(tail_pos)
				if (head_off and tail_off) :
					phase = FADE
					_fade_age = 0.0
					_apply_phase()

		FADE:
			_fade_age += delta
			_shader_mat.set_shader_parameter("alpha", maxf(1.0 - _fade_age / 0.3, 0.0))
			if _fade_age >= 0.3:
				phase = DEAD
				_apply_phase()

	_update_points()


func _is_offscreen(pos: Vector2) -> bool:
	if _screen_size.size == Vector2.ZERO:
		if is_inside_tree():
			_screen_size = get_viewport().get_visible_rect()
		if _screen_size.size == Vector2.ZERO:
			return false
	var margin := 200.0
	return (pos.x < -margin or pos.x > _screen_size.size.x + margin or
			pos.y < -margin or pos.y > _screen_size.size.y + margin)


func _update_rotated_curve():
	# 用更少的采样点重建旋转曲线
	var new_curve := Curve2D.new()
	var cached_len := curve_total_length
	for i in range(CURVE_SAMPLES + 1):
		var t := float(i) / CURVE_SAMPLES
		var dist := t * cached_len
		var orig := _sample_curve(dist)
		var to := orig - origin_point
		var rotated := origin_point + to.rotated(elapsed_angle)
		new_curve.add_point(rotated)
	guide_curve = new_curve


func _update_points():
	var visible_length := head_dist - tail_dist
	if visible_length <= 10.0:
		line.clear_points()
		return

	var count := maxi(int(visible_length / 15.0), 8)  # 15px间距，至少8个点
	line.clear_points()
	for i in range(count):
		var dist := tail_dist + visible_length * float(i) / float(count - 1)
		line.add_point(_sample_curve(dist))


func _spawn_fog():
	# 先清理旧的
	var old := get_node_or_null("Fog")
	if old:
		old.queue_free()
	if not data.spawn_fog_texture:
		return
	var fog := Sprite2D.new()
	fog.name = "Fog"
	fog.texture = data.spawn_fog_texture
	fog.global_position = origin_point
	fog.z_index = 51
	add_child(fog)


func _toggle_fog(visible: bool):
	var fog := get_node_or_null("Fog")
	if fog:
		fog.visible = visible


func _apply_phase():
	line.visible = true
	match phase:
		ALIVE:
			_toggle_fog(true)
			_shader_mat.set_shader_parameter("alpha", 1.0)
			_shader_mat.set_shader_parameter("warning", 0.0)
			_shader_mat.set_shader_parameter("glow_intensity", data.glow_intensity)
		FADE:
			_toggle_fog(false)
			_shader_mat.set_shader_parameter("warning", 0.0)
		DEAD:
			_toggle_fog(false)
			_shader_mat.set_shader_parameter("alpha", 0.0)
			line.visible = false


func is_hitting_player(player_pos: Vector2, hit_radius: float = 2.0) -> bool:
	if phase != ALIVE:
		return false

	var threshold := data.hitbox_width + hit_radius
	var visible_length := head_dist - tail_dist
	if visible_length <= 0.0:
		return false

	var samples := maxi(int(visible_length / 20.0), 4)  # 20px间距
	for i in range(samples):
		var dist := tail_dist + visible_length * float(i) / float(samples - 1)
		var a := _sample_curve(dist)

		if i < samples - 1:
			var dist2 := tail_dist + visible_length * float(i + 1) / float(samples - 1)
			var b := _sample_curve(dist2)
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
