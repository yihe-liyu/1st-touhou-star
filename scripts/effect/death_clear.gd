extends Node2D

@export var max_radius: float = 200.0
@export var duration: float = 0.5
@export var start_radius: float = 10.0

var _age: float = 0.0
var _area: Area2D
var _shape: CircleShape2D
var _pending: Array[Area2D] = []


func _ready() -> void:
	_shape = CircleShape2D.new()
	_shape.radius = start_radius
	
	var collision := CollisionShape2D.new()
	collision.shape = _shape
	
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 4294967295
	_area.area_entered.connect(_on_area_entered)
	_area.add_child(collision)
	
	add_child(_area)


func _physics_process(delta: float) -> void:
	_age += delta
	
	# 延迟清理上一帧收集的子弹
	if not _pending.is_empty():
		for b in _pending:
			BulletManager.call("return_bullet", b)
		_pending.clear()
	
	if _age >= duration:
		queue_free()
		return
	var t := _age / duration
	_shape.radius = lerpf(start_radius, max_radius, t)


func _on_area_entered(area: Area2D) -> void:
	# 只消子弹（有 coroutine_movement 属性的才是子弹）
	if not "coroutine_movement" in area:
		return
	if not _pending.has(area):
		_pending.append(area)
