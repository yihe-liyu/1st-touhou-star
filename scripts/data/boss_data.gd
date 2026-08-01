## Boss 定义：名称 + 视觉 + 阶段列表（构造链）
extends Resource
class_name BossData

var boss_name: String = ""
var visual: PackedScene
var phases: Array[PhaseData] = []
var score_value: int = 10000
var hitbox_radius: float = 36.0

## ── 构造链 ──

func name(v: String) -> BossData:       boss_name = v; return self
func look(v: PackedScene) -> BossData:  visual = v; return self
func phase(v: PhaseData) -> BossData:   phases.append(v); return self
func score(v: int) -> BossData:         score_value = v; return self
func hitbox(v: float) -> BossData:       hitbox_radius = v; return self


## 配置校验：逐个校验 phases。返回错误列表（空 = 合法）
func validate() -> Array[String]:
	var errs: Array[String] = []
	if phases.is_empty():
		errs.append("BossData[%s] 没有 phases（空 Boss）" % boss_name)
	for i in phases.size():
		if phases[i] == null:
			errs.append("BossData[%s] phases[%d] 为空" % [boss_name, i])
		else:
			errs.append_array(phases[i].validate())
	return errs
