# DialogueBubble.gd
extends Resource
class_name DialogueBubble

enum Side { LEFT = 0, RIGHT = 1 }

## 说话者
@export var speaker: CharacterProfile
## 站位 LEFT=0 左列, RIGHT=1 右列
@export var side: int = Side.LEFT
## 内容
@export var text: String = ""
## 表情 key
@export var emotion: String = ""
