extends RefCounted
class_name StageAPI
## 薄门面 —— 逐步迁移到 StageContext，最终删除
##
## 返回值约定（配合 CoroutineRunner 调度器）：
##   seconds(t) → 返回 float 秒数，runner 自动倒计时
##   frames(n)  → 返回等价秒数

var ctx  # StageContext

const ClockServiceClass = preload("res://scripts/coroutine/base/clock_service.gd")
const BulletServiceClass = preload("res://scripts/coroutine/base/bullet_service.gd")
const EnemyServiceClass = preload("res://scripts/coroutine/base/enemy_service.gd")
const PlayerServiceClass = preload("res://scripts/coroutine/base/player_service.gd")
const StageContextClass = preload("res://scripts/coroutine/base/stage_context.gd")
const DecorManagerClass = preload("res://scripts/background/decor_manager.gd")

func _init(p_runner: CoroutineRunner) -> void:
	ctx = StageContextClass.new(p_runner)

func active() -> bool:
	return ctx.active()

func seconds(duration: float) -> float:
	return ctx.clock.wait(duration)

func frames(count: int) -> float:
	return ctx.clock.wait_frames(count)

# ── 子弹 ──

func shoot_spread(bullet_data: BulletData, count: int, spread_angle: float, base_dir: Vector2, at: Vector2) -> void:
	ctx.bullets.shoot_spread(bullet_data, count, spread_angle, base_dir, at)

# ── 激光 ──

func fire_growing_laser(data: Resource, origin: Vector2, guide_curve: Curve2D, rot_speed: float = 0.0):
	return ctx.bullets.fire_growing_laser(data, origin, guide_curve, rot_speed)

func fire_straight_laser(data: Resource, origin: Vector2, direction: Vector2, length: float):
	return ctx.bullets.fire_straight_laser(data, origin, direction, length)

func fire_rotating_laser(data: Resource, origin: Vector2, initial_dir: Vector2, angle_per_sec: float, length: float):
	return ctx.bullets.fire_rotating_laser(data, origin, initial_dir, angle_per_sec, length)

func fire_homing_laser(data: Resource, origin: Vector2, bend_amount: float, length: float = 500.0):
	var pp: Vector2 = ctx.player.get_position()
	return ctx.bullets.fire_homing_laser(data, origin, bend_amount, length, pp)

func clear_all_lasers() -> void:
	ctx.bullets.clear_all_lasers()

# ── 敌机 ──

func spawn_enemy(data: EnemyData, position: Vector2) -> Enemy:
	return ctx.enemies.spawn_enemy(data, position)

func spawn_boss(data: BossData, position: Vector2):
	ctx.enemies.spawn_boss(data, position, self)

func all_defeated() -> bool:
	return ctx.enemies.all_defeated()

# ── 玩家 ──

func get_player() -> Player:
	return ctx.player.get_player()

# ── 道具 ──

func spawn_item(type: int, position: Vector2) -> void:
	ctx.spawn_item(type, position)

# ── 装饰物 ──

func add_decor_layer(layer: DecorLayer) -> void:
	_get_decor_mgr().add_layer(layer)

func remove_decor_layer(layer_name: String) -> void:
	_get_decor_mgr().remove_layer(layer_name)

func spawn_decor(layer_name: String, pos3d: Vector3, scale: Vector2 = Vector2(1, 1), follow_plane: BackgroundPlane = null, lifetime: float = -1.0) -> void:
	_get_decor_mgr().spawn(layer_name, pos3d, scale, follow_plane, lifetime)

func batch_spawn_decor(layer_name: String, count: int, x_range: Vector2, z_range: Vector2 = Vector2.ZERO, follow_plane: BackgroundPlane = null, lifetime: float = -1.0) -> void:
	_get_decor_mgr().batch_spawn(layer_name, count, x_range, z_range, follow_plane, lifetime)

func clear_decor_layer(layer_name: String) -> void:
	_get_decor_mgr().clear_layer(layer_name)

func fade_out_decor_layer(layer_name: String, duration: float) -> void:
	_get_decor_mgr().fade_out_layer(layer_name, duration)

var _decor_mgr: DecorManager

func _get_decor_mgr() -> DecorManager:
	if _decor_mgr: return _decor_mgr
	var bg := StageManager.current_background
	if not bg: return null
	var mgr := bg.get_node_or_null("DecorManager") as DecorManager
	if not mgr:
		mgr = DecorManagerClass.new()
		mgr.name = "DecorManager"
		bg.add_child(mgr)
	_decor_mgr = mgr
	return mgr

# ── 对话 ──

func play_dialogue(lines: Array) -> float:
	return ctx.play_dialogue(lines)

func dialogue_show(char_name: String, text: String, pos: Vector2 = Vector2(100, 200), portrait: Texture2D = null) -> void:
	ctx.dialogue_show(char_name, text, pos, portrait)

# ── 工具 ──

func get_field_rect() -> Rect2:
	return ctx.get_field_rect()
