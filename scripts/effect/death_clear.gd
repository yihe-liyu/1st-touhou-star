extends Node2D
# 死亡弹幕清除 —— 不可见的扩大圆，碰到的子弹全部消失

@export var max_radius: float = 200.0
@export var duration: float = 0.5
@export var start_radius: float = 10.0

var _age: float = 0.0
var _cleared: Array = []  # 已清除的子弹（防重复）


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	
	var t := _age / duration
	var radius := lerpf(start_radius, max_radius, t)
	
	# 遍历所有活跃弹幕，只清敌弹
	var bullets := BulletManager.active_bullets
	for b in bullets:
		if not is_instance_valid(b) or b in _cleared:
			continue
		# 只清敌弹 (faction == FACTION_ENEMY)
		if b.faction != 1:
			continue
		if b.global_position.distance_squared_to(global_position) <= radius * radius:
			_cleared.append(b)
			BulletManager.call("return_bullet", b)
