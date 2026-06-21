class_name Timeline
extends RefCounted
## 时间线 —— 声明式替代 match _phase 状态机
##
##   var tl := Timeline.new(ctx)
##   tl.at(0.0).call(_bgm)
##   tl.at(2.0).every(1.5).times(4).call(_wave)
##   tl.at(10.0).spawn_boss(boss, pos)
##   tl.loop()
##
##   func _on_step(_ctx): return tl.tick(_ctx.clock.delta)

var ctx: StageContext
var _events: Array[TimelineEvent] = []
var _elapsed: float = 0.0
var _paused: bool = false
var _loop_start: float = -1.0

# builder state
var _time: float = -1.0
var _every: float = -1.0
var _times: int = -1


func _init(p_ctx: StageContext) -> void:
	ctx = p_ctx


# ═══ 构建器 ═══

func at(t: float) -> Timeline:
	_time = t
	_every = -1.0
	_times = -1
	return self

func every(interval: float) -> Timeline:
	_every = interval
	return self

func times(n: int) -> Timeline:
	_times = n
	return self

func do(cb: Callable) -> Timeline:
	_add(_time, cb, _every, _times)
	return self

func spawn_wave(data: BulletData, count: int, spread: float, dir: Vector2, at_pos: Vector2) -> Timeline:
	return do(func(): ctx.bullets.shoot_spread(data, count, spread, dir, at_pos))

func spawn_enemy(key: String, pos: Vector2) -> Timeline:
	return do(func(): ctx.enemies.spawn(key, pos).spawn())

func spawn_boss(data: BossData, pos: Vector2) -> Timeline:
	return do(func(): ctx.enemies.spawn_boss(data, pos))

func play_bgm(stream: AudioStream) -> Timeline:
	return do(func(): ctx.audio.play_bgm(stream))

func play_dialogue(dialogue_data) -> Timeline:
	return do(func(): ctx.play_dialogue(dialogue_data.lines))


# ═══ 内部 ═══

func _add(t: float, cb: Callable, ev: float = -1.0, n: int = -1) -> void:
	_events.append(TimelineEvent.new(t, cb, ev, n))


# ═══ 运行 ═══

func tick(delta: float) -> bool:
	if _paused:
		return true
	_elapsed += delta
	
	for ev in _events:
		if ev.fired and ev.repeat_every < 0:
			continue
		if _elapsed >= ev.time:
			ev.execute()
			if ev.repeat_every >= 0:
				ev.time += ev.repeat_every
				ev.fired_count += 1
				if ev.repeat_times > 0 and ev.fired_count >= ev.repeat_times:
					ev.fired = true
					ev.repeat_every = -1.0
			else:
				ev.fired = true
	
	if _loop_start >= 0 and _elapsed >= _loop_start and _all_onetime_fired():
		_reset_onetime()
		_elapsed = _loop_start
	
	return _events.any(func(e): return not e.fired) or _loop_start >= 0


func _all_onetime_fired() -> bool:
	for ev in _events:
		if not ev.fired:
			return false
	return true

func _reset_onetime() -> void:
	for ev in _events:
		ev.fired = false
		ev.time = _elapsed + ev._original_time
		ev.fired_count = 0


func pause() -> void: _paused = true
func resume() -> void: _paused = false

func reset() -> void:
	_elapsed = 0.0
	for ev in _events:
		ev.fired = false

func seek(time: float) -> void:
	_elapsed = time
	for ev in _events:
		ev.fired = ev.time <= time and ev.repeat_every <= 0

func loop() -> void:
	if _events.is_empty(): return
	_loop_start = _events.back().time
