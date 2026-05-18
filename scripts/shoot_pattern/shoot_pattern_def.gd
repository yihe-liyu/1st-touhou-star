extends Resource
class_name ShootPatternDef

## 发射的子弹原始模板
@export var bullet_data: BulletData
## 射击间隔（秒）。0.05=每秒 20 轮
@export var interval: float = 0.05
## 模式持续时间（秒）。-1=无限, >0 到时自动切换到 next_def 或停止
@export var duration: float = -1.0
## 结束后自动切换的下一个弹幕模式（留空则停止）
@export var next_def: ShootPatternDef
## 此模式的运行时执行器脚本（如 ShootCircleExecutor）
@export var executor_script: Script
