class_name StageContext
extends RefCounted
## 关卡上下文 —— 协程拿这个代替 StageAPI

var clock: ClockService
var bullets: BulletService
var enemies: EnemyService
var player: PlayerService
var dialogue  ## DialogueService
var items  ## ItemService
var runner: CoroutineRunner

var _decor_mgr: DecorManager

const DialogueServiceClass = preload("res://scripts/coroutine/base/dialogue_service.gd")
const ItemServiceClass = preload("res://scripts/coroutine/base/item_service.gd")
const DecorManagerClass = preload("res://scripts/background/decor_manager.gd")

func _init(p_runner: CoroutineRunner) -> void:
	runner = p_runner
	clock = ClockService.new()
	bullets = BulletService.new()
	enemies = EnemyService.new()
	enemies.ctx = self
	player = PlayerService.new()
	dialogue = DialogueServiceClass.new()
	dialogue.ctx = self
	items = ItemServiceClass.new()
	items.ctx = self

## 装饰物管理器（树附着，懒加载）
func get_decor() -> DecorManager:
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

## 便捷属性
var decor: DecorManager:
	get: return get_decor()

func active() -> bool:
	return is_instance_valid(runner) and runner.is_running

## 对话框（便捷委托）
func play_dialogue(lines: Array) -> float:
	return dialogue.play(lines)

func dialogue_show(char_name: String, text: String, pos: Vector2 = Vector2(100, 200), portrait: Texture2D = null) -> void:
	dialogue.show(char_name, text, pos, portrait)

func get_field_rect() -> Rect2:
	if not is_instance_valid(runner): return Rect2()
	return runner.get_viewport().get_visible_rect()

## 道具（便捷委托）
func spawn_item(type: int, position: Vector2) -> void:
	items.spawn(type, position)
