class_name BulletService
extends RefCounted
## 子弹服务 —— 拆自 StageAPI.shoot_spread / fire_laser

var active: bool = true

func shoot_spread(bullet_data: BulletData, count: int, spread_angle: float, base_dir: Vector2, at: Vector2, sfx: AudioStream = null) -> void:
	if not active: return
	if count <= 0: return
	if sfx:
		AudioManager.play_sfx(sfx, -8.0)
	if count == 1:
		BulletManager.shoot_enemy_bullet(bullet_data, at, base_dir)
		return
	var step: float
	if spread_angle >= TAU - 0.001:
		step = spread_angle / count
	else:
		step = spread_angle / (count - 1)
	for i in count:
		var angle_offset := -spread_angle / 2.0 + step * i
		var dir := base_dir.rotated(angle_offset)
		BulletManager.shoot_enemy_bullet(bullet_data, at, dir)


func fire_growing_laser(data: Resource, origin: Vector2, guide_curve: Curve2D, rot_speed: float = 0.0) -> CurvedLaser:
	if not active: return null
	return BulletManager.fire_laser(data, origin, guide_curve, rot_speed)

func fire_straight_laser(data: Resource, origin: Vector2, direction: Vector2, length: float) -> CurvedLaser:
	var curve := _straight_curve(origin, direction, length)
	return fire_growing_laser(data, origin, curve)

func fire_rotating_laser(data: Resource, origin: Vector2, initial_dir: Vector2, angle_per_sec: float, length: float) -> CurvedLaser:
	var curve := _straight_curve(origin, initial_dir, length)
	return fire_growing_laser(data, origin, curve, angle_per_sec)

func fire_homing_laser(data: Resource, origin: Vector2, bend_amount: float, length: float = 500.0, player_pos: Vector2 = Vector2.ZERO) -> CurvedLaser:
	var to_player := (player_pos - origin).normalized()
	if to_player == Vector2.ZERO:
		return fire_straight_laser(data, origin, Vector2.DOWN, length)
	var end := origin + to_player * length
	var mid := (origin + end) / 2.0
	var ctrl := mid + to_player.orthogonal() * bend_amount
	var curve := _cubic_bezier_curve(origin, ctrl, end)
	return fire_growing_laser(data, origin, curve)

func clear_all_lasers() -> void:
	BulletManager.clear_all_lasers()


func _straight_curve(origin: Vector2, direction: Vector2, length: float) -> Curve2D:
	var curve := Curve2D.new()
	curve.add_point(origin)
	curve.add_point(origin + direction.normalized() * length)
	return curve

func _cubic_bezier_curve(p0: Vector2, p1: Vector2, p2: Vector2) -> Curve2D:
	const SAMPLES := 120
	var curve := Curve2D.new()
	for i in SAMPLES + 1:
		var t := float(i) / SAMPLES
		var u := 1.0 - t
		curve.add_point(u * u * p0 + 2 * u * t * p1 + t * t * p2)
	return curve
