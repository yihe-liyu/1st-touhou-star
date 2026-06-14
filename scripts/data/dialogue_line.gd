# DialogueLine.gd
extends Resource
class_name DialogueLine

## 本帧在场人物 + 站位
@export var positions: Array[DialoguePosition] = []
## 本帧气泡（可多个 → 多人齐声）
@export var bubbles: Array[DialogueBubble] = []
