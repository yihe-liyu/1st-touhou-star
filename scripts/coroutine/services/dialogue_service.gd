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

## 播放一段对话（DialogueSteps 步骤序列，台词已内联）—— 唯一入口
func play_steps(steps: Array) -> float:
	if not ctx or not ctx.active() or not is_instance_valid(ctx.runner):
		return 0.0
	var box := DialogueBoxScene.instantiate()
	ctx.runner.get_tree().current_scene.add_child(box)
	ctx.runner.pause()
	box.finished.connect(func(): ctx.runner.resume(), CONNECT_ONE_SHOT)
	box.play_steps(steps)
	return 0.0

## 兼容旧 lines 数组入口（DialogueLine 列表 → 步骤序列）
## 旧模型的行内演出属性已废弃；仅保留"谁说什么、什么表情"
func play(lines: Array) -> float:
	var d := DialogueSteps.new()
	for line in lines:
		var b: DialogueBubble = line.bubbles[0] if line.bubbles.size() > 0 else null
		if b == null or b.speaker == null:
			continue
		d.say(b.speaker, b.text, {"emotion": b.emotion})
	return play_steps(d.steps)

## 临时/动态台词（调试或运行时内容）：一句单气泡对话
## 位置由 Profile.default_pos 决定（新模型演出归 DSL 步骤）
func show(char_name: String, text: String, _pos: Vector2 = Vector2(100, 200), portrait: Texture2D = null) -> void:
	var profile := CharacterProfile.new()
	profile.char_name = char_name
	if portrait:
		profile.portraits["通常"] = portrait
	var d := DialogueSteps.new()
	d.say(profile, text)
	play_steps(d.steps)
