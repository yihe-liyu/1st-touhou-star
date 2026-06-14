# DialogueLine.gd
extends Resource
class_name DialogueLine

## 本帧气泡（可多个 → 多人齐声）
## 在场人物从 bubbles[].speaker 自动收集, 站位由 bubbles[].side 决定
@export var bubbles: Array[DialogueBubble] = []
