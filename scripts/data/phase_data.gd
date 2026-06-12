# PhaseData.gd
extends Resource
class_name PhaseData

@export var name: String = ""            ## 符卡名（空串=非符不显示）
@export var spell_id: int = 0             ## 记录用唯一ID，0=不记
@export var bonus: int = 0               ## 初始奖励分
@export var time_limit: float = 30.0     ## 时限（秒）
@export var hp: int = 1000               ## 血量（时符自动忽略）
@export var is_timeout_only: bool = false ## 时符：无敌、纯躲、时间到收
@export var move_script: Script          ## 移动脚本
@export var shoot_script: Script         ## 弹幕脚本
@export var background: PackedScene      ## 可选换背景
