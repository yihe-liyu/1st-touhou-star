extends Node3D
class_name BackgroundLayer

@export var parallax_factor: float = 1.0

var _initial_pos: Vector3
var _background: StageBackground

func _ready():
	_initial_pos = position
	_background = _find_background()
	_on_setup()

func _process(_delta):
	if not _background:
		return
	if not _background._active:
		return
	_on_update(_delta, _background._elapsed)

func _find_background() -> StageBackground:
	var parent = get_parent()
	if parent is StageBackground:
		return parent
	if parent and parent.get_parent() is StageBackground:
		return parent.get_parent()
	return null

func _on_setup():
	pass

func _on_update(_delta: float, _elapsed: float):
	pass
