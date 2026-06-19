class_name ItemService
extends RefCounted
## 道具服务

var ctx: StageContext

func spawn(type: int, position: Vector2) -> void:
	if not ctx or not ctx.active():
		return
	var scene := ctx.runner.get_tree().current_scene
	if not scene: return
	var world := scene.get_node_or_null("World")
	if world:
		var pool := world.get_node_or_null("ItemPool")
		if pool: pool.spawn(position, type)
