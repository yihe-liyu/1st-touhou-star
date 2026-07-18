# entities/player/player.gd
extends Area2D
class_name Player

const FRONT_UP: int = 32
const FRONT_DOWN: int = 960 - 32
const FRONT_LEFT: int = 64
const FRONT_RIGHT: int = 1280 - 448
const MIN_MARGIN: int = 8

const IDLE = "idle"
const LEFTING = "lefting"
const LEFT = "left"
const RIGHTING = "righting"
const RIGHT = "right"
var anim_state: String = IDLE

var input_vector: Vector2 = Vector2.ZERO
var is_focused: bool = false
var is_invincible: bool = false
var _invincible_timer: float = 0.0

var hitbox_radius: float = 5.0
var graze_radius: float = 40.0  # 擦弹判定半径

@onready var hitpoint_display: HitPointDisplay = $HitPointDisplay
@onready var muzzle: Marker2D = $Muzzle

## 玩家机体数据（速度、动画、武器等）
@export var player_data: PlayerData
var _shoot_script: PlayerShootScript

# 移动速度（像素/秒）
var focus_speed: int
var normal_speed: int
var current_speed: int

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	z_index = LayerConfig.PLAYER
	# 连接 animation_finished 信号，用于检测一次性动画播完
	sprite.animation_finished.connect(_on_animation_finished)

	_apply_player_data()
	_init_shoot_script()

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
	# 无敌倒计时（替代 await，不挂起调用链）
	if is_invincible:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			is_invincible = false
	
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	is_focused = Input.is_action_pressed("focus")

	update_hitbox_display()
	update_animation()
	update_move(delta)

func _init_shoot_script() -> void:
	if not player_data or not player_data.shoot_script:
		return
	_shoot_script = player_data.shoot_script.new()
	assert(_shoot_script is PlayerShootScript, "Player: shoot_script must be a PlayerShootScript")
	add_child(_shoot_script)
	var ctx := StageContext.new(_shoot_script)
	_shoot_script.start_shooting(ctx)

## 切换角色时重新初始化射击
func _reinit_shoot() -> void:
	if _shoot_script:
		_shoot_script.stop()
		_shoot_script.queue_free()
		_shoot_script = null
	_init_shoot_script()

func update_hitbox_display() -> void:
	if is_focused:
		hitpoint_display.show_hitpoint()
	else:
		hitpoint_display.hide_hitpoint()

func update_move(delta: float) -> void:
	var move_input: Vector2 = input_vector
	# 归一化对角线速度，使斜向移动速度不增加
	if move_input.length() > 1.0: move_input = move_input.normalized()

	current_speed = focus_speed if is_focused else normal_speed

	position += move_input * current_speed * delta

	# 位置限制
	position.x = clamp(position.x, FRONT_LEFT + MIN_MARGIN * 3, FRONT_RIGHT - MIN_MARGIN * 3)
	position.y = clamp(position.y, FRONT_UP + MIN_MARGIN * 4, FRONT_DOWN - MIN_MARGIN * 4)

func update_animation() -> void:
	var pressing_left: bool = input_vector.x < -0.1
	var pressing_right: bool = input_vector.x > 0.1

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
	if is_invincible:
		return
	
	AudioManager.play_sfx(preload("res://assets/Sound/player_dead.wav"), -6.0)
	var pos: Vector2 = global_position
	MissEffectManager.add_circle(pos, 2.5, 1280)
	MissEffectManager.add_circle(pos + Vector2(100, 0), 2.5, 1280)
	MissEffectManager.add_circle(pos + Vector2(-100, 0), 2.5, 1280)
	MissEffectManager.add_circle(pos + Vector2(0, 100), 2.5, 1280)
	MissEffectManager.add_circle(pos + Vector2(0, -100), 2.5, 1280)
	MissEffectManager.add_circle(pos, 1.0, 1280, 0.0, 1.5)
	
	BulletManager.start_death_clear(pos, 2048, 3.0)
	
	# Miss 后记忆值增加 25%
	GameState.add_memory(GameState.MEMORY_MISS)
	
	# 残机扣除
	if GameState.lose_life():
		# 无敌：倒计时 3 秒，_physics_process 自动倒数（不 await，不挂起调用链）
		is_invincible = true
		_invincible_timer = 3.0
	else:
		# 残机为 0 → Game Over，给短暂无敌防止每帧连续触发
		is_invincible = true
		_invincible_timer = 3.0
		GameEvents.player_death.emit()
