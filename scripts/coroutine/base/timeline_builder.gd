class_name TimelineBuilder
extends RefCounted
## 流畅构建器 —— 链式编排 Timeline
##
## 不会被直接 new，由 Timeline.at() / Timeline.every() 返回

var _tl: Timeline
var _time: float
var _every: float = -1.0
var _every_times: int = -1

func _init(tl: Timeline, p_time: float) -> void:
	_tl = tl
	_time = p_time


# ═══ 时间锚点 ═══

func at(time: float) -> TimelineBuilder:
	_time = time
	_every = -1.0
	return self

## 开始一个重复节拍：后续 call() 生成的事件每 interval 秒重复
func every(interval: float) -> TimelineBuilder:
	_every = interval
	return self


# ═══ 演出动作 ═══

## 限制 every 重复次数
func times(n: int) -> TimelineBuilder:
	_every_times = n
	return self

func call(cb: Callable) -> TimelineBuilder:
	_tl.add_event(_time, cb, _every, _every_times)
	return self

func callv(cb: Callable, args: Array) -> TimelineBuilder:
	var ev := _tl.add_event(_time, cb, _every, _every_times)
	ev.args = args
	return self


# ═══ 便捷方法（委托 ctx） ═══

func spawn_wave(data: BulletData, count: int, spread: float, dir: Vector2, at_pos: Vector2) -> TimelineBuilder:
	return call(func(): _tl.ctx.bullets.shoot_spread(data, count, spread, dir, at_pos))

func spawn_enemy(data: EnemyData, pos: Vector2) -> TimelineBuilder:
	return call(func(): _tl.ctx.enemies.spawn_enemy(data, pos))

func spawn_boss(data: BossData, pos: Vector2) -> TimelineBuilder:
	return call(func(): _tl.ctx.enemies.spawn_boss(data, pos))

func play_bgm(path: String) -> TimelineBuilder:
	return call(func(): AudioManager.play_bgm(load(path), 0.0))

func fire_straight_laser(data: Resource, origin: Vector2, dir: Vector2, length: float) -> TimelineBuilder:
	return call(func(): _tl.ctx.bullets.fire_straight_laser(data, origin, dir, length))

func play_dialogue(dialogue_data) -> TimelineBuilder:
	return call(func(): _tl.ctx.play_dialogue(dialogue_data.lines))


# ═══ 控制 ═══

## 标记循环：所有一次性事件触发完毕后从头再来
func loop() -> Timeline:
	_tl.loop()
	return _tl
