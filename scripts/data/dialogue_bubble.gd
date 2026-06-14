# DialogueBubble.gd
extends Resource
class_name DialogueBubble

## 说话者
@export var speaker: CharacterProfile
## 立绘锚点位置 (左上)
@export var position: Vector2 = Vector2(100, 200)
## 内容
@export var text: String = ""
## 表情 key
@export var emotion: String = ""
