extends Node
class_name StageWaveController

var level_mgr: LevelManager
var wave: WaveData

func start(mgr: LevelManager, w: WaveData):
	level_mgr = mgr
	wave = w
	_on_start()

func _on_start():
	pass

func _process_wave(_delta: float):
	pass

func signal_wave_done():
	if level_mgr:
		level_mgr.force_advance()
