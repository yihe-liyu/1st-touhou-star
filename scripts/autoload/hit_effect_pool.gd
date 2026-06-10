extends Node
## 命中特效对象池 — 避免频繁 instantiate()/queue_free()

const POOL_SIZE := 8

var _pools: Dictionary = {}  # PackedScene → Array[HitEffect]
var _return_method: Callable


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_return_method = _recycle


## 播放一个命中特效
func play(scene: PackedScene, pos: Vector2, vel: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> HitEffect:
	var effect := _acquire(scene)
	if not effect:
		return null
	
	# 挂到当前场景（不在 pool 里渲染！）
	var current: Node = Engine.get_main_loop().current_scene
	if current and effect.get_parent() != current:
		if effect.get_parent():
			effect.reparent(current)
		else:
			current.add_child(effect)
	
	effect.activate(pos, vel, tint, _return_method)
	return effect


func _acquire(scene: PackedScene) -> HitEffect:
	var arr: Array = _pools.get(scene, [])
	
	for eff in arr:
		if not eff.visible:
			return eff
	
	var instance := scene.instantiate()
	instance.visible = false
	arr.append(instance)
	_pools[scene] = arr
	return instance


func _recycle(effect: HitEffect) -> void:
	effect.visible = false
