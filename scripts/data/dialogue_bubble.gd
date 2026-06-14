# DialogueBubble.gd
extends Resource
class_name DialogueBubble

## 说话者
@export var speaker: CharacterProfile
## 站位 0=左 1=右
@export var side: int = 0
## 内容
@export var text: String = ""
## 表情 key
@export var emotion: String = ""
