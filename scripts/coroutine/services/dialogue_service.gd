class_name DialogueService
extends RefCounted
## 对话服务

var ctx: StageContext

const DialogueBoxScene = preload("res://scenes/ui/dialogue_box.tscn")

func play(lines: Array) -> float:
	if not ctx or not ctx.active() or not is_instance_valid(ctx.runner):
		return 0.0
	var box := DialogueBoxScene.instantiate()
	ctx.runner.get_tree().current_scene.add_child(box)
	ctx.runner.pause()
	box.finished.connect(func(): ctx.runner.resume(), CONNECT_ONE_SHOT)
	box.play(lines)
	return 0.0

func show(char_name: String, text: String, pos: Vector2 = Vector2(100, 200), portrait: Texture2D = null) -> void:
	var profile := CharacterProfile.new()
	profile.char_name = char_name
	if portrait:
		profile.portraits["通常"] = portrait
	var bubble := DialogueBubble.new()
	bubble.speaker = profile
	bubble.text = text
	bubble.portrait_pos = pos
	var line := DialogueLine.new()
	line.bubbles = [bubble]
	play([line])
