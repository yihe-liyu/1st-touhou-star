extends Node
## 可复现随机数（replay 基础）。所有随机数必须走 RNG，不要用全局 randf()/randi()。

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready():
	_rng.randomize()

func set_seed(s: int) -> void:
	_rng.seed = s

## 重新随机化种子（工作台关闭"固定种子"时调用）
func randomize_seed() -> void:
	_rng.randomize()

func get_seed() -> int:
	return _rng.seed

func randf() -> float:
	return _rng.randf()

func randi() -> int:
	return _rng.randi()

func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func randfn(mean: float = 0.0, deviation: float = 1.0) -> float:
	return _rng.randfn(mean, deviation)
