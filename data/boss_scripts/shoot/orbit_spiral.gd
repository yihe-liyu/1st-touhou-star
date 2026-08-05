extends CoroutineScript
## 旋转发射器（发弹点轨迹实验 v4）
## 三段式：外扩（半径渐远）→ 外圈保持（半径不变继续旋转 hold_time 秒，画一圈外环）→ 回卷重开
## 角加速度：角速度随时间变化（正=越转越快/螺旋渐疏，负=渐慢）；夹在 min~max 之间
## 弹幕：每发 probe_count 颗铺满 360°，挂往返探测弹行为（飞出→回点→分裂 90° 红弹）
## auto_stop = false

const PROBE_PATH := "res://data/bullet_scripts/orbit_probe.gd"

var orbit_speed: float = 3    # 初始角速度（弧度/秒，1.5 ≈ 每秒 86°）
var angle_accel: float = 0.0  # 角加速度（弧度/秒²，正=加速、负=减速）
var angle_speed_min: float = 0.3  # 角速度下限（防停转）
var angle_speed_max: float = 512.0  # 角速度上限（防糊成一片）
var radius_min: float = 0.0    # 起始半径（离 Boss 最近）
var radius_max: float = 550.0   # 外扩上限
var radius_growth: float = 55.0 # 半径每秒外扩量
var hold_time: float = 5.0      # 到达外圈后保持旋转的秒数（画外环）
var interval: float = 0.05      # 发弹间隔（秒）
var bullet_speed: float = 150.0 # 青弹初速（往返探测弹起飞速度）
var probe_count: int = 8        # 每发颗数（铺满 360°）

var _angle: float = 0.0
var _angle_speed: float = 5.0  # 当前角速度（哨兵：首次 tick 取 orbit_speed，工作台改后重跑生效）
var _radius: float = 60.0
var _hold_left: float = 0.0  # 剩余保持时间（>0 = 外圈空转阶段）


func _tick(p_ctx: StageContext):
	if not target:
		return p_ctx.clock.wait(interval)

	# ── 发弹点轨迹：角加速度更新角速度 → 三段式（外扩 → 外圈保持 → 回卷）──
	if _angle_speed < 0.0:
		_angle_speed = orbit_speed
	_angle_speed += angle_accel * interval
	_angle_speed = clampf(_angle_speed, angle_speed_min, angle_speed_max)
	_angle += _angle_speed * interval
	if _hold_left > 0.0:
		# 外圈保持：半径不动，继续旋转 hold_time 秒（画外环）
		_hold_left -= interval
		if _hold_left <= 0.0:
			_radius = radius_min  # 开启下一轮
			_angle = RNG.randf() * TAU  # 新一轮：发弹点初始角度随机（每层螺旋错开）
	else:
		# 外扩：半径渐远
		_radius += radius_growth * interval
		if _radius >= radius_max:
			_radius = radius_max
			_hold_left = hold_time

	# 发弹点 = Boss 中心 + 半径方向 × 当前半径（跟随 Boss 移动）
	var emit_pos := target.global_position \
		+ Vector2(cos(_angle), sin(_angle)) * _radius

	# ── 发射：probe_count 颗铺满圆，切向为基准方向；挂往返探测弹行为 ──
	var dir := Vector2(-sin(_angle), cos(_angle))  # 半径方向顺时针转 90° = 切向（基准）
	var bullet := BulletData.new() \
		.tex("小玉") \
		.speed(bullet_speed) \
		.color(Color(0.4, 0.8, 1.0, 0.9)) \
		.blend(true) \
		.enemy() \
		.behavior(load(PROBE_PATH))
	p_ctx.bullets.shoot_spread(bullet, probe_count, TAU, dir, emit_pos, AssetRegistry.sounds["shoot"])

	return p_ctx.clock.wait(interval)
