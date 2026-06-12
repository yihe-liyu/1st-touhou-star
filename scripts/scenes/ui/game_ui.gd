extends CanvasLayer
class_name GameUI
## 游戏 HUD —— Score / HiScore / Power / MaxPoint / Graze

## 入场动画完成时发射，供 GameScene 等待
signal entry_finished()

const NumberSpriteClass = preload("res://scripts/ui/number_sprite.gd")
const SeparatorClass = preload("res://scripts/ui/ui_separator.gd")

## 入场动画：每个元素的间隔时间（秒）
const ENTRY_INTERVAL: float = 0.03
## 入场动画：单个元素滑入持续时间（秒）
const ENTRY_DURATION: float = 0.25

var _hi_score_num: Node2D
var _score_num: Node2D
var _power_num: Node2D
var _max_point_num: Node2D
var _graze_num: Node2D
var _memory_num: Node2D
var _memory_rect: ColorRect
var _shader_time: float = 0.0

# 残机 & Bomb 碎片
var _life_fragments: Array[Sprite2D] = []
var _bomb_fragments: Array[Sprite2D] = []

## 记录所有入场元素，按顺序播放
var _entry_queue: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时水面动画不冻
	var tex := preload("res://assets/Textures/ascii/ascii.png")
	
	# Title Logo → 先入队但单独处理
	var title := $"Title"
	_entry_queue.push_front(title)
	
	# 难度 UI → 入队，单独处理入场动画
	var diff := $"diffculty"
	_entry_queue.append(diff)
	
	# 文字标签先入队（先出现）
	_entry_queue.append($HighScore)
	_entry_queue.append($Score)
	_entry_queue.append($Player)
	_entry_queue.append($Bomb)
	_entry_queue.append($Power)
	_entry_queue.append($Point)
	_entry_queue.append($Graze)
	_entry_queue.append($MemoryValue)
	
	_hi_score_num = _make_number_sprite("HiScoreNumber",  $HighScore.position + Vector2(102, 0), tex, 10)
	_add_separator(Vector2(832, 124), 450.0, Color(0.685, 0.685, 0.685, 0.5))
	_score_num    = _make_number_sprite("ScoreNumber",    $Score.position     + Vector2(102, 0), tex, 10)
	_add_separator(Vector2(832, 180), 450.0, Color(1.0, 1.0, 1.0, 0.5))
	_add_separator(Vector2(832, 274), 450.0, Color(0.961, 0.825, 0.963, 0.502))
	_add_separator(Vector2(832, 344), 450.0, Color(0.735, 1.0, 0.732, 0.502))
	_power_num    = _make_number_sprite("PowerNumber",    $Power.position     + Vector2(78, 0), tex, 10)
	_add_separator(Vector2(832, 396), 450.0, Color(1.0, 0.805, 0.704, 0.502))
	_max_point_num= _make_number_sprite("MaxPointNumber", $Point.position     + Vector2(102, 0), tex)
	_add_separator(Vector2(832, 452), 450.0, Color(0.689, 0.933, 1.0, 0.502))
	_graze_num    = _make_number_sprite("GrazeNumber",    $Graze.position     + Vector2(102, 0), tex)
	_add_separator(Vector2(832, 508), 450.0, Color(0.685, 0.685, 0.685, 0.5))
	
	_memory_rect = $Memory/OutlineRect
	_entry_queue.append(_memory_rect)
	_memory_num = _make_number_sprite_on("MemoryNumber", $Memory, Vector2(980, 608), tex, 6)
	
	# 设置难度标签贴图
	_update_difficulty_texture()
	
	# 碎片图标
	_fragment_init()

	# 颜色
	_hi_score_num.modulate  = Color(0.735, 0.735, 0.735)
	_power_num.modulate     = Color(1.0, 0.498, 0.165, 1.0)
	_max_point_num.modulate = Color(0.502, 0.898, 1.0, 1.0)
	_graze_num.modulate     = Color(0.735, 0.735, 0.735)
	_memory_num.modulate    = Color(0.592, 0.549, 1.0, 1.0)

	# 对齐：不带前导零的用左对齐
	_max_point_num.left_align = true
	_graze_num.left_align     = true
	_memory_num.pct_index     = 13
	_memory_num.minus_index   = 12
	_memory_num.char_count    = 14
	_memory_num.z_index       = 128
	
	# 依次播放入场动画
	_play_entry_animation()


