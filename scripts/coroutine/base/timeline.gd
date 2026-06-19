class_name Timeline
extends RefCounted
## 时间线 —— 声明式替代 match _phase 状态机
##
## 用法：
##   var tl := Timeline.new(ctx)
##   tl.at(0.0).call(_init_fog) \
##     .at(2.0).spawn_wave(data, pos, 12) \
##     .at(5.0).every(1.5).call(_check_and_shoot) \
##     .at(10.0).spawn_boss(boss, pos) \
##     .loop()
##
##   func _on_step(_ctx): return tl.tick(_ctx.clock.delta)

var ctx: StageContext
var _events: Array[TimelineEvent] = []
var _elapsed: float = 0.0
var _paused: bool = false
var _loop_start: float = -1.0

func _init(p_ctx: StageContext) -> void:
	ctx = p_ctx


# ═══ 构建 ═══

## 在指定时间点准备一个事件（链式）
func at(time: float) -> TimelineBuilder:
	return TimelineBuilder.new(self, time)

## 开始一段 every 块（链式）
func every(interval: float) -> TimelineBuilder:
	return TimelineBuilder.new(self, -1.0).every(interval)

func add_event(time: float, cb: Callable, every_interval: float = -1.0, times: int = -1) -> TimelineEvent:
	var ev := TimelineEvent.new(time, cb, every_interval, times)
	_events.append(ev)
	return ev


# ═══ 运行 ═══

## 每帧推时间，触发到期事件。返回 true=继续，false=所有一次性事件均已触发完毕
func tick(delta: float) -> bool:
	if _paused:
		return true
	_elapsed += delta
	
	var any_fired := false
	for ev in _events:
		if ev.fired and ev.repeat_every <= 0:
			continue
		if _elapsed >= ev.time:
			ev.execute()
			any_fired = true
			if ev.repeat_every > 0:
				ev.time += ev.repeat_every
				ev._repeat_count += 1
				if ev.repeat_times > 0 and ev._repeat_count >= ev.repeat_times:
					ev.fired = true
			else:
				ev.fired = true
	
	# 循环：重置所有一次性事件
	if _loop_start >= 0 and _all_onetime_fired():
		_reset_onetime()
		_elapsed = _loop_start
	
	if not any_fired:
		return _events.any(func(e): return not e.fired or e.repeat_every > 0)
	return true


func _all_onetime_fired() -> bool:
	for ev in _events:
		if ev.repeat_every <= 0 and not ev.fired:
			return false
	return true

func _reset_onetime() -> void:
	for ev in _events:
		if ev.repeat_every <= 0:
			ev.fired = false
			ev.time -= _loop_start  # 偏移回原始时间


func pause() -> void: _paused = true
func resume() -> void: _paused = false

func reset() -> void:
	_elapsed = 0.0
	for ev in _events:
		ev.fired = false

## 跳到指定时间，重置该时间前所有事件
func seek(time: float) -> void:
	_elapsed = time
	for ev in _events:
		ev.fired = ev.time <= time and ev.repeat_every <= 0

func is_running() -> bool:
	return _events.any(func(e): return not e.fired or e.repeat_every > 0)

## 标记循环起点（在最后一个 at() 后调用）
func loop() -> void:
	if _events.is_empty(): return
	_loop_start = _events.back().time
