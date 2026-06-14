# DialogueLine.gd
extends Resource
class_name DialogueLine

## 本帧在场人物
@export var characters: Array[CharacterProfile] = []
## 本帧气泡（可多个 → 多人齐声）
@export var bubbles: Array[DialogueBubble] = []
