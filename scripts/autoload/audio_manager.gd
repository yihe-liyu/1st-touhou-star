extends Node
## 音频管理器 autoload
## 用法：AudioManager.play_bgm(preload("res://bgm.ogg"))
##       AudioManager.play_sfx(preload("res://sfx.wav"))

# ── 声道 ──
var _bgm_player: AudioStreamPlayer
var _bgm_player2: AudioStreamPlayer  # 用于淡入淡出
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8

# ── 音量 ──
var master_volume: float = 1.0:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		_apply_volumes()
var bgm_volume: float = 1.0:
	set(v):
		bgm_volume = clampf(v, 0.0, 1.0)
		_apply_volumes()
var sfx_volume: float = 0.3:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		_apply_volumes()

var _current_bgm: AudioStream
var _fade_tween: Tween


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	var bgm_bus := _find_bus("BGM")
	var sfx_bus := _find_bus("SFX")
	
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = bgm_bus
	add_child(_bgm_player)
	
	_bgm_player2 = AudioStreamPlayer.new()
	_bgm_player2.bus = bgm_bus
	_bgm_player2.volume_db = -80.0  # 静音
	add_child(_bgm_player2)
	
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		add_child(p)
		_sfx_players.append(p)
	
	# 暂停/恢复时控制 BGM
	GameManager.game_state_changed.connect(_on_game_state_changed)


# ═══ BGM ═══

func play_bgm(stream: AudioStream, fade_in: float = 0.5) -> void:
	if _current_bgm == stream and _bgm_player.playing:
		return
	
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	_current_bgm = stream
	
	if _bgm_player.playing:
		# 淡入淡出：旧 BGM 还在播，新 BGM 从 player2 渐入
		_bgm_player2.stream = stream
		_bgm_player2.play()
		
		_fade_tween = create_tween().set_parallel(true)
		_fade_tween.tween_property(_bgm_player, "volume_db", -80.0, fade_in)
		_fade_tween.tween_property(_bgm_player2, "volume_db", _to_db(bgm_volume), fade_in)
		_fade_tween.tween_callback(func():
			_bgm_player.stop()
			# 交换角色
			var tmp := _bgm_player
			_bgm_player = _bgm_player2
			_bgm_player2 = tmp
		)
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = _to_db(bgm_volume)
		_bgm_player.play()


func stop_bgm(fade_out: float = 0.5) -> void:
	_current_bgm = null
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bgm_player, "volume_db", -80.0, fade_out)
	_fade_tween.tween_callback(_bgm_player.stop)


# ═══ SFX ═══

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db + _to_db(sfx_volume)
			p.play()
			return p
	
	# 池满了，踢掉最旧的
	_sfx_players[0].stop()
	_sfx_players[0].stream = stream
	_sfx_players[0].volume_db = volume_db + _to_db(sfx_volume)
	_sfx_players[0].play()
	return _sfx_players[0]


# ═══ 内部 ═══

func _apply_volumes() -> void:
	if _bgm_player.playing:
		_bgm_player.volume_db = _to_db(bgm_volume * master_volume)


func _to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return linear_to_db(linear)


func _find_bus(name: String) -> StringName:
	var idx := AudioServer.get_bus_index(name)
	return name if idx >= 0 else &"Master"


func _on_game_state_changed(_old: int, new: int) -> void:
	if new == GameManager.AppState.PAUSED:
		_bgm_player.stream_paused = true
		_bgm_player2.stream_paused = true
	elif _old == GameManager.AppState.PAUSED:
		_bgm_player.stream_paused = false
		_bgm_player2.stream_paused = false
