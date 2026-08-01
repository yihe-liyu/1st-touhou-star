## 激光形态预设库 —— 弹幕作者直接"选形态 + 填参数"，不用手写曲线
## 每个预设返回 LaserSkeleton（骨架），配合 engine.spawn(sk, color, opts) 使用：
##   var sk := LaserPresets.wave(origin, dir, 800.0, 60.0, 200.0)
##   engine.spawn(sk, Color.BLUE, {"grow": true, ...})
class_name LaserPresets
extends RefCounted

const _SEG: float = 16.0  # 预设采样步长（px）


## 直线（两点）
static func straight(a: Vector2, b: Vector2) -> LaserSkeleton:
	var sk := LaserSkeleton.new()
	sk.from_line(a, b)
	return sk


## 折线（多个点）
static func polyline(pts: Array) -> LaserSkeleton:
	var sk := LaserSkeleton.new()
	var packed := PackedVector2Array()
	for p in pts:
		packed.append(p)
	sk.from_points(packed)
	return sk


## 正弦波：沿 base_dir 方向传播，横向摆动（amp 振幅 / wavelength 波长）
static func wave(origin: Vector2, base_dir: Vector2, length: float, amp: float, wavelength: float) -> LaserSkeleton:
	var dir := base_dir.normalized()
	var perp := dir.orthogonal()
	var n := maxi(2, int(ceil(length / _SEG)))
	var sk := LaserSkeleton.new()
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var along := origin + dir * (length * t)
		var offset := sin(t * TAU * length / maxf(wavelength, 1.0)) * amp
		pts.append(along + perp * offset)
	sk.from_points(pts)
	return sk


## 螺旋：绕 center 从中心向外展开（turns 圈数 / phase 起始角 / radius 外径）
static func spiral(center: Vector2, radius: float, turns: float, phase_rad: float = 0.0, segments_per_turn: int = 24) -> LaserSkeleton:
	var n := maxi(8, int(turns * segments_per_turn))
	var sk := LaserSkeleton.new()
	var pts := PackedVector2Array()
	for i in n + 1:  # 含终点（t=1 → 外径）
		var t := float(i) / float(n)
		var ang := phase_rad + t * turns * TAU
		var r := radius * t
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	sk.from_points(pts)
	return sk


## 扇形扫：从 origin 出发，方向从 start_dir 扫过 sweep_angle
static func sweep(origin: Vector2, start_dir: Vector2, sweep_angle: float, length: float, segments: int = 20) -> LaserSkeleton:
	var n := maxi(2, segments)
	var sk := LaserSkeleton.new()
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var dir := start_dir.rotated(sweep_angle * t)
		pts.append(origin + dir * length)
	sk.from_points(pts)
	return sk


## 贝塞尔（c1/c2 控制点）
static func bezier(p0: Vector2, c1: Vector2, c2: Vector2, p1: Vector2, segments: int = 24) -> LaserSkeleton:
	var n := maxi(4, segments)
	var sk := LaserSkeleton.new()
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var u := 1.0 - t
		pts.append(u * u * u * p0 + 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t * p1)
	sk.from_points(pts)
	return sk
