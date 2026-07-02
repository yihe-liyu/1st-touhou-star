# DialogueBubble.gd
extends Resource
class_name DialogueBubble

## 说话者
@export var speaker: CharacterProfile
## 立绘锚点位置 (左上)
@export var portrait_pos: Vector2 = Vector2(50.0, 230.0)
## 是否移动立绘到此位置（否则保持原位）
@export var move_portrait: bool = false
## 是否移动气泡到此偏移（否则保持原位）
@export var move_bubble: bool = false
## 内容
@export_multiline var text: String = ""
## 表情 key
@export var emotion: String = "通常"
## 气泡相对立绘的偏移（默认右侧对齐顶部）
@export var bubble_offset: Vector2 = Vector2(-220.0, 250.0)
