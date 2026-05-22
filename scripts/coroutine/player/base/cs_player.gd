extends CoroutineRunner
class_name PlayerShootScript

const OPTION = preload("res://assets/Textures/player/pl00.png")

var _options: Array[Node2D] = []

func start_shooting(api: StageAPI):
	run(_on_run.bind(api))

func _on_run(_api: StageAPI):
	pass

func _sync_options(leader: Node2D, visual_script: Script, wanted: int, offsets: Array, api: StageAPI) -> void:
	while _options.size() < wanted:
		var opt := Node2D.new()
		opt.global_position = leader.global_position
		opt.z_index = 6
		leader.get_parent().add_child(opt)

		var tex: AtlasTexture = AtlasTexture.new()
		tex.atlas = OPTION
		tex.region = Rect2(80, 144, 16, 16)

		var visual: OptionVisual = visual_script.new() as OptionVisual
		if visual is OptionVisualSimple:
			visual.texture = tex
		visual.name = "Visual"
		opt.add_child(visual)
		visual.setup(opt)

		var follow := OptionFollow.new()
		follow.name = "Follow"
		follow.leader = leader
		opt.add_child(follow)
		follow.start_moving(StageAPI.new(follow), opt)

		_options.append(opt)

	while _options.size() > wanted:
		var opt = _options.pop_back()
		opt.queue_free()

	if offsets.size() > 0:
		for i in _options.size():
			var follow = _options[i].get_node_or_null("Follow") as OptionFollow
			if follow:
				follow.offset = offsets[i]

	for opt in _options:
		var visual = opt.get_node_or_null("Visual") as OptionVisual
		if visual:
			visual.update_visual(api, leader)

func _shoot_options(api: StageAPI, bullet_data: BulletData, count: int, spread: float, dir: Vector2) -> void:
	for opt in _options:
		api.shoot_spread(bullet_data, count, spread, dir, opt.global_position)

func _cleanup_options() -> void:
	for opt in _options:
		if is_instance_valid(opt):
			opt.queue_free()
	_options.clear()
