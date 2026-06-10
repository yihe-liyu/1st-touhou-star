extends Node2D
class_name CurvedLaser
## 梭形生长型曲线激光 —— 头部一直前进，尾巴跟随，出屏消失
## 支持孔洞分段：消弹圆切割后，激光被分成多段显示

const ALIVE: int = 0
const FADE: int = 1
const DEAD: int = 2

const CURVE_SAMPLES: int = 60
const MAX_SEGMENTS: int = 8  # 最多 8 段，撑够一生

# 曲线 & 运动
var guide_curve: Curve2D
var head_dist: float = 0.0
var tail_dist: float = 0.0
var curve_total_length: float
var end_dir: Vector2

# 孔洞（消弹圆打的洞）
var holes: Array[Dictionary] = []  # [{start_dist, end_dist}]
var _grazed_ranges: Array[Dictionary] = []  # 已擦过的 dist 区间

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
var _seg_lines: Array[Line2D] = []  # 分段落 Line2D 池
var _shader_mat: ShaderMaterial
var _fog_sprite: Sprite2D
var _fog_tween: Tween
var _screen_size: Rect2


func init(p_data: CurvedLaserData, p_origin: Vector2, p_curve: Curve2D,
		p_rot_speed: float = 0.0):
	data = p_data
	origin_point = p_origin
	rotation_speed = p_rot_speed
	guide_curve = p_curve
	holes.clear()
	_grazed_ranges.clear()
	
	curve_total_length = _calc_curve_length()
	var count := guide_curve.get_point_count()
	if count >= 2:
		var last := guide_curve.get_point_position(count - 1)
		var prev := guide_curve.get_point_position(count - 2)
		end_dir = (last - prev).normalized()
	else:
		end_dir = Vector2.DOWN
	
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
	if dist <= 0.0:
		return guide_curve.get_point_position(0)
	
	if dist >= curve_total_length:
		var last := guide_curve.get_point_position(guide_curve.get_point_count() - 1)
		return last + end_dir * (dist - curve_total_length)
	
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

	# 主 Line2D（无孔时用）
	line = _make_line_node()
	line.visible = false
	add_child(line)
	
	# 段落 Line2D 池（有孔时用）
	for i in range(MAX_SEGMENTS):
		var sl := _make_line_node()
		sl.visible = false
		add_child(sl)
		_seg_lines.append(sl)
	
	_shader_mat.set_shader_parameter("laser_color", data.laser_color)
	_shader_mat.set_shader_parameter("glow_intensity", data.glow_intensity)


func _make_line_node() -> Line2D:
	var l := Line2D.new()
	l.z_index = 50
	l.width = data.mid_width
	l.default_color = data.laser_color
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	
	var tex := GradientTexture1D.new()
	tex.width = 1
	tex.gradient = Gradient.new()
	tex.gradient.add_point(0.0, Color.WHITE)
	tex.gradient.add_point(1.0, Color.WHITE)
	l.texture = tex
	l.texture_mode = Line2D.LINE_TEXTURE_TILE
	l.material = _shader_mat
	
	var ratio := data.end_width / data.mid_width
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, ratio))
	wc.add_point(Vector2(0.25, 0.7))
	wc.add_point(Vector2(0.5, 1.0))
	wc.add_point(Vector2(0.75, 0.7))
	wc.add_point(Vector2(1.0, ratio))
	l.width_curve = wc
	
	return l


# ── 孔洞 ──

func add_hole(h_start: float, h_end: float) -> void:
	## 在激光上打一个洞（距离范围），自动合并重叠
	if h_start >= h_end or h_end <= tail_dist or h_start >= head_dist:
		return
	# 裁剪到可见范围
	h_start = maxf(h_start, tail_dist)
	h_end = minf(h_end, head_dist)
	if h_start >= h_end:
		return
	
	holes.append({start_dist = h_start, end_dist = h_end})
	_merge_holes()


func _merge_holes() -> void:
	if holes.size() <= 1:
		return
	# 按 start 排序
	holes.sort_custom(func(a, b): return a.start_dist < b.start_dist)
	var merged: Array[Dictionary] = [holes[0]]
	for i in range(1, holes.size()):
		var prev = merged[merged.size() - 1]
		var cur = holes[i]
		if cur.start_dist <= prev.end_dist:
			prev.end_dist = maxf(prev.end_dist, cur.end_dist)
		else:
			merged.append(cur)
	holes = merged


