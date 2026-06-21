# PhaseData.gd
## 一个战斗阶段（非符/符卡）的配置：血量、时限、脚本、掉落
extends Resource
class_name PhaseData

@export var name: String = ""            ## 符卡名（空串=非符）
@export var uid: int = 0                  ## 全局唯一符卡编号，0=非符不记
@export var bonus: int = 0               ## 初始奖励分
@export var time_limit: float = 30.0     ## 时限（秒）
@export var hp: int = 1000               ## 血量
@export var is_timeout_only: bool = false ## 时符
@export var move_script: Script
@export var shoot_script: Script
@export var background: PackedScene      ## 可选换背景
@export var item_power: int = 0         ## 击破掉落 P 点
@export var item_point: int = 0         ## 击破掉落蓝点
@export var item_life: int = 0          ## 击破掉落残机碎片
@export var item_bomb: int = 0          ## 击破掉落 Bomb 碎片
@export var item_life_full: int = 0     ## 击破掉落整残
@export var item_bomb_full: int = 0     ## 击破掉落整 B
