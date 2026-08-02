## 关卡编排数据（波次表）—— 数据化编辑器的核心数据
## 工作台编辑这份数据 = 编辑关卡节奏；运行时 WaveStage 解释器按表生成敌人
class_name StageTimeline
extends Resource

## 波次：{t, name, enemy(模板名), count, interval, params(模板自定义参数), spawn_x}
@export var waves: Array[Dictionary] = []
