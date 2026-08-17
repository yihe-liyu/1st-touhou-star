# DialogueData.gd
extends Resource
class_name DialogueData

## 台词库 —— 把台词文本打包成 .tres
## 格式：lines: Dictionary { id: DialogueLine }，id 对应 DIALOGUE.md 台词编号
## 演出（位置/翻转/明暗/表情切换/event 时机）由 DialogueSteps DSL 负责，不在此存储
@export var lines: Dictionary = {}  # { String: DialogueLine }
