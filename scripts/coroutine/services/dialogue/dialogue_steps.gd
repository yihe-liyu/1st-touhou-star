class_name DialogueSteps
extends RefCounted
## 对话流程 DSL —— 构建步骤序列（Array[DialogueStep]）
##
## 用法（关卡编排里）：
##   var d := DialogueSteps.new()
##   d.enter(reimu_profile, Vector2(200, 200))
##   d.line("r1")
##   d.event("bgm_switch")
##   d.wait(0.5)
##   tl.at(92).dialogue_steps(d.steps, lines_dict)   # 播放器/runner 接入
##
## 原则：只描述"变化"；位置/flip/明暗/表情等在状态里"声明即改变，不声明不动"

var steps: Array[DialogueStep] = []


func _add(step: DialogueStep) -> DialogueSteps:
	steps.append(step)
	return self


## 显示一句：内容从台词库按 id 取（本 DSL 只记 id）
func line(line_id: String, opts: Dictionary = {}) -> DialogueSteps:
	var s := DialogueStep.new()
	s.type = DialogueStep.Type.LINE
	s.line_id = line_id
	s.opts = opts
	return _add(s)


## 登场：profile 决定立绘/表情集；opts 可带 flip/dim/emotion
func enter(profile: CharacterProfile, pos: Vector2, opts: Dictionary = {}) -> DialogueSteps:
	var s := DialogueStep.new()
	s.type = DialogueStep.Type.ENTER
	s.profile = profile
	s.char_name = profile.char_name
	s.pos = pos
	s.flip = opts.get("flip", false)
	s.light = opts.get("dim", 1.0)
	s.emotion = opts.get("emotion", "通常")
	return _add(s)


## 退场
func exit(char_name: String) -> DialogueSteps:
	var s := DialogueStep.new()
	s.type = DialogueStep.Type.EXIT
	s.char_name = char_name
	return _add(s)


## 移动立绘（可选时长，秒）
func move(char_name: String, pos: Vector2, duration: float = 0.0) -> DialogueSteps:
	var s := DialogueStep.new()
	s.type = DialogueStep.Type.MOVE
	s.char_name = char_name
	s.pos = pos
	s.duration = duration
	return _add(s)


## 水平翻转
func flip(char_name: String, flipped: bool) -> DialogueSteps:
	var s := DialogueStep.new()
	s.type = DialogueStep.Type.FLIP
	s.char_name = char_name
	s.flip = flipped
	return _add(s)


## 手动明暗（0~1）
func dim(char_name: String, value: float) -> DialogueSteps:
	var s := DialogueStep.new()
	s.type = DialogueStep.Type.DIM
	s.char_name = char_name
	s.light = value
	return _add(s)


## 换表情（立绘 key）
func portrait(char_name: String, emotion_key: String) -> DialogueSteps:
	var s := DialogueStep.new()
	s.type = DialogueStep.Type.PORTRAIT
	s.char_name = char_name
	s.emotion = emotion_key
	return _add(s)


## 调气泡偏移
func bubble(char_name: String, offset: Vector2) -> DialogueSteps:
	var s := DialogueStep.new()
	s.type = DialogueStep.Type.BUBBLE
	s.char_name = char_name
	s.bubble_offset = offset
	return _add(s)


## 行间事件（时机精确：出现在步骤序列的任意位置）
func event(event_key: String) -> DialogueSteps:
	var s := DialogueStep.new()
	s.type = DialogueStep.Type.EVENT
	s.event_key = event_key
	return _add(s)


## 停顿（秒）——替代旧模型 auto_advance 的行间等待
func wait(seconds: float) -> DialogueSteps:
	var s := DialogueStep.new()
	s.type = DialogueStep.Type.WAIT
	s.duration = seconds
	return _add(s)
