extends Resource
class_name WaveData

enum TriggerCondition {TIMED = 0, ALL_DEFEATED = 1}

## 敌人配置数据
@export var enemy_data: EnemyData
## 单次生成数量（同一波内连续出几个敌人）
@export var spawn_count: int = 1
## 同波内连续生成间隔（秒）。0 = 一次性全部生成
@export var spawn_interval: float = 0.0
## 默认出场位置（spawn_positions 为空时使用）
@export var spawn_position: Vector2 = Vector2(640, 100)
## 多个出场位置列表。spawn_count > positions 时循环复用。非空时覆盖 spawn_position
@export var spawn_positions: Array[Vector2] = []
## 入场延迟（秒）——波开始后等多久才刷第一个敌人
@export var spawn_delay: float = 0.0
## 触发条件（TIMED=计时推进, ALL_DEFEATED=全灭推进）
@export var trigger_condition: TriggerCondition = TriggerCondition.TIMED
## 计时触发的秒数（仅 trigger_condition=TIMED 时有效）
@export var trigger_time: float = 3.0
## 移动模式脚本（预留）
@export var move_pattern: Script
## 脚本驱动字段。存在时 LevelManager 将波次控制权交给此脚本，跳过机械生成
@export var stage_script: Script
