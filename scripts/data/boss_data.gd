## Boss 定义：名称 + 视觉 + 阶段列表（构造链）
extends Resource
class_name BossData

var boss_name: String = ""
var visual: PackedScene
var phases: Array[PhaseData] = []
var score_value: int = 10000

## ── 构造链 ──

func name(v: String) -> BossData:       boss_name = v; return self
func look(v: PackedScene) -> BossData:  visual = v; return self
func phase(v: PhaseData) -> BossData:   phases.append(v); return self
func score(v: int) -> BossData:         score_value = v; return self
