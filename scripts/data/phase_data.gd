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
## 弹幕蓝图（数据驱动，可选）：空 = 用 shoot_script（向后兼容）；非空 = PatternDriver 解释
@export var patterns: Array[BulletPattern] = []
@export var background: PackedScene      ## 可选换背景
@export var item_power: int = 0         ## 击破掉落 P 点
@export var item_point: int = 0         ## 击破掉落蓝点
@export var item_life: int = 0          ## 击破掉落残机碎片
@export var item_bomb: int = 0          ## 击破掉落 Bomb 碎片
@export var item_life_full: int = 0     ## 击破掉落整残
@export var item_bomb_full: int = 0     ## 击破掉落整 B


## 配置校验：返回错误列表（空 = 合法）。加载/开战前调用，防除零
## 注意：不校验脚本（纯移动/演示阶段可能无脚本，属合法）
func validate() -> Array[String]:
	var errs: Array[String] = []
	if time_limit <= 0.0:
		errs.append("PhaseData[%s].time_limit = %s 必须 > 0（会除零/立即超时）" % [name, time_limit])
	if hp <= 0:
		errs.append("PhaseData[%s].hp = %s 必须 > 0" % [name, hp])
	return errs
