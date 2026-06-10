extends Node
## 命中特效对象池 — 避免频繁 instantiate()/queue_free()
##
## 用法:
##   HitEffectPool.play(preload("res://scenes/effect/hit_effect_reimu.tscn"), pos, vel, tint)
##
## 特效播完后自动回收，不删除节点。

## 每种场景预创建数量
const POOL_SIZE := 8

var _pools: Dictionary = {}  # PackedScene → Array[HitEffect]
var _return_method: Callable


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_return_method = _recycle


## 播放一个命中特效
func play(scene: PackedScene, pos: Vector2, vel: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> HitEffect:
	var effect := _acquire(scene)
	if effect:
		effect.activate(pos, vel, tint, _return_method)
	return effect


## 预创建指定场景的池（可选，不调用也自动创建）
func prewarm(scene: PackedScene, count: int = POOL_SIZE) -> void:
	var arr: Array = _pools.get(scene, [])
	var existing := arr.size()
	for i in range(maxi(count - existing, 0)):
		var instance := scene.instantiate()
		instance.visible = false
		add_child(instance)
		arr.append(instance)
	_pools[scene] = arr


func _acquire(scene: PackedScene) -> HitEffect:
	var arr: Array = _pools.get(scene, [])
	
	# 找空闲的
	for eff in arr:
		if not eff.visible:
			return eff
	
	# 池空 → 即时扩展
	var instance := scene.instantiate()
	instance.visible = false
	add_child(instance)
	arr.append(instance)
	_pools[scene] = arr
	return instance


func _recycle(effect: HitEffect) -> void:
	# 已经在 pool 里，只标记不可见
	effect.visible = false
