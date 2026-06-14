extends RefCounted
class_name StageAPI
## 协程 API —— seconds/frames 直接返回等待秒数（不再 await）
##
## 返回值约定（配合 CoroutineRunner 调度器）：
##   seconds(t) → 返回 float 秒数，runner 自动倒计时
##   frames(n)  → 返回等价秒数

const CurvedLaserClass = preload("res://scripts/laser/curved_laser.gd")

var runner: CoroutineRunner

func _init(p_runner: CoroutineRunner) -> void:
	runner = p_runner

func active() -> bool:
	return is_instance_valid(runner) and runner.is_running

func seconds(duration: float) -> float:
	return duration

func frames(count: int) -> float:
	return float(count) / Engine.physics_ticks_per_second

func shoot_spread(bullet_data: BulletData, count: int, spread_angle: float, base_dir: Vector2, at: Vector2) -> void:
	if not active():
		return
	if count <= 0:
		return
	if count == 1:
		BulletManager.shoot_enemy_bullet(bullet_data, at, base_dir)
		return
	var step: float
	if spread_angle >= TAU - 0.001:
		step = spread_angle / count
	else:
		step = spread_angle / (count - 1)
	for i in range(count):
		var angle_offset = - spread_angle / 2.0 + step * i
		var dir := base_dir.rotated(angle_offset)
		BulletManager.shoot_enemy_bullet(bullet_data, at, dir)

func spawn_enemy(data: EnemyData, position: Vector2) -> Enemy:
	if not active():
		return null
	return StageManager.spawn_enemy(data, position)

func spawn_boss(data: BossData, position: Vector2):
	if not active():
		return
	StageManager.spawn_boss(data, position, self)

func get_player() -> Player:
	return GameState.player

func get_field_rect() -> Rect2:
	if not is_instance_valid(runner):
		return Rect2()
	return runner.get_viewport().get_visible_rect()

func all_defeated() -> bool:
	return GameState.active_enemies.is_empty()

# ---------- 曲线激光 ----------

## 生长型激光
func fire_growing_laser(data: Resource, origin: Vector2,
		guide_curve: Curve2D, rot_speed: float = 0.0):
	if not active():
		return null
	return BulletManager.fire_laser(data, origin, guide_curve, rot_speed)

## 直线激光
func fire_straight_laser(data: Resource, origin: Vector2,
		direction: Vector2, length: float):
	var curve := _make_straight_curve(origin, direction, length)
	return fire_growing_laser(data, origin, curve)

## 旋转激光
func fire_rotating_laser(data: Resource, origin: Vector2,
		initial_dir: Vector2, angle_per_sec: float, length: float):
	var curve := _make_straight_curve(origin, initial_dir, length)
	return fire_growing_laser(data, origin, curve, angle_per_sec)

## 自机狙击弯曲线激光
func fire_homing_laser(data: Resource, origin: Vector2,
		bend_amount: float, length: float = 500.0):
	var player := get_player()
	if not player:
		return _fire_straight_fallback(data, origin, length)
	
	var to_player := (player.global_position - origin).normalized()
	var end := origin + to_player * length
	var mid := (origin + end) / 2.0
	var ctrl := mid + to_player.orthogonal() * bend_amount
	
	var curve := _cubic_bezier_curve(origin, ctrl, end)
	return fire_growing_laser(data, origin, curve)

func clear_all_lasers() -> void:
	BulletManager.clear_all_lasers()


func _make_straight_curve(origin: Vector2, direction: Vector2, length: float) -> Curve2D:
	var curve := Curve2D.new()
	curve.add_point(origin)
	curve.add_point(origin + direction.normalized() * length)
	return curve

func _cubic_bezier_curve(p0: Vector2, p1: Vector2, p2: Vector2) -> Curve2D:
	const SAMPLES := 120
	var curve := Curve2D.new()
	for i in range(SAMPLES + 1):
		var t := float(i) / SAMPLES
		var u := 1.0 - t
		var pos := u * u * p0 + 2 * u * t * p1 + t * t * p2
		curve.add_point(pos)
	return curve

func _fire_straight_fallback(data: Resource, origin: Vector2, length: float):
	return fire_straight_laser(data, origin, Vector2.DOWN, length)

func spawn_item(type: int, position: Vector2) -> void:
	if not active():
		return
	var pool := _find_item_pool()
	if not pool:
		return
	pool.spawn(position, type)

func _find_item_pool() -> Node:
	# ItemPool 在 World 下
	var scene := runner.get_tree().current_scene
	if not scene: return null
	var world := scene.get_node_or_null("World")
	if world:
		return world.get_node_or_null("ItemPool")
	return null

# ---------- 背景装饰物 ----------

## 生成背景装饰物（3D 物体，挂在背景场景里）
## 
## @param scene  装饰物 PackedScene
## @param pos3d  3D 世界坐标
## @param follow_plane  可选：跟随某个 BackgroundPlane 的速度
## @return 生成的 BackgroundObject 或 null
func spawn_decor(scene: PackedScene, pos3d: Vector3, follow_plane: BackgroundPlane = null) -> BackgroundObject:
	var bg := StageManager.current_background
	if not bg:
		return null
	var obj := scene.instantiate()
	var wrapper: BackgroundObject
	if obj is BackgroundObject:
		wrapper = obj
	else:
		# 包一层 Node3D，挂 BackgroundObject 脚本
		wrapper = BackgroundObject.new()
		wrapper.name = obj.name + "_decor"
		obj.name = "Mesh"
	wrapper.position = pos3d
	wrapper.follow = follow_plane
	if obj != wrapper:
		wrapper.add_child(obj)
	bg.add_child(wrapper)
	return wrapper


# ═══ 对话 ═══

const DialogueBoxClass = preload("res://scripts/scenes/ui/dialogue_box.gd")
const DialogueBoxScene = preload("res://scenes/ui/dialogue_box.tscn")

## 播放对话序列，阻塞协程直到对话结束
func play_dialogue(data: DialogueData) -> float:
	if not active() or not is_instance_valid(runner):
		return 0.0
	
	var box := DialogueBoxScene.instantiate()
	runner.get_tree().current_scene.add_child(box)
	
	# 暂停协程，对话结束后恢复
	runner.is_running = false
	box.finished.connect(func():
		runner.is_running = true
	, CONNECT_ONE_SHOT)
	
	box.play(data)
	return 0.0  # 立即返回，由 finished 信号恢复

## 快捷单句对话
func dialogue_show(char_name: String, text: String, portrait: Texture2D = null) -> void:
	var profile := CharacterProfile.new()
	profile.char_name = char_name
	if portrait:
		profile.portraits["通常"] = portrait
	
	var bubble := DialogueBubble.new()
	bubble.speaker = profile
	bubble.text = text
	
	var line := DialogueLine.new()
	line.characters = [profile]
	line.bubbles = [bubble]
	
	var data := DialogueData.new()
	data.lines = [line]
	play_dialogue(data)