func _shift_holes(amount: float) -> void:
	## 孔洞跟着激光一起往前滑，被尾巴超出的丢弃
	for i in range(holes.size() - 1, -1, -1):
		holes[i].start_dist += amount
		holes[i].end_dist += amount
		if holes[i].end_dist <= tail_dist:
			holes.remove_at(i)


func _has_any_visible() -> bool:
	## 激光上是否还有未被洞覆盖的可见段
	var segs := _build_segments()
	for seg in segs:
		if (seg.end_dist as float) - (seg.start_dist as float) > 10.0:
			return true
	return false


# ── 擦弹分段 ──

func mark_grazed(dist: float) -> void:
	var margin := 20.0
	_grazed_ranges.append({start_dist = dist - margin, end_dist = dist + margin})
	_merge_grazed()

func is_grazed(dist: float) -> bool:
	for gr in _grazed_ranges:
		if dist >= (gr.start_dist as float) and dist <= (gr.end_dist as float):
			return true
	return false

func _merge_grazed() -> void:
	if _grazed_ranges.size() <= 1:
		return
	_grazed_ranges.sort_custom(func(a, b): return a.start_dist < b.start_dist)
	var merged: Array[Dictionary] = [_grazed_ranges[0]]
	for i in range(1, _grazed_ranges.size()):
		var prev = merged[-1]
		var cur = _grazed_ranges[i]
		if cur.start_dist <= prev.end_dist:
			prev.end_dist = maxf(prev.end_dist, cur.end_dist)
		else:
			merged.append(cur)
	_grazed_ranges = merged

func _shift_grazed(amount: float) -> void:
	for i in range(_grazed_ranges.size() - 1, -1, -1):
		_grazed_ranges[i].start_dist += amount
		_grazed_ranges[i].end_dist += amount
		if _grazed_ranges[i].end_dist <= tail_dist:
			_grazed_ranges.remove_at(i)


## 返回激光上距离 player_pos 最近点的 dist 值
func find_closest_dist(player_pos: Vector2) -> float:
	var visible_len := head_dist - tail_dist
	if visible_len <= 0:
		return tail_dist
	var samples := maxi(int(visible_len / 10.0), 16)
	var best_dist := tail_dist
	var best_d2 := INF
	for i in range(samples):
		var dist := tail_dist + visible_len * float(i) / float(samples - 1)
		var pt := _sample_curve(dist)
		var d2 := player_pos.distance_squared_to(pt)
		if d2 < best_d2:
			best_d2 = d2
			best_dist = dist
	return best_dist


func _build_segments() -> Array[Dictionary]:
	## 返回 [{start_dist, end_dist}, ...] 不包含孔洞的可见区间
	if holes.is_empty():
		return [{start_dist = tail_dist, end_dist = head_dist}]
	
	var segs: Array[Dictionary] = []
	var cur := tail_dist
	for h in holes:
		if h.start_dist > cur:
			segs.append({start_dist = cur, end_dist = h.start_dist})
		cur = maxf(cur, h.end_dist)
	if cur < head_dist:
		segs.append({start_dist = cur, end_dist = head_dist})
	return segs


# ── 步进 ──

func step(delta: float):
	if phase == DEAD:
		return

	age += delta

	if rotation_speed != 0.0:
		elapsed_angle += rotation_speed * delta
		_update_rotated_curve()

	match phase:
		ALIVE:
			var old_tail := tail_dist
			head_dist += data.grow_speed * delta
			tail_dist = maxf(head_dist - data.tail_distance, 0.0)
			# 孔洞跟着尾巴一起滑
			var tail_shift := tail_dist - old_tail
			if tail_shift > 0.0:
				_shift_holes(tail_shift)
				_shift_grazed(tail_shift)
			_toggle_fog(tail_dist <= 0.0)
			if _fog_sprite and _fog_sprite.visible:
				_fog_sprite.rotation += delta * 18.0
			
			# 有孔洞时才检查是否整条激光都成洞了
			if not holes.is_empty() and not _has_any_visible():
				phase = FADE
				_fade_age = 0.0
				_apply_phase()
			elif data.max_lifetime > 0.0:
				if age >= data.max_lifetime:
					phase = FADE
					_fade_age = 0.0
					_apply_phase()
			else:
				var head_pos := _sample_curve(head_dist)
				var tail_pos := _sample_curve(tail_dist)
				var head_off := _is_offscreen(head_pos)
				var tail_off := _is_offscreen(tail_pos)
				if head_off and tail_off:
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
	var segs := _build_segments()
	
	if segs.size() == 0:
		line.visible = false
		for sl in _seg_lines: sl.visible = false
		return
	
	# 无孔 → 单 Line2D
	if segs.size() == 1 and holes.is_empty():
		for sl in _seg_lines: sl.visible = false
		line.visible = true
		var seg := segs[0]
		_draw_segment(line, seg.start_dist, seg.end_dist)
		return
	
	# 有孔 → 多段落
	line.visible = false
	for i in range(MAX_SEGMENTS):
		var sl := _seg_lines[i]
		if i < segs.size():
			sl.visible = true
			_draw_segment(sl, segs[i].start_dist, segs[i].end_dist)
		else:
			sl.visible = false


