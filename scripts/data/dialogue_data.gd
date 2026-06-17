# DialogueData.gd
extends Resource
class_name DialogueData

## 纯编辑器便利类 —— 把多条 DialogueLine 打包成一个 .tres
@export var lines: Array[DialogueLine] = []
