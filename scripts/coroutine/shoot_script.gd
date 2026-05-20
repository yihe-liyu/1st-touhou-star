extends CoroutineRunner
class_name ShootScript

var def: ShootPatternDef

func start_shooting(api: StageAPI, p_def: ShootPatternDef):
	def = p_def
	run(_on_run.bind(api))

func _on_run(_api: StageAPI):
	pass
