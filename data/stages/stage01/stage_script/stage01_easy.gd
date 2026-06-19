extends StageScript

const REIMU_BEFORE_DIALOGUE = preload("res://data/dialogue/reimu/stage01_before.tres")

var _phase: int = 0

func _on_step(_ctx: StageContext) -> Variant:
	match _phase:
		0:
			AudioManager.play_bgm(preload("res://assets/Music/THq01_02.夜间漫步.mp3"), 0.0)
			return true
		_:
			return true
