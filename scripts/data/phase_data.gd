# PhaseData.gd
extends Resource
class_name PhaseData

@export var name: String = ""            ## 符卡名（空串=非符，练习菜单忽略此项）
@export var spell_names: Array[String] = [] ## 各难度符卡名 [Easy, Normal, Hard, Lunatic, Extra]
@export var uid: int = 0                  ## 全局唯一符卡编号，0=非符不记
@export var bonus: int = 0               ## 初始奖励分
@export var time_limit: float = 30.0     ## 时限（秒）
@export var hp: int = 1000               ## 血量
@export var is_timeout_only: bool = false ## 时符：无敌、纯躲、时间到收
@export var move_scripts: Array[Script] = []  ## 各难度移动脚本
@export var shoot_scripts: Array[Script] = [] ## 各难度弹幕脚本
@export var background: PackedScene      ## 可选换背景
