extends CoroutineScript
## 非符1 移动：正弦波左右飘移，两端缓慢，中间最快
## auto_stop = false（持续运行直到 phase 结束）

var _center: float = 448.0     # 中心 x
var _amplitude: float = 200.0  # 振幅（左右各 200px）
var _period: float = 6.0       # 一个来回的周期（秒）
var _timer: float = 0.0


func _tick(_ctx: StageContext):
	if not target: return true
	
	_timer += get_physics_process_delta_time()
	
	# sin: 两端导数最小（慢），中心导数最大（快）= 自然加减速
	target.global_position.x = _center + sin(_timer * TAU / _period) * _amplitude
	
	return true  # 每帧都跑