func _draw_segment(l: Line2D, s_dist: float, e_dist: float) -> void:
	var vis_len := e_dist - s_dist
	if vis_len <= 10.0:
		l.clear_points()
		return
	var count := maxi(int(vis_len / 15.0), 8)
	l.clear_points()
	for i in range(count):
		var dist := s_dist + vis_len * float(i) / float(count - 1)
		l.add_point(_sample_curve(dist))


# ── 弹雾 ──

func _spawn_fog():
	if _fog_sprite:
		if _fog_tween and _fog_tween.is_valid():
			_fog_tween.kill()
		_fog_sprite.global_position = origin_point
		_fog_sprite.scale = Vector2(2.0, 2.0)
		if _fog_sprite.material:
			_fog_sprite.material.set_shader_parameter("fog_tint", data.laser_color)
		_fog_sprite.modulate = Color.WHITE
		_fog_sprite.modulate.a = 1.0
		_fog_sprite.visible = true
		return
	if not data.spawn_fog_texture:
		return
	_fog_sprite = Sprite2D.new()
	_fog_sprite.texture = data.spawn_fog_texture
	_fog_sprite.scale = Vector2(2.0, 2.0)
	_fog_sprite.global_position = origin_point
	_fog_sprite.z_index = 51
	
	# BLEND shader：白色不变，只染暗部
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/bullet_fog_blend.gdshader")
	mat.set_shader_parameter("fog_tint", data.laser_color)
	_fog_sprite.material = mat
	_fog_sprite.modulate = Color.WHITE
	
	add_child(_fog_sprite)


func _toggle_fog(v: bool):
	if not _fog_sprite:
		return
	if v:
		if _fog_tween and _fog_tween.is_valid():
			_fog_tween.kill()
		_fog_sprite.scale = Vector2(2.0, 2.0)
		_fog_sprite.material.set_shader_parameter("fog_tint:a", 1.0)
		_fog_sprite.visible = true
	else:
		if _fog_tween and _fog_tween.is_valid():
			return
		_fog_tween = create_tween()
		_fog_tween.set_ease(Tween.EASE_OUT)
		_fog_tween.set_trans(Tween.TRANS_QUAD)
		_fog_tween.set_parallel(true)
		_fog_tween.tween_property(_fog_sprite, "scale", Vector2.ZERO, 0.3)
		_fog_tween.tween_method(_set_laser_fog_alpha, 1.0, 0.0, 0.3)


func _set_laser_fog_alpha(a: float):
	_fog_sprite.material.set_shader_parameter("fog_tint:a", a)


func _apply_phase():
	line.visible = true
	match phase:
		ALIVE:
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
			for sl in _seg_lines: sl.visible = false


func is_hitting_player(player_pos: Vector2, hit_radius: float = 2.0) -> bool:
	if phase != ALIVE:
		return false

	var threshold := data.hitbox_width + hit_radius
	var segs := _build_segments()
	
	for seg in segs:
		var seg_len := (seg.end_dist as float) - (seg.start_dist as float)
		if seg_len <= 0.0:
			continue
		var samples := maxi(int(seg_len / 20.0), 4)
		for i in range(samples):
			var dist := (seg.start_dist as float) + seg_len * float(i) / float(samples - 1)
			var a := _sample_curve(dist)
			if i < samples - 1:
				var dist2 := (seg.start_dist as float) + seg_len * float(i + 1) / float(samples - 1)
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
