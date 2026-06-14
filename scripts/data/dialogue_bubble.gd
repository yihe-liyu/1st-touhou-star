# DialogueBubble.gd
extends Resource
class_name DialogueBubble

enum Side { LEFT = 0, RIGHT = 1 }

## 说话者
@export var speaker: CharacterProfile
## 站位
@export_enum("LEFT:0", "RIGHT:1") var side: int = Side.LEFT
## 内容
@export var text: String = ""
## 表情 key
@export var emotion: String = ""
