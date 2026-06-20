extends Resource
class_name CardDef
## 符卡定义——每张卡 = 一个可练习的相位

@export var uid: int                     ## 唯一ID
@export var name: String                 ## 符卡名称
@export var stage_id: int                ## 所属关卡
@export var boss_scene: PackedScene      ## Boss 外观容器
@export var phase_script: Script         ## 这段非符/符卡的脚本
@export var background_scene: PackedScene ## 符卡背景
@export var difficulty: int = -1         ## -1 表示通用
@export var character: int = -1          ## -1 表示通用
