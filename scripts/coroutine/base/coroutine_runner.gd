extends Node
class_name CoroutineRunner
## 协程调度器 —— 所有任务在 _physics_process 里步进
##
## 每个任务是一个 callable，每帧被调用，返回值约定：
##   float/int > 0  → 等待这么秒后再次调用
##   true           → 下帧立即再次调用（等价于等待 0 帧）
##   false / null   → 任务结束，移除
##
## run()      — 先清掉所有旧任务再启动
## run_parallel() — 追加一个并行任务
##
## 计时方式：累积 _physics_process 的 delta，暂停时不累积。
## 恢复后不会追帧，时钟从暂停处继续。

signal finished()
signal cancelled()

var is_running: bool = false
var _tasks: Array[Task] = []
var _clock: float = 0.0  # 游戏内时间（物理帧累积，暂停时冻结）

class Task extends RefCounted:
	var callable: Callable
	var wake_time: float = 0.0


func run(method: Callable):
	stop()
	_clock = 0.0
	_start_task(method)

func run_parallel(method: Callable):
	_start_task(method)

func _start_task(method: Callable):
	var task := Task.new()
	task.callable = method
	task.wake_time = _clock  # 第一帧立即执行
	_tasks.append(task)
	is_running = true

func stop():
	if not is_running:
		return
	for task in _tasks:
		task.callable = Callable()
	_tasks.clear()
	is_running = false
	cancelled.emit()

func _physics_process(delta: float) -> void:
	_clock += delta
	
	for i in range(_tasks.size() - 1, -1, -1):
		var task := _tasks[i]
		if not task.callable.is_valid():
			_tasks.remove_at(i)
			continue

		if task.wake_time > _clock:
			continue

		var result = task.callable.call()

		if typeof(result) == TYPE_FLOAT or typeof(result) == TYPE_INT:
			if result > 0:
				task.wake_time = _clock + result
			else:
				_tasks.remove_at(i)
		elif result == true:
			pass  # 下帧立即再次调用
		else:
			_tasks.remove_at(i)

	if _tasks.is_empty() and is_running:
		is_running = false
		finished.emit()

func _exit_tree():
	stop()
