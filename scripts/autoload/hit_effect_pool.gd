extends Node
## 命中特效对象池 — 避免频繁 instantiate()/queue_free()

const POOL_SIZE := 8

var _pools: Dictionary = {}  # PackedScene → Array[HitEffect]
var _return_method: Callable


## 直接实例化（不用池），挂到 World 节点
static func spawn(scene: PackedScene, pos: Vector2, vel: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> void:
	if not scene:
		return
	var eff = scene.instantiate()
	var world = Engine.get_main_loop().current_scene.get_node_or_null("World")
	var target = world if world else Engine.get_main_loop().current_scene
	target.add_child(eff)
	eff.global_position = pos
	eff.z_index = 100
	if eff.has_method("set_tint"):
		eff.set_tint(tint)
	if eff.has_method("_setup"):
		eff._setup()


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
