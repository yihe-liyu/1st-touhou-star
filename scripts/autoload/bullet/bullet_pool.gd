# BulletPool — 子弹池管理 + 发射/回收
class_name BulletPool
extends RefCounted

const POOL_SIZE: int = 4000
const MAX_TOTAL: int = 5000  # 硬上限，超限回收最老子弹

var use_multi_mesh: bool = true

var bullet_scene = preload("res://scenes/bullet.tscn")
var active_bullets: Array = []
var bullet_pool: Array = []

var _parent  # 用于 add_child 和 get_viewport


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


func shoot(data: BulletData, pos: Vector2, direction: Vector2, override: BulletOverride = null):
	var bullet: Bullet
	
	if bullet_pool.is_empty():
		var total := active_bullets.size() + bullet_pool.size()
		if total >= MAX_TOTAL:
			# 硬上限：回收最老的活跃子弹腾位
			if active_bullets.size() > 0:
				return_bullet(active_bullets[0])
			else:
				return null
		else:
			bullet = bullet_scene.instantiate()
			if use_multi_mesh:
				bullet.get_node("Sprite2D").visible = false
			_parent.add_child(bullet)
	else:
		bullet = bullet_pool.pop_back()
	
	bullet.bind(data, direction, override)
	bullet.global_position = pos
	bullet.visible = true
	bullet.process_mode = Node.PROCESS_MODE_INHERIT
	active_bullets.append(bullet)
	
	return bullet


func shoot_player(data: BulletData, pos: Vector2, direction: Vector2, override: BulletOverride = null):
	return shoot(data, pos, direction, override)

func shoot_enemy(data: BulletData, pos: Vector2, direction: Vector2, override: BulletOverride = null):
	return shoot(data, pos, direction, override)

func shoot_bomb(data: BulletData, pos: Vector2, direction: Vector2, override: BulletOverride = null):
	return shoot(data, pos, direction, override)


func return_bullet(bullet: Bullet) -> void:
	if bullet.coroutine_movement and is_instance_valid(bullet.coroutine_movement):
		bullet.coroutine_movement.stop()
		bullet.coroutine_movement.queue_free()
		bullet.coroutine_movement = null
	for child in bullet.get_children():
		if child is MoveScript:
			child.stop()
			child.queue_free()
	bullet.visible = false
	bullet.process_mode = Node.PROCESS_MODE_DISABLED
	bullet.fog.visible = false
	bullet.fog.texture = null
	if bullet.fog.fog_finished.is_connected(bullet._on_fog_ready):
		bullet.fog.fog_finished.disconnect(bullet._on_fog_ready)
	active_bullets.erase(bullet)
	if bullet_pool.size() < POOL_SIZE:
		bullet_pool.append(bullet)
	else:
		bullet.queue_free()


func clear() -> void:
	while active_bullets.size() > 0:
		return_bullet(active_bullets[0])


func is_offscreen(pos: Vector2) -> bool:
	var r = _parent.get_viewport().get_visible_rect()
	var margin = 90.0
	return pos.x < -margin or \
		   pos.x > r.size.x + margin or \
		   pos.y < -margin or \
		   pos.y > r.size.y + margin
