extends Node
## Item 对象池，挂在 World 下

const ITEM_SCENE = preload("res://scenes/item.tscn")
const POOL_SIZE := 64

var _pool: Array[Item] = []


func _ready() -> void:
	for i in range(POOL_SIZE):
		var item: Item = ITEM_SCENE.instantiate() as Item
		item.set_physics_process(false)
		item.visible = false
		add_child(item)
		_pool.append(item)


func spawn(pos: Vector2, type: int) -> Item:
	# 定位日志：任何道具生成都记录（游戏时间/位置/类型）——用户跑游戏贴日志定位
	if StageManager.current_stage_script():
		var log_t := StageManager.current_stage_script().game_time()
		var type_name := Item.Type.keys()[type] if type >= 0 and type < Item.Type.keys().size() else "?%d" % type
		print("[Item生成] t=%.1f pos=%s type=%s" % [log_t, pos, type_name])
	var item: Item
	if _pool.is_empty():
		item = ITEM_SCENE.instantiate() as Item
		if not item:
			return null
		add_child(item)
	else:
		item = _pool.pop_back()
		if not is_instance_valid(item):
			item = ITEM_SCENE.instantiate() as Item
			if not item:
				return null
			add_child(item)
		elif not item.is_inside_tree():
			add_child(item)
	
	item.setup(type, pos)
	item.visible = true
	item.set_physics_process(true)
	return item


func recycle(item: Item) -> void:
	if not is_instance_valid(item):
		return
	if item in _pool:
		return  # 已在池中，防重复
	item.visible = false
	item.set_physics_process(false)
	if _pool.size() < POOL_SIZE:
		_pool.append(item)
	else:
		item.queue_free()
