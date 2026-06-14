# DialogueLine.gd
extends Resource
class_name DialogueLine

## 本帧在场人物 (含不说话的路人)
@export var characters: Array[CharacterProfile] = []
## 本帧气泡（可多个 → 多人齐声）
## 说话者自动从 bubbles[].speaker 收集, 其他人渲染但暗
@export var bubbles: Array[DialogueBubble] = []
