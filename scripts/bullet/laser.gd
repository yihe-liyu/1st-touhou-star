extends Node2D
class_name Laser
## 激光 —— 替代 CurvedLaser 的极简版
##
## 三种模式：
##   FIXED_PATH  — 沿 Curve2D 瞬间全开，持续 n 秒后淡出
##   LINE        — 两点间直线，瞬间全开，持续 n 秒后淡出
##   GROWING     — 沿 Curve2D 头部生长，尾巴跟随，超时或出屏后淡出

enum Mode { FIXED_PATH, LINE, GROWING }

var mode: Mode = Mode.GROWING
var laser_color: Color = Color(1.0, 0.2, 0.1)
var mid_width: float = 24.0
var end_width: float = 3.0
var hitbox_width: float = 8.0
var glow_intensity: float = 0.6
var max_lifetime: float = 8.0

# 生长型专用
var grow_speed: float = 600.0
var tail_distance: float = 300.0

var age: float = 0.0
var head_dist: float = 0.0    # 头部走的距离（像素）
var tail_dist: float = 0.0    # 尾部距离
var _dead: bool = true         # pool 中未使用的激光默认为 dead
var _fading: bool = false
var _fade_age: float = 0.0
var _curve: Curve2D            # FIXED_PATH / GROWING 用
# 曲线长度通过 _curve.get_baked_length() 获取
var _line_a: Vector2           # LINE 模式起点
var _line_b: Vector2           # LINE 模式终点
var _screen_size: Rect2

var _line: Line2D
var _texture: Texture2D
var _fog_sprite: Sprite2D


func init_fixed_path(p_curve: Curve2D, p_color: Color, p_lifetime: float, p_tex: Texture2D = null):
	mode = Mode.FIXED_PATH
	_curve = _to_local_curve(p_curve)
	laser_color = p_color
	max_lifetime = p_lifetime
	head_dist = _curve.get_baked_length()
	tail_dist = 0.0
	if p_tex: _texture = p_tex
	_common_init()
	_update_line()


func init_line(a: Vector2, b: Vector2, p_color: Color, p_lifetime: float, p_tex: Texture2D = null):
	mode = Mode.LINE
	global_position = a
	_line_a = Vector2.ZERO
	_line_b = b - a
	laser_color = p_color
	max_lifetime = p_lifetime
	head_dist = _line_a.distance_to(_line_b)
	tail_dist = 0.0
	if p_tex: _texture = p_tex
	_common_init()
	_update_line()


func init_growing(p_curve: Curve2D, p_color: Color, p_grow_speed: float, p_tail: float, p_lifetime: float, p_tex: Texture2D = null):
	mode = Mode.GROWING
	_curve = _to_local_curve(p_curve)
	laser_color = p_color
	grow_speed = p_grow_speed
	tail_distance = p_tail
	max_lifetime = p_lifetime
	if p_tex: _texture = p_tex
	_common_init()
	_update_line()


func _common_init():
	# 清理上次残留的子节点
	for child in get_children():
		child.queue_free()
	_setup_line()
	_spawn_fog()
	age = 0.0
	_dead = false
	_fading = false
	_fade_age = 0.0
	_line.visible = true
	if is_inside_tree():
		_screen_size = get_viewport().get_visible_rect()


func _setup_line():
	_line = Line2D.new()
	_line.width = mid_width
	_line.default_color = laser_color
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.z_index = 50
	_line.antialiased = true
	
	if not _texture:
		_texture = preload("res://assets/Textures/bullet/laser.png")
	_line.texture = _texture
	_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	# BLEND 渲染：白色不变，只染暗部
	var blend_mat := ShaderMaterial.new()
	blend_mat.shader = preload("res://gdshader/bullet_fog_blend.gdshader")
	var bright := Color(
		minf(laser_color.r * 1.5, 1.0),
		minf(laser_color.g * 1.5, 1.0),
		minf(laser_color.b * 1.5, 1.0),
		1.0
	)
	blend_mat.set_shader_parameter("fog_tint", bright)
	_line.material = blend_mat
	
	add_child(_line)


func _spawn_fog():
	if not AssetRegistry.FOG_TEXTURE:
		return
	_fog_sprite = Sprite2D.new()
	_fog_sprite.texture = AssetRegistry.FOG_TEXTURE
	_fog_sprite.scale = Vector2(2.0, 2.0)
	_fog_sprite.z_index = 51

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/bullet_fog_blend.gdshader")
	mat.set_shader_parameter("fog_tint", laser_color)
	_fog_sprite.material = mat
	add_child(_fog_sprite)


func _physics_process(delta):
	if _dead or not _line:
		return

	age += delta

	match mode:
		Mode.FIXED_PATH, Mode.LINE:
			if max_lifetime > 0 and age >= max_lifetime:
				_start_fade()

		Mode.GROWING:
			var baked := _curve.get_baked_length() if _curve else 1.0
			var retracting := head_dist >= baked or _head_cut

			if not retracting:
				head_dist = minf(head_dist + grow_speed * delta, baked)
				tail_dist = maxf(head_dist - tail_distance, 0.0)
				
				var head_off := _is_offscreen(_sample_curve(head_dist))
				var tail_off := _is_offscreen(_sample_curve(tail_dist))
				if head_off and tail_off:
					_start_fade()
				elif max_lifetime > 0 and age >= max_lifetime:
					retracting = true
			
			# 收缩阶段：头部被切或长到头 → 尾部追头部，越来越短直到消失
			if retracting:
				if not _head_cut:
					head_dist = baked
				tail_dist = minf(tail_dist + grow_speed * delta, head_dist)
				var should_die := tail_dist >= head_dist
				if should_die:
					_dead = true
					_line.visible = false
					if _fog_sprite:
						_fog_sprite.visible = false
					return

	if _fading:
		_fade_age += delta
		_update_line()
		var alpha := maxf(1.0 - _fade_age / 0.15, 0.0)
		if _line.material is ShaderMaterial:
			_line.material.set_shader_parameter("fog_tint:a", alpha)
		if _fog_sprite:
			_fog_sprite.modulate.a = alpha
		if _fade_age >= 0.15:
			_dead = true
			_line.visible = false
			if _fog_sprite:
				_fog_sprite.visible = false
			return

	_update_fog(delta)
	_update_line()
	





