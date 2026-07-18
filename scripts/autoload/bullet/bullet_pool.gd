# BulletPool - 子弹池管理 + 发射/回收
class_name BulletPool
extends RefCounted

const POOL_SIZE: int = 4000
const MAX_TOTAL: int = 5000  # 硬上限,超限回收最老子弹

var use_multi_mesh: bool = true

var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
var active_bullets: Array = []
var bullet_pool: Array = []

var _parent: Node  ## 用于 add_child 和 get_viewport


func _init() -> void:
	pass


func setup(p_parent) -> void:
	_parent = p_parent


func init_pool() -> void:
	for i in range(POOL_SIZE):
		var b = bullet_scene.instantiate()
		b.visible = false
		b.process_mode = Node.PROCESS_MODE_DISABLED
		if use_multi_mesh:
			b.get_node("Sprite2D").visible = false
		_parent.add_child(b)
		bullet_pool.append(b)


func shoot(data: BulletData, pos: Vector2, direction: Vector2):
	var bullet := _request_bullet()
	if not bullet: return null
	bullet.bind(data, direction)
	bullet.global_position = pos
	bullet.visible = true
	bullet.process_mode = Node.PROCESS_MODE_INHERIT
	active_bullets.append(bullet)
	return bullet


func request_bullet() -> Bullet:
	var bullet := _request_bullet()
	if not bullet: return null
	active_bullets.append(bullet)
	return bullet


func _request_bullet() -> Bullet:
	while not bullet_pool.is_empty():
		var b: Bullet = bullet_pool.pop_back()
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			b.visible = false
			b.process_mode = Node.PROCESS_MODE_DISABLED
			return b
	
	# 硬上限：避免无限制创建新子弹
	if bullet_pool.size() + active_bullets.size() >= MAX_TOTAL:
		return null
	
	var nb := bullet_scene.instantiate()
	if use_multi_mesh:
		nb.get_node("Sprite2D").visible = false
	_parent.add_child(nb)
	return nb


func _return_to_pool(bullet: Bullet) -> void:
	if not is_instance_valid(bullet) or bullet.is_queued_for_deletion():
		return
	if bullet.coroutine_script and is_instance_valid(bullet.coroutine_script):
		bullet.coroutine_script.stop()
		bullet.remove_child(bullet.coroutine_script)
		bullet.coroutine_script.queue_free()
		bullet.coroutine_script = null
	for child in bullet.get_children():
		if child is CoroutineScript:
			child.stop()
			bullet.remove_child(child)
			child.queue_free()
	bullet.visible = false
	bullet.is_ready = false  # 池回收重置
	bullet.velocity = Vector2.ZERO  # 防止残留速度
	bullet.process_mode = Node.PROCESS_MODE_DISABLED
	bullet.fog.visible = false
	bullet.fog.texture = null
	if bullet.fog.fog_finished.is_connected(bullet._on_fog_ready):
		bullet.fog.fog_finished.disconnect(bullet._on_fog_ready)
	if bullet_pool.size() < POOL_SIZE:
		bullet_pool.append(bullet)
	else:
		bullet.queue_free()


func return_bullet(bullet: Bullet) -> void:
	_return_to_pool(bullet)
	active_bullets.erase(bullet)


func clear() -> void:
	while active_bullets.size() > 0:
		return_bullet(active_bullets[0])


func is_offscreen(pos: Vector2) -> bool:
	var r: Rect2 = _parent.get_viewport().get_visible_rect()
	var margin: float = 90.0
	return pos.x < -margin or \
		   pos.x > r.size.x + margin or \
		   pos.y < -margin or \
		   pos.y > r.size.y + margin
