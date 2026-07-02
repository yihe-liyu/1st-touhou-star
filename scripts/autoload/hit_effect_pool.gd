extends Node
## 命中特效对象池 — 避免频繁 instantiate()/queue_free()

const POOL_SIZE := 8

var _pools: Dictionary = {}  # PackedScene → Array[HitEffect]
var _return_method: Callable


## 从池中取一个特效实例播放，挂到 World 节点
func play(scene: PackedScene, pos: Vector2, vel: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> HitEffect:
	var effect := _acquire(scene)
	if not effect:
		return null
	
	var current: Node = Engine.get_main_loop().current_scene
	var world := current.get_node_or_null("World") if current else null
	var target := world if world else current
	if effect.get_parent() != target:
		if effect.get_parent():
			effect.reparent(target)
		else:
			target.add_child(effect)
	
	effect.z_index = 100
	effect.activate(pos, vel, tint, _return_method)
	return effect


## 从池中取一个实例：优先复用不可见的，没有则新建
func _acquire(scene: PackedScene) -> HitEffect:
	var arr: Array = _pools.get(scene, [])
	
	for i in arr.size():
		var eff: HitEffect = arr[i] as HitEffect
		if not is_instance_valid(eff):
			arr[i] = null
			continue
		if not eff.visible:
			return eff
	
	var instance := scene.instantiate()
	instance.visible = false
	var idx := arr.find(null)
	if idx >= 0:
		arr[idx] = instance
	else:
		arr.append(instance)
	_pools[scene] = arr
	return instance


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_return_method = _recycle


func clear_all_pool() -> void:
	for key in _pools:
		for eff in _pools[key]:
			if is_instance_valid(eff):
				eff.queue_free()
	_pools.clear()


func _recycle(effect: HitEffect) -> void:
	effect.visible = false
