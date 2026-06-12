extends Area2D
class_name Item

enum Type { POWER, POINT, LIFE_FRAGMENT, BOMB_FRAGMENT, LIFE_FULL, BOMB_FULL }

var item_type: Type = Type.POINT
var value: int = 100
var _velocity: Vector2
var _gravity: float = 240.0
var _max_fall_speed: float = 180.0
var _collect_speed: float = 800.0
var _auto_collect: bool = false
var _auto_collect_line: float = 256.0
var _proximity_range: float = 128.0  # 靠近自机即吸
var _dead: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

## 吸附半径（像素）
var collect_radius: float = 32.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	if _collision and _collision.shape is CircleShape2D:
		(_collision.shape as CircleShape2D).radius = collect_radius

func setup(type: Type, pos: Vector2) -> void:
	_dead = false
	item_type = type
	global_position = pos
	_velocity = Vector2(0, -180)  # 上抛初速
	_auto_collect = false
	
	match type:
		Type.POWER:
			_sprite.texture = preload("res://assets/Textures/item/power.png")
		Type.POINT:
			_sprite.texture = preload("res://assets/Textures/item/point.png")
		Type.LIFE_FRAGMENT:
			_sprite.texture = preload("res://assets/Textures/item/life_part.png")
		Type.BOMB_FRAGMENT:
			_sprite.texture = preload("res://assets/Textures/item/spell_part.png")
		Type.LIFE_FULL:
			_sprite.texture = preload("res://assets/Textures/item/life_full.png")
		Type.BOMB_FULL:
			_sprite.texture = preload("res://assets/Textures/item/spell_full.png")
	_sprite.modulate = Color.WHITE


func _physics_process(delta: float) -> void:
	if _dead:
		return
	
	var player := GameState.player
	var to_player := player.global_position - global_position if player and is_instance_valid(player) else Vector2.ZERO
	
	# 玩家过收点线 或 靠近自机 → 自动吸附（focus 时范围翻倍）
	if player and is_instance_valid(player):
		var prox := _proximity_range * 1.5 if player.is_focused else _proximity_range
		if player.global_position.y < _auto_collect_line or to_player.length() < prox:
			_auto_collect = true
	
	if _auto_collect and player and is_instance_valid(player):
		var dir := to_player.normalized()
		global_position += dir * _collect_speed * delta
	else:
		# 重力 + 终端速度
		_velocity.y = min(_velocity.y + _gravity * delta, _max_fall_speed)
		global_position += _velocity * delta
	
	# 出屏回收
	if global_position.y > 960:
		_dead = true
		set_physics_process(false)
		_recycle()

func _on_area_entered(area: Area2D) -> void:
	if _dead:
		return
	if area is Player:
		collect()


func collect() -> void:
	if _dead:
		return
	_dead = true
	visible = false
	set_physics_process(false)
	match item_type:
		Type.POWER:
			GameState.add_power(1)
		Type.POINT:
			GameState.add_max_point()
		Type.LIFE_FRAGMENT:
			GameState.collect_life_fragment()
		Type.BOMB_FRAGMENT:
			GameState.collect_bomb_fragment()
		Type.LIFE_FULL:
			GameState.collect_life_full()
		Type.BOMB_FULL:
			GameState.collect_bomb_full()
	_recycle()

func _recycle() -> void:
	var pool := get_parent()
	if pool and pool.has_method("recycle"):
		pool.recycle(self)
