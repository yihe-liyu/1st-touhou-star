extends Node2D
# 死亡弹幕清除 —— 不可见的扩大圆，碰到的子弹全部消失

@export var max_radius: float = 1200.0
@export var duration: float = 1.0
@export var start_radius: float = 10.0

var _age: float = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	
	var t := _age / duration
	var radius := lerpf(start_radius, max_radius, t)
	
	# 遍历所有活跃敌弹，先收集再清理（避改数组迭代问题）
	var to_clear: Array = []
	for b in BulletManager.active_bullets:
		if not is_instance_valid(b) or b.faction != 1:
			continue
		if b.global_position.distance_squared_to(global_position) <= radius * radius:
			to_clear.append(b)
	
	for b in to_clear:
		BulletManager.call("return_bullet", b)
