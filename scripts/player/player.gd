# entities/player/player.gd
extends Area2D
class_name Player

const MIN_MARGIN: float = 8.0

const IDLE = "idle"
const LEFTING = "lefting"
const LEFT = "left"
const RIGHTING = "righting"
const RIGHT = "right"
var anim_state: String = IDLE

var input_vector: Vector2 = Vector2.ZERO
var is_focused: bool = false
var is_invincible: bool = false

var hitbox_radius: float = 5.0

@onready var hitpoint_display: HitPointDisplay = $HitPointDisplay
@onready var muzzle: Marker2D = $Muzzle

# @export 的机体数据
@export var player_data: PlayerData
var shoot_timer: float = 0.0
var options: Array = []		# 子机

# 移动速度（像素/秒）
var focus_speed: int
var normal_speed: int
var current_speed: int

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# 连接 animation_finished 信号，用于检测一次性动画播完
	sprite.animation_finished.connect(_on_animation_finished)

	_apply_player_data()

# 应用机体数据
func _apply_player_data() -> void:
	if player_data == null:
		push_error("Player: 未设置 PlayerData 资源！")
		return

	focus_speed = player_data.focus_speed
	normal_speed = player_data.normal_speed
	current_speed = normal_speed

	if sprite and player_data.animation:
		sprite.sprite_frames = player_data.animation
		sprite.play("idle")

	GameState.player = self

func _physics_process(delta):
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	is_focused = Input.is_action_pressed("focus")

	shoot_timer -= delta

	if Input.is_action_pressed("shoot") and shoot_timer <= 0.0:
		shoot()
		shoot_timer = player_data.main_weapon.shoot_rate

	update_hitbox_display()
	update_animation()
	update_move(delta)

func shoot() -> void:
	var mw = player_data.main_weapon

	for muzzle_offset in mw.muzzle_positions:
		var pos = muzzle.global_position + muzzle_offset
		BulletManager.shoot_bullet(mw.bullet_data, pos, Vector2.UP)

func update_hitbox_display() -> void:
	if is_focused:
		hitpoint_display.show_hitpoint()
	else:
		hitpoint_display.hide_hitpoint()

func update_move(delta) -> void:
	var move_input = input_vector
	# 归一化对角线速度，使斜向移动速度不增加
	if move_input.length() > 1.0: move_input = move_input.normalized()

	current_speed = focus_speed if is_focused else normal_speed

	position += move_input * current_speed * delta

	# 位置限制
	position.x = clamp(position.x, 64.0 + MIN_MARGIN * 3, 830.0 - MIN_MARGIN * 3)
	position.y = clamp(position.y, 30.0 + MIN_MARGIN * 4, 930.0 - MIN_MARGIN * 4)

func update_animation() -> void:
	var pressing_left = input_vector.x < -0.1
	var pressing_right = input_vector.x > 0.1

	if (pressing_left and pressing_right) or (not pressing_left and not pressing_right):
		change_state(IDLE)
		return

	# 根据当前状态和输入，决定下一个状态
	match anim_state:
		IDLE:
			if		pressing_left and not pressing_right: change_state(LEFTING)
			elif		pressing_right and not pressing_left: change_state(RIGHTING)
		LEFTING:		if not pressing_left:  change_state(IDLE)
		LEFT:		if not pressing_left:  change_state(IDLE)
		RIGHT:		if not pressing_right: change_state(IDLE)
		RIGHTING:	if not pressing_right: change_state(IDLE)

func change_state(new_state: String) -> void:
	if anim_state == new_state:
		return

	anim_state = new_state
	sprite.play(anim_state)

func _on_animation_finished() -> void:
	# 一次性动画播完后，自动切换到对应的循环动画
	match anim_state:
		LEFTING:
			change_state(LEFT)
		RIGHTING:
			change_state(RIGHT)

func miss() -> void:
	pass  # TODO: 实现玩家中弹后的无敌、残机扣除、死亡特效等
