class_name StageContext
extends RefCounted
## 关卡上下文 —— 协程拿这个代替 StageAPI

var clock: ClockService
var bullets: BulletService
var enemies: EnemyService
var player: PlayerService
var decor: DecorManager
var runner: CoroutineRunner

func _init(p_runner: CoroutineRunner) -> void:
	runner = p_runner
	clock = ClockService.new()
	bullets = BulletService.new()
	enemies = EnemyService.new()
	player = PlayerService.new()
	decor = DecorManager.new()

func active() -> bool:
	return is_instance_valid(runner) and runner.is_running

## 对话框（暂留，后续拆到 DialogueService）
const DialogueBoxScene = preload("res://scenes/ui/dialogue_box.tscn")

func play_dialogue(lines: Array) -> float:
	if not active() or not is_instance_valid(runner): return 0.0
	var box := DialogueBoxScene.instantiate()
	runner.get_tree().current_scene.add_child(box)
	runner.is_running = false
	box.finished.connect(func(): runner.is_running = true, CONNECT_ONE_SHOT)
	box.play(lines)
	return 0.0

func dialogue_show(char_name: String, text: String, pos: Vector2 = Vector2(100, 200), portrait: Texture2D = null) -> void:
	var profile := CharacterProfile.new()
	profile.char_name = char_name
	if portrait: profile.portraits["通常"] = portrait
	var bubble := DialogueBubble.new()
	bubble.speaker = profile
	bubble.text = text
	bubble.portrait_pos = pos
	var line := DialogueLine.new()
	line.bubbles = [bubble]
	play_dialogue([line])

func get_field_rect() -> Rect2:
	if not is_instance_valid(runner): return Rect2()
	return runner.get_viewport().get_visible_rect()

func spawn_item(type: int, position: Vector2) -> void:
	if not active(): return
	var scene := runner.get_tree().current_scene
	if not scene: return
	var world := scene.get_node_or_null("World")
	if world:
		var pool := world.get_node_or_null("ItemPool")
		if pool: pool.spawn(position, type)
