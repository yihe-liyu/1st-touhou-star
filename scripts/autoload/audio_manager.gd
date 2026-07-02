extends Node
## 音频管理器 autoload
## BGM 单路（无需 crossfade），SFX 8 路池 + 同帧去重

# ── 声道 ──
var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8

## 每帧已播放的音效流，防止同帧重复播放
var _played_this_frame: Array[AudioStream] = []

# ── 音量 ──
var master_volume: float = 1.0:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		_bgm_sync_volume()
var bgm_volume: float = 1.0:
	set(v):
		bgm_volume = clampf(v, 0.0, 1.0)
		_bgm_sync_volume()
var sfx_volume: float = 0.7:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_init_players()
	GameManager.game_state_changed.connect(_on_game_state_changed)


func _process(_delta: float) -> void:
	_played_this_frame.clear()


# ═══ 初始化 ═══

func _init_players() -> void:
	if not _bgm_player:
		_bgm_player = AudioStreamPlayer.new()
		_bgm_player.bus = _find_bus("BGM")
		_bgm_player.process_mode = PROCESS_MODE_ALWAYS
		add_child(_bgm_player)
	
	if _sfx_players.is_empty():
		var sfx_bus := _find_bus("SFX")
		for i in range(SFX_POOL_SIZE):
			var p := AudioStreamPlayer.new()
			p.bus = sfx_bus
			add_child(p)
			_sfx_players.append(p)


# ═══ BGM ═══

const MUSIC_REGISTRY_PATH := "res://data/registry/music_registry.tres"

## 播 BGM（覆盖当前播放）。播放前无间隔、无渐弱。
func play_bgm(stream: AudioStream, _gap_unused: float = 0.0) -> void:
	if not _bgm_player or not is_instance_valid(_bgm_player):
		_init_players()
	if _bgm_player.playing and _bgm_player.stream == stream:
		return
	
	_bgm_player.stop()
	_bgm_player.stream = stream
	_bgm_player.volume_db = _to_db(bgm_volume * master_volume)
	_bgm_player.play()
	
	# 音乐解锁：如果该音频有关联的音乐记录，解锁之
	_unlock_music_by_stream(stream)


## 根据 AudioStream 查找对应的音乐记录并解锁
func _unlock_music_by_stream(stream: AudioStream) -> void:
	if not ResourceLoader.exists(MUSIC_REGISTRY_PATH):
		return
	var registry: MusicRegistry = ResourceLoader.load(MUSIC_REGISTRY_PATH)
	if not registry:
		return
	# 通过音频资源路径匹配
	var path := stream.resource_path
	if path.is_empty():
		return
	if registry.unlock_by_path(path):
		ResourceSaver.save(registry, MUSIC_REGISTRY_PATH)


## 停止 BGM（无渐弱）
func stop_bgm() -> void:
	if not _bgm_player or not is_instance_valid(_bgm_player):
		return
	_bgm_player.stop()


# ═══ BGM 音量同步 ═══

func _bgm_sync_volume() -> void:
	if not _bgm_player or not is_instance_valid(_bgm_player):
		return
	_bgm_player.volume_db = _to_db(bgm_volume * master_volume)


# ═══ SFX ═══

## 播一次音效，返回播放器（返回值通常不用）。同帧同一流不重复。
func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if _sfx_players.is_empty():
		_init_players()
	
	# 同帧不重复
	if stream in _played_this_frame:
		return
	_played_this_frame.append(stream)
	
	var player := _pick_sfx_player()
	if not player:
		return
	
	player.stream = stream
	player.volume_db = clampf(volume_db + _to_db(sfx_volume), -80.0, 24.0)
	player.play()


## 从池中挑一个可用的播放器。
## 优先空闲的，其次找播放时间最久远的那个。
func _pick_sfx_player() -> AudioStreamPlayer:
	# 1) 有空闲 → 用它
	for p in _sfx_players:
		if not p.playing:
			return p
	
	# 2) 全忙 → 踢掉最老的（最早开始播放的那个）
	var oldest := _sfx_players[0]
	var oldest_tick := oldest.get_playback_position()
	for i in range(1, _sfx_players.size()):
		var p := _sfx_players[i]
		var tick := p.get_playback_position()
		if tick > oldest_tick:
			oldest = p
			oldest_tick = tick
	oldest.stop()
	return oldest


# ═══ 内部 ═══

func _to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80
	return linear_to_db(linear)


func _find_bus(bus_name: String) -> StringName:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return StringName(bus_name)
	return &"Master"


func _on_game_state_changed(_old: int, new: int) -> void:
	if not _bgm_player:
		return
	_bgm_player.stream_paused = (new == GameManager.AppState.PAUSED or new == GameManager.AppState.TRANSITIONING)
	# SFX 在 tree.paused 下自动静音，无需额外处理
