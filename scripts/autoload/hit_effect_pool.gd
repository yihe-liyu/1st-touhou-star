extends Node
## 命中特效对象池 — 避免频繁 instantiate()/queue_free()

const POOL_SIZE := 8

var _pools: Dictionary = {}  # PackedScene → Array[HitEffect]
var _return_method: Callable


## 直接实例化（不用池），挂到 World 节点
func spawn(scene: PackedScene, pos: Vector2, vel: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> HitEffect:
	return play(scene, pos, vel, tint)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_return_method = _recycle


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


func _acquire(scene: PackedScene) -> HitEffect:
	var arr: Array = _pools.get(scene, [])
	
	# 清理失效引用，找可复用实例
	var i := 0
	while i < arr.size():
		var eff = arr[i]
		if not is_instance_valid(eff):
			arr.remove_at(i)
			continue
		if not eff.visible:
			return eff
		i += 1
	
	var instance := scene.instantiate()
	instance.visible = false
	arr.append(instance)
	_pools[scene] = arr
	return instance


func clear_all_pool() -> void:
	for key in _pools:
		for eff in _pools[key]:
			if is_instance_valid(eff):
				eff.queue_free()
	_pools.clear()

func _recycle(effect: HitEffect) -> void:
	effect.visible = false
