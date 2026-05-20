extends Resource
class_name WaveData

## 敌人配置数据（供波次脚本引用）
@export var enemy_data: EnemyData
## 协程波次脚本（WaveScript 子类）。关卡开始时自动实例化并运行其 _on_run(api)
@export var wave_script: Script
