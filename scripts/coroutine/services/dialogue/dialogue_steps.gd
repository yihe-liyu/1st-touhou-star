class_name DialogueSteps
extends RefCounted
## 对话流程 DSL —— 构建步骤序列（Array[DialogueStep]）
##
## 用法（关卡编排里，台词直接内联——与弹幕编排同样"代码即真相"）：
##   var d := DialogueSteps.new()
##   d.enter(reimu_profile, Vector2(200, 200))
##   d.line("啊，什么线索都没有…")                    # 延续上一说话者（灵梦）
##   d.line("一般这时候就会有人出现了吧～", {"emotion": "笑"})
##   d.enter(ka_profile, Vector2(1300, 230))            # 进场后自动成为延续者
##   d.move("卡摩瑞", Vector2(550, 230), 1.0)
##   d.line("哦呀，弱小的人类怎么会在永夜出门？", {"emotion": "疑惑"})
##   d.event("bgm_switch")                              # 行间事件，时机精确
##   d.wait(0.5)
##   ctx.play_dialogue_steps(d.steps)
##
## 原则：只描述"变化"；位置/flip/明暗/表情等在状态里"声明即改变，不声明不动"。
## line() 的说话者默认延续上一句（enter 也会更新延续者），换人用 say()。

var steps: Array[DialogueStep] = []

var _current_speaker: CharacterProfile  ## line() 默认说话者（延续机制）


func _add(step: DialogueStep) -> DialogueSteps:
	steps.append(step)
	return self


## 显示一句台词（延续上一说话者；首句或换人用 say() 或 opts.speaker）
func line(text: String, opts: Dictionary = {}) -> DialogueSteps:
	var speaker: CharacterProfile = opts.get("speaker", _current_speaker)
	assert(speaker != null, "DialogueSteps.line: 需要说话者——首句请用 say(profile, text) 或传 opts.speaker")
	var line_data := _build_line(speaker, text, opts)
	var s := DialogueStep.new()
	s.type = DialogueStep.Type.LINE
	s.line_data = line_data
	_current_speaker = speaker
	return _add(s)


## 指定说话者的台词（换人/首句用）
func say(profile: CharacterProfile, text: String, opts: Dictionary = {}) -> DialogueSteps:
	opts["speaker"] = profile
	return line(text, opts)


func _build_line(speaker: CharacterProfile, text: String, opts: Dictionary) -> DialogueLine:
	var line_data := DialogueLine.new()
	var bubble := DialogueBubble.new()
	bubble.speaker = speaker
	bubble.text = text
	bubble.emotion = opts.get("emotion", "通常")
	line_data.bubbles = [bubble]
	line_data.skippable = opts.get("skippable", true)
	line_data.auto_advance = opts.get("auto_advance", 0.0)
	return line_data


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
	# 新角色进场后通常是他说下一句 → 更新延续者
	_current_speaker = profile
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


## 停顿（秒）——行间等待演出
func wait(seconds: float) -> DialogueSteps:
	var s := DialogueStep.new()
	s.type = DialogueStep.Type.WAIT
	s.duration = seconds
	return _add(s)