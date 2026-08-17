class_name DialogueService
extends RefCounted
## 对话服务

## 弱引用 ctx：避免 StageContext ↔ DialogueService 形成 RefCounted 环导致关卡退出后泄漏
var _ctx_ref: WeakRef
var ctx: StageContext:
	get:
		return _ctx_ref.get_ref() as StageContext if _ctx_ref else null
	set(value):
		_ctx_ref = weakref(value) if value else null

const DialogueBoxScene = preload("res://scenes/ui/dialogue_box.tscn")

## 播放一段对话（步骤序列 + 台词库）—— 新流程入口
func play_steps(steps: Array, lines: Dictionary) -> float:
	if not ctx or not ctx.active() or not is_instance_valid(ctx.runner):
		return 0.0
	var box := DialogueBoxScene.instantiate()
	ctx.runner.get_tree().current_scene.add_child(box)
	ctx.runner.pause()
	box.finished.connect(func(): ctx.runner.resume(), CONNECT_ONE_SHOT)
	box.play_steps(steps, lines)
	return 0.0

## 兼容旧 lines 数组入口：每行转成一个 LINE 步骤（id = 索引）
## 注意：旧模型的行内演出属性（portrait_pos/move_*）不再生效，迁移到 DSL 步骤
func play(lines: Array) -> float:
	var d := DialogueSteps.new()
	for i in lines.size():
		d.line(str(i))
	var lib: Dictionary = {}
	for i in lines.size():
		lib[str(i)] = lines[i]
	return play_steps(d.steps, lib)

## 临时/动态台词（调试或运行时内容）：一句单气泡对话
## 注意：pos 参数仅作兼容保留——新模型立绘位置由 DSL 步骤/Profile.default_pos 决定
func show(char_name: String, text: String, _pos: Vector2 = Vector2(100, 200), portrait: Texture2D = null) -> void:
	var profile := CharacterProfile.new()
	profile.char_name = char_name
	if portrait:
		profile.portraits["通常"] = portrait
	var bubble := DialogueBubble.new()
	bubble.speaker = profile
	bubble.text = text
	var line := DialogueLine.new()
	line.bubbles = [bubble]
	play([line])
