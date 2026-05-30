extends Node
## 音频管理器 autoload
## 用法：AudioManager.play_bgm(preload("res://bgm.ogg"), 0.3)  # 第二参=停止后的间隔秒数
##       AudioManager.play_sfx(preload("res://sfx.wav"))

# ── 声道 ──
var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_bgm: AudioStream
var _loop_bgm: bool = true
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
var sfx_volume: float = 0.8:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	var bgm_bus := _find_bus("BGM")
	var sfx_bus := _find_bus("SFX")
	
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = bgm_bus
	_bgm_player.process_mode = PROCESS_MODE_ALWAYS
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)
	
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		add_child(p)
		_sfx_players.append(p)
	
	GameManager.game_state_changed.connect(_on_game_state_changed)


# ═══ BGM ═══

## gap: 停止旧音乐后的间隔秒数（默认 0.3）
func play_bgm(stream: AudioStream, gap: float = 0.3, loop: bool = true) -> void:
	if _bgm_player.playing and _bgm_player.stream == stream:
		return
	
	_current_bgm = stream
	_loop_bgm = loop
	
	_bgm_player.stop()
	
	if gap > 0.0:
		await get_tree().create_timer(gap).timeout
	
	_bgm_player.stream = stream
	_bgm_player.volume_db = _to_db(bgm_volume * master_volume)
	_bgm_player.play()


func stop_bgm() -> void:
	_loop_bgm = false
	_bgm_player.stop()


func _on_bgm_finished() -> void:
	if _loop_bgm and _current_bgm:
		_bgm_player.seek(0.0)
		_bgm_player.play()


# ═══ SFX ═══

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db + _to_db(sfx_volume)
			p.play()
			return p
	
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


func _find_bus(bus_name: String) -> StringName:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return StringName(bus_name)
	return &"Master"


func _on_game_state_changed(_old: int, new: int) -> void:
	if new == GameManager.AppState.PAUSED:
		_bgm_player.stream_paused = true
	elif new == GameManager.AppState.PLAYING:
		_bgm_player.stream_paused = false