## 将所有 HUD 元素依次从右侧滑入
func _play_entry_animation() -> void:
	for i in _entry_queue.size():
		var node := _entry_queue[i]
		
		# 判断节点类型
		var is_memory := node.name in ["MemoryValue", "MemoryNumber"] or node == _memory_rect
		var is_separator := node is UISeparator
		var is_title := node.name == "Title"
		var is_diff := node.name == "diffculty"
		var is_fragment := node.has_meta("is_fragment")
		if is_title:
			# Title Logo：挂 Shader，初始隐藏
			var logo_shader := preload("res://gdshader/logo_entrance.gdshader")
			var mat := ShaderMaterial.new()
			mat.shader = logo_shader
			mat.set_shader_parameter("progress", 0.0)
			mat.set_shader_parameter("alpha_mult", 0.0)
			node.material = mat
			node.modulate.a = 1.0
		elif is_separator:
			# 分隔条：初始长度为 0，从中间向两端生长
			node.progress = 0.0
			node.modulate.a = 0.0
		elif is_diff:
			# 难度 UI：居中，初始极小 + 透明
			node.position = Vector2(448, 480)
			node.scale = Vector2(0.01, 0.01)
			node.modulate.a = 0.0
		elif not is_memory and not is_fragment:
			# 其他元素：偏右 + 透明
			node.position.x += 30
			node.modulate.a = 0.0
		else:
			# Memory：原地渐显
			if node == _memory_rect:
				node.material = node.material.duplicate()
				node.material.set_shader_parameter("alpha_mult", 0.0)
			else:
				node.modulate.a = 0.0
		
		# 逐个延迟播放入场 tween
		var tw := create_tween()
		tw.tween_interval(i * ENTRY_INTERVAL)
		tw.tween_callback(func():
			if not is_instance_valid(node):
				return
			var t := create_tween().set_parallel(true)
			if is_title:
				t.set_trans(Tween.TRANS_CUBIC)
				t.set_ease(Tween.EASE_OUT)
				t.tween_property(node.material, "shader_parameter/progress", 1.0, 1.5)
				t.tween_property(node.material, "shader_parameter/alpha_mult", 1.0, 0.8)
			elif is_diff:
				# 难度 UI：从中心弹跳到 3 倍 → 移动到原位并缩到 1 倍
				node.modulate.a = 1.0
				var pop := create_tween().set_parallel(true)
				pop.set_trans(Tween.TRANS_BACK)
				pop.set_ease(Tween.EASE_OUT)
				pop.tween_property(node, "scale", Vector2(3, 3), 0.4)
				t.tween_callback(func():
					var t2 := create_tween().set_parallel(true)
					t2.set_trans(Tween.TRANS_CUBIC)
					t2.set_ease(Tween.EASE_OUT)
					t2.tween_property(node, "position", Vector2(1056, 64), 0.5)
					t2.tween_property(node, "scale", Vector2(1, 1), 0.5)
				).set_delay(0.5)
			elif is_separator:
				t.set_trans(Tween.TRANS_CUBIC)
				t.set_ease(Tween.EASE_OUT)
				t.tween_property(node, "progress", 1.0, ENTRY_DURATION)
				t.tween_property(node, "modulate:a", 1.0, ENTRY_DURATION * 0.7)
			elif not is_memory and not is_fragment:
				t.set_trans(Tween.TRANS_CUBIC)
				t.set_ease(Tween.EASE_OUT)
				t.tween_property(node, "position:x", node.position.x - 30, ENTRY_DURATION)
				t.tween_property(node, "modulate:a", 1.0, ENTRY_DURATION * 0.7)
			else:
				if node == _memory_rect:
					t.tween_property(node.material, "shader_parameter/alpha_mult", 1.0, ENTRY_DURATION * 0.7)
				else:
					t.tween_property(node, "modulate:a", 1.0, ENTRY_DURATION * 0.7)
		)
	
	# 所有入场动画完成后通知 GameScene
	# 总时长 = 串行 stagger + 最长动画缓冲
	# Title logo 排第一, 入场 1.5s → 1.5 = 最长单元素时长
	var total := _entry_queue.size() * ENTRY_INTERVAL + 1.5
	var done := create_tween()
	done.tween_interval(total + 0.1)
	done.tween_callback(func():
		entry_finished.emit()
	)


func _make_number_sprite_on(p_name: String, parent: Node, pos: Vector2, tex: Texture2D = null, dcount: int = 8) -> Node2D:
	var ns := _make_number_sprite(p_name, pos, tex, dcount)
	remove_child(ns)
	parent.add_child(ns)
	ns.z_index = 0  # 同层内靠到最上
	return ns


## 初始化残机 / Bomb 碎片图标
## 贴图要求：横排 6 帧等宽，帧数 = 碎片数
func _fragment_init() -> void:
	var life_tex := preload("res://assets/Textures/front/life.png")
	var spell_tex := preload("res://assets/Textures/front/spell.png")
	
	_life_fragments.resize(8)
	_bomb_fragments.resize(8)
	
	# 残机碎片：在 Player 标签右侧
	for i in 8:
		var s := Sprite2D.new()
		s.texture = _make_fragment_region(life_tex, 5)
		s.position = Vector2(1018 + i * 32, 232)
		s.z_index = 128
		s.modulate.a = 0.0
		s.set_meta("is_fragment", true)
		add_child(s)
		_life_fragments[i] = s
		_entry_queue.append(s)
	
	# Spell 碎片：在 Bomb 标签右侧
	for i in 8:
		var s := Sprite2D.new()
		s.texture = _make_fragment_region(spell_tex, 5)
		s.position = Vector2(1018 + i * 32, 304)
		s.z_index = 128
		s.modulate.a = 0.0
		s.set_meta("is_fragment", true)
		add_child(s)
		_bomb_fragments[i] = s
		_entry_queue.append(s)


