extends Resource
class_name CardDef
## 符卡定义——每张卡 = 一个可练习的相位
##
## 手动在编辑器中创建 .tres，添加到 CardRegistry，
## 按 order 排序自动显示在练习菜单中。

@export var uid: int = 0                 ## 展示用编号（0=不显示 "No.xxx"）
@export var name: String                 ## 显示名，如 "非符1" / "梦幻「幻想风穴」"
@export var stage_id: int                ## 所属关卡
## 在该关卡内的显示顺序（从 0 开始，与 BossData.phases 数组索引对齐）
@export var order: int = 0               ## 在该关卡内的显示顺序
@export var phase_data: PhaseData        ## 战斗配置（血量/脚本/时限/颜色/掉落等）
@export var boss_scene: PackedScene      ## Boss 外观场景
@export var background_scene: PackedScene ## 练习背景场景
@export_enum("全部:-1", "Easy:0", "Normal:1", "Hard:2", "Lunatic:3", "Extra:4") var difficulty: int = -1
@export_enum("全部:-1", "Reimu:0", "Marisa:1") var character: int = -1
