# PhaseData.gd
extends Resource
class_name PhaseData

@export var name: String = ""
@export var spell_id: String = ""    # 记录用唯一ID，空串不记录
@export var bonus: int = 0
@export var time_limit: float = 30.0
@export var hp: int = 1000
@export var is_timeout_only: bool = false
@export var move_script: Script
@export var shoot_script: Script
@export var background: PackedScene