## 从 6 帧横排贴图中切出第 index 帧
func _make_fragment_region(tex: Texture2D, index: int) -> AtlasTexture:
	var frame_w := tex.get_width() / 6.0
	var h := tex.get_height()
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(index * frame_w, 0, frame_w, h)
	at.filter_clip = true
	return at


## 根据 life_values[i] 选帧：0.0=空(隐藏), 0.0~0.2=帧0, ..., 0.8~1.0=帧4(碎片), 1.0=帧5(完整)
func _life_frame(value: float) -> int:
	if value <= 0.0:
		return -1
	elif value >= 1.0:
		return 5
	else:
		# 0.0 < value < 1.0 → 帧 0~4
		return mini(int(value * 5.0), 4)


func _update_fragments() -> void:
	var life_tex := preload("res://assets/Textures/front/life.png")
	var spell_tex := preload("res://assets/Textures/front/spell.png")
	var fw_life := life_tex.get_width() / 6.0
	var fw_spell := spell_tex.get_width() / 6.0
	
	for i in 8:
		# 残机：前 lives 个完整，下一个可能显示碎片，其余空
		if i < GameState.lives:
			_life_fragments[i].visible = true
			var at := _life_fragments[i].texture as AtlasTexture
			at.region = Rect2(5 * fw_life, 0, fw_life, life_tex.get_height())  # 帧 5=完整
		elif i == GameState.lives and GameState.life_fragments > 0:
			_life_fragments[i].visible = true
			var at := _life_fragments[i].texture as AtlasTexture
			at.region = Rect2(GameState.life_fragments * fw_life, 0, fw_life, life_tex.get_height())
		else:
			_life_fragments[i].visible = true
			var at := _life_fragments[i].texture as AtlasTexture
			at.region = Rect2(0, 0, fw_life, life_tex.get_height())  # 帧 0=空
		
		# Bomb
		if i < GameState.bomb_count:
			_bomb_fragments[i].visible = true
			var at := _bomb_fragments[i].texture as AtlasTexture
			at.region = Rect2(5 * fw_spell, 0, fw_spell, spell_tex.get_height())
		elif i == GameState.bomb_count and GameState.bomb_fragments > 0:
			_bomb_fragments[i].visible = true
			var at := _bomb_fragments[i].texture as AtlasTexture
			at.region = Rect2(GameState.bomb_fragments * fw_spell, 0, fw_spell, spell_tex.get_height())
		else:
			_bomb_fragments[i].visible = true
			var at := _bomb_fragments[i].texture as AtlasTexture
			at.region = Rect2(0, 0, fw_spell, spell_tex.get_height())


## 各难度的贴图切片，在 Inspector 中拖入
@export var difficulty_textures: Array[Texture2D]


## 根据 selected_difficulty 切换难度标签贴图
func _update_difficulty_texture() -> void:
	var diff := $"diffculty"
	if not diff:
		return
	var idx := clampi(GameState.selected_difficulty, 0, difficulty_textures.size() - 1)
	if idx < difficulty_textures.size() and difficulty_textures[idx]:
		diff.texture = difficulty_textures[idx]


func _add_separator(pos: Vector2, length: float, col: Color) -> void:
	var sep := SeparatorClass.new()
	sep.position = pos
	sep.line_length = length
	sep.line_color = col
	sep.line_width = 4
	sep.fade_ratio = 0.25
	sep.z_index = 128
	add_child(sep)
	_entry_queue.append(sep)


func _make_number_sprite(p_name: String, pos: Vector2, tex: Texture2D = null, dcount: int = 8) -> Node2D:
	var ns := NumberSpriteClass.new()
	ns.name = p_name
	ns.position = pos
	ns.z_index = 128
	ns.digit_count = dcount
	ns.digit_texture = tex
	ns.char_count = 14   # 贴图: 0-9 . / - %
	ns.dot_index = 10    # 10='.'
	ns.slash_index = 11  # 11='/'
	ns.minus_index = -1  # 普通不用 '-'
	ns.pct_index = -1    # 普通不用 '%'
	add_child(ns)
	_entry_queue.append(ns)
	return ns


func _process(_delta: float) -> void:
	if not is_instance_valid(GameState):
		return

	_hi_score_num.value = GameState.get_high_score(0)
	_score_num.value    = GameState.current_score
	_max_point_num.value= GameState.max_point
	_graze_num.value    = GameState.graze_count
	_memory_num.show_text("%d%%" % int(GameState.memory_value))

	if GameState.player and is_instance_valid(GameState.player):
		_power_num.show_text(GameState.get_power_display() + "/4.00")
	
	_update_fragments()
	
	# 同步 memory → shader
	if _memory_rect and _memory_rect.material is ShaderMaterial:
		_memory_rect.material.set_shader_parameter("memory", float(GameState.memory_value))
		_shader_time += _delta * smoothstep(-100.0, 200.0, GameState.memory_value) * 10.0
		_memory_rect.material.set_shader_parameter("shader_time", _shader_time)
