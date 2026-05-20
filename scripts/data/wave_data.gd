extends Resource
class_name WaveData

enum TriggerCondition { TIMED = 0, ALL_DEFEATED = 1 }

## 敌人配置数据
@export var enemy_data: EnemyData
## 生成位置
@export var spawn_position: Vector2 = Vector2(640, 100)
## 入场延迟（秒）
@export var spawn_delay: float = 0.0
## 触发条件（0=计时, 1=前一波全灭）
@export var trigger_condition: int = 0
## 计时触发的秒数（仅 trigger_condition=0 时有效）
@export var trigger_time: float = 3.0
## 移动模式脚本（预留）
@export var move_pattern: Script
