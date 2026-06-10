extends Node
## 音频管理器 autoload
## 用法：AudioManager.play_bgm(preload("res://bgm.ogg"), 0.3)  # 第二参=停止后的间隔秒数
##       AudioManager.play_sfx(preload("res://sfx.wav"))

# ── 声道 ──
var _bgm_player: AudioStreamPlayer
var _bgm_player_b: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _crossfade_tween: Tween
const SFX_POOL_SIZE := 8

## 每帧已播放的音效流，防止同帧重复播放
var _played_this_frame: Array[AudioStream] = []

# ── 音量 ──
var master_volume: float = 1.0:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		_apply_volumes()
var bgm_volume: float = 1.0:
	set(v):
		bgm_volume = clampf(v, 0.0, 1.0)
		_apply_volumes()
var sfx_volume: float = 0.7:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_init_players()
	GameManager.game_state_changed.connect(_on_game_state_changed)


func _process(_delta: float) -> void:
	# 每帧清空播放记录
	_played_this_frame.clear()
	set_process(false)


# ═══ BGM ═══

## gap: 停止旧音乐后的间隔秒数（默认 0.3）
func _init_players() -> void:
	if not _bgm_player:
		var bgm_bus := _find_bus("BGM")
		_bgm_player = AudioStreamPlayer.new()
		_bgm_player.bus = bgm_bus
		_bgm_player.process_mode = PROCESS_MODE_ALWAYS
		add_child(_bgm_player)
		
		_bgm_player_b = AudioStreamPlayer.new()
		_bgm_player_b.bus = bgm_bus
		_bgm_player_b.process_mode = PROCESS_MODE_ALWAYS
		add_child(_bgm_player_b)
	
	if _sfx_players.is_empty():
		var sfx_bus := _find_bus("SFX")
		for i in range(SFX_POOL_SIZE):
			var p := AudioStreamPlayer.new()
			p.bus = sfx_bus
			add_child(p)
			_sfx_players.append(p)


func play_bgm(stream: AudioStream, gap: float = 0.3) -> void:
	if not _bgm_player or not is_instance_valid(_bgm_player):
		_init_players()
	if _bgm_player.playing and _bgm_player.stream == stream:
		return
	
	cancel_crossfade()
	_bgm_player.stop()
	_bgm_player_b.stop()
	
	if gap > 0.0:
		# false = 暂停时 timer 不走，防止暂停期间 BGM 偷跑
		await get_tree().create_timer(gap, false).timeout
	
	_bgm_player.stream = stream
	_bgm_player.volume_db = _to_db(bgm_volume * master_volume)
	_bgm_player.play()


func stop_bgm() -> void:
	cancel_crossfade()
	_bgm_player.stop()
	_bgm_player_b.stop()


## 交叉淡入淡出到新 BGM
func crossfade_bgm(stream: AudioStream, duration: float = 1.0) -> void:
	if not _bgm_player or not is_instance_valid(_bgm_player):
		_init_players()
	if _bgm_player.playing and _bgm_player.stream == stream:
		return
	
	cancel_crossfade()
	
	var base_db := _to_db(bgm_volume * master_volume)
	var old_player := _bgm_player if _bgm_player.playing else null
	
	# 新流放到闲置播放器
	var new_player: AudioStreamPlayer
	if _bgm_player_b.playing:
		_bgm_player_b.stop()
	new_player = _bgm_player_b
	new_player.volume_db = -80.0
	new_player.stream = stream
	new_player.play()
	
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)
	_crossfade_tween.tween_property(new_player, "volume_db", base_db, duration)
	
	if old_player:
		_crossfade_tween.tween_property(old_player, "volume_db", -80.0, duration)
		_crossfade_tween.finished.connect(_on_crossfade_done.bind(old_player))


func cancel_crossfade() -> void:
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()


func _on_crossfade_done(old: AudioStreamPlayer) -> void:
	if old and is_instance_valid(old):
		old.stop()


# ═══ SFX ═══

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> AudioStreamPlayer:
	# 懒初始化
	if _sfx_players.is_empty():
		_init_players()
	
	# 同帧不重复播放同一音效
	if stream in _played_this_frame:
		return _sfx_players[0] if _sfx_players.size() > 0 else null
	_played_this_frame.append(stream)
	set_process(true)
	
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
	var db := _to_db(bgm_volume * master_volume)
	if _bgm_player.playing:
		_bgm_player.volume_db = db
	if _bgm_player_b.playing:
		_bgm_player_b.volume_db = db


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
		if _bgm_player and _bgm_player.playing:
			_bgm_player.stream_paused = true
		if _bgm_player_b and _bgm_player_b.playing:
			_bgm_player_b.stream_paused = true
	elif new == GameManager.AppState.PLAYING:
		if _bgm_player:
			_bgm_player.stream_paused = false
		if _bgm_player_b:
			_bgm_player_b.stream_paused = false
