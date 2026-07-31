extends GutTest
## 碰撞数学测试 —— 圆形/矩形判定与擦弹半径

const BulletPhysicsClass = preload("res://scripts/autoload/bullet/bullet_physics.gd")
const BULLET_SCENE = preload("res://scenes/bullet.tscn")


## 带真实 hitbox_radius 属性的目标（"in" 检查需要真实属性而非动态 set）
class TestTarget:
	extends Node2D
	var hitbox_radius: float = 8.0


## 用场景实例化 Bullet（脚本直接 new 缺少子节点会报错）
func _make_bullet(pos: Vector2, radius: float) -> Bullet:
	var b: Bullet = BULLET_SCENE.instantiate()
	autofree(b)
	b.position = pos
	b.hitbox_shape = BulletData.HitboxShape.CIRCLE
	b.hitbox_radius = radius
	b.hitbox_offset = Vector2.ZERO
	b.rotation = 0.0
	return b


func _make_rect_bullet(size: Vector2, rotation_deg: float) -> Bullet:
	var b: Bullet = BULLET_SCENE.instantiate()
	autofree(b)
	b.position = Vector2(0, 0)
	b.hitbox_shape = BulletData.HitboxShape.RECTANGLE
	b.hitbox_size = size
	b.hitbox_offset = Vector2.ZERO
	b.hitbox_rotation = rotation_deg
	b.rotation = 0.0
	return b


func _make_target(pos: Vector2, radius: float) -> TestTarget:
	var t := TestTarget.new()
	autofree(t)
	t.position = pos
	t.hitbox_radius = radius
	return t


## 圆 vs 圆：重叠判定（用 < 严格小于）
func test_circle_hits_when_overlapping():
	var phys := BulletPhysicsClass.new()
	autofree(phys)
	var bullet := _make_bullet(Vector2(0, 0), 5.0)
	var target := _make_target(Vector2(8.0, 0), 5.0)  # 距离 8 < 半径和 10
	assert_true(phys._check_circle(bullet, target), "距离小于半径和应命中")


func test_circle_misses_when_separated():
	var phys := BulletPhysicsClass.new()
	autofree(phys)
	var bullet := _make_bullet(Vector2(0, 0), 5.0)
	var target := _make_target(Vector2(11.0, 0), 5.0)  # 距离 11 > 半径和 10
	assert_false(phys._check_circle(bullet, target), "距离大于半径和不应命中")


## 圆 vs 圆：恰好相切（distance² == radius²）不命中（严格小于）
func test_circle_tangent_does_not_hit():
	var phys := BulletPhysicsClass.new()
	autofree(phys)
	var bullet := _make_bullet(Vector2(0, 0), 5.0)
	var target := _make_target(Vector2(10.0, 0), 5.0)  # 距离 10 == 半径和 10
	assert_false(phys._check_circle(bullet, target), "相切不应命中")


## 矩形 vs 圆：点在矩形内
func test_rect_hits_when_target_inside():
	var phys := BulletPhysicsClass.new()
	autofree(phys)
	var bullet := _make_rect_bullet(Vector2(40, 20), 0.0)
	var target := _make_target(Vector2(5, 0), 3.0)  # 在矩形内
	assert_true(phys._check_rect(bullet, target), "目标在矩形内应命中")


## 矩形 vs 圆：目标在矩形外
func test_rect_misses_when_target_outside():
	var phys := BulletPhysicsClass.new()
	autofree(phys)
	var bullet := _make_rect_bullet(Vector2(40, 20), 0.0)
	var target := _make_target(Vector2(100, 100), 3.0)  # 远离矩形
	assert_false(phys._check_rect(bullet, target), "目标在矩形外不应命中")


## 矩形旋转后仍正确
func test_rect_rotated_still_works():
	var phys := BulletPhysicsClass.new()
	autofree(phys)
	var bullet := _make_rect_bullet(Vector2(40, 10), 90.0)  # 旋转成竖向长条
	var target := _make_target(Vector2(0, 20), 3.0)  # 竖向长条下方
	assert_true(phys._check_rect(bullet, target), "旋转 90° 后竖向长条应命中其下方目标")


## 擦弹半径判定（用带 graze_radius 的轻量节点代替 Player）
func test_graze_radius():
	var phys := BulletPhysicsClass.new()
	autofree(phys)
	var bullet := _make_bullet(Vector2(0, 0), 3.0)
	var player: Player = load("res://scripts/player/player.gd").new()
	autofree(player)
	player.position = Vector2(35, 0)  # 距子弹 35 < 3 + graze_radius(40) = 43
	player.graze_radius = 40.0
	assert_true(phys._grazes_player(bullet, player), "35 < 43 应擦弹")


func test_graze_radius_miss():
	var phys := BulletPhysicsClass.new()
	autofree(phys)
	var bullet := _make_bullet(Vector2(0, 0), 3.0)
	var player: Player = load("res://scripts/player/player.gd").new()
	autofree(player)
	player.position = Vector2(50, 0)  # 距子弹 50 > 43
	player.graze_radius = 40.0
	assert_false(phys._grazes_player(bullet, player), "50 > 43 不应擦弹")