## 生长型激光头部被消弹圈命中：冻结头部，尾部追上后消失
var _head_cut: bool = false

func _cut_head() -> void:
	if _dead or _fading or mode != Mode.GROWING:
		return
	_head_cut = true


	if _fading:
		return
	_fading = true
	_fade_age = 0.0
	if _fog_sprite:
		var tw := create_tween()
		tw.tween_property(_fog_sprite, "scale", Vector2.ZERO, 0.15)
		tw.tween_property(_fog_sprite, "modulate:a", 0.0, 0.15)


func _start_fade():
	if _fading:
		return
	# GROWING 模式走收缩消失，不走淡出
	if mode == Mode.GROWING:
		_head_cut = true
		return
	_fading = true
	_fade_age = 0.0
	if _fog_sprite:
		var tw := create_tween()
		tw.tween_property(_fog_sprite, "scale", Vector2.ZERO, 0.15)
		tw.tween_property(_fog_sprite, "modulate:a", 0.0, 0.15)


func _update_line():
	# 有孔洞时按段渲染（所有模式共用）
	var pts := _sample_range(tail_dist, head_dist, 60)
	var local_pts: Array = []
	for p in pts:
		local_pts.append(p - global_position)
	_sync_lines(local_pts)


func _sync_lines(pts: Array) -> void:
	_line.clear_points()
	for p in pts:
		_line.add_point(p)


## 更新两点间直线激光的端点（不重建整个激光）
func update_line_endpoints(a: Vector2, b: Vector2) -> void:
	if mode != Mode.LINE:
		return
	global_position = a
	_line_a = Vector2.ZERO
	_line_b = b - a
	head_dist = _line_a.distance_to(_line_b)
	# 只更新 tail 到 head 之间的线段
	var pts := _sample_range(tail_dist, head_dist, 30)
	_line.clear_points()
	for p in pts:
		_line.add_point(p - global_position)


func _update_fog(delta):
	if not _fog_sprite or _fading:
		return
	if mode == Mode.GROWING and tail_dist <= 0:
		_fog_sprite.visible = true
		_fog_sprite.global_position = _sample_curve(0)
		_fog_sprite.rotation += delta * 18.0
	else:
		_fog_sprite.visible = false


func is_hitting_player(player_pos: Vector2) -> bool:
	if _dead or _fading:
		return false
	var pts := _sample_range(tail_dist, head_dist, 30)
	if pts.size() < 2:
		return false
	var threshold := hitbox_width + 5.0
	for i in range(pts.size() - 1):
		var closest := _closest_on_segment(player_pos, pts[i], pts[i + 1])
		if player_pos.distance_to(closest) < threshold:
			return true
	return false


func is_grazing_player(player_pos: Vector2, graze_radius: float) -> bool:
	if _dead or _fading:
		return false
	var threshold := hitbox_width + graze_radius
	var pts := _sample_range(tail_dist, head_dist, 20)
	for i in range(pts.size() - 1):
		var closest := _closest_on_segment(player_pos, pts[i], pts[i + 1])
		if player_pos.distance_to(closest) < threshold:
			return true
	return false


# ── 工具 ──

## 将世界坐标曲线转为相对于 global_position 的局部坐标
func _to_local_curve(world_curve: Curve2D) -> Curve2D:
	var local := Curve2D.new()
	var origin := world_curve.get_point_position(0)
	global_position = origin
	for i in range(world_curve.get_point_count()):
		local.add_point(world_curve.get_point_position(i) - origin)
	return local


func _sample_curve(dist: float) -> Vector2:
	if mode == Mode.LINE:
		var progress := dist / maxf(head_dist, 1.0)
		return _line_a.lerp(_line_b, clampf(progress, 0.0, 1.0)) + global_position

	if not _curve or _curve.get_baked_length() <= 0:
		return global_position

	var clamped := clampf(dist, 0.0, _curve.get_baked_length())
	return _curve.sample_baked(clamped) + global_position


func _sample_range(from_dist: float, to_dist: float, count: int) -> Array:
	var result: Array = []
	for i in range(count):
		var d := from_dist + (to_dist - from_dist) * float(i) / float(count - 1)
		result.append(_sample_curve(d))
	return result


func _is_offscreen(pos: Vector2) -> bool:
	if _screen_size.size == Vector2.ZERO:
		if is_inside_tree():
			_screen_size = get_viewport().get_visible_rect()
		if _screen_size.size == Vector2.ZERO:
			return false
	var m := 200.0
	return pos.x < -m or pos.x > _screen_size.size.x + m or pos.y < -m or pos.y > _screen_size.size.y + m


func _closest_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var ap := p - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return a
	var t := clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t
