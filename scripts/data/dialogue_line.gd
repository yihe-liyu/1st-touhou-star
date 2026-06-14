# DialogueLine.gd
extends Resource
class_name DialogueLine

## 左侧角色列表（纵向栈叠）
@export var left_chars: Array[DialogueCharacter] = []
## 右侧角色列表（纵向栈叠）
@export var right_chars: Array[DialogueCharacter] = []
## 说话内容
@export var text: String = ""
## 说话者索引: [0]=左栏第1人, [3]=右栏第2人... 从0起,左栏先排,右栏接后
@export var speakers: Array[int] = []
