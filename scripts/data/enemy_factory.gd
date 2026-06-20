class_name EnemyFactory
extends RefCounted
## 组合式敌人生成——不建 .tres，参数化拼装

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")

# ═══ 子弹 ═══

func bullet(texture_path: String, speed: float, tint: Color = Color.WHITE) -> BulletData:
	var b := BulletData.new()
	b.texture = load(texture_path)
	b.velocity = Vector2(0, speed)
	b.tint = tint
	b.faction = BulletData.Faction.ENEMY
	b.can_be_canceled = true
	return b


# ═══ 敌人生成 ═══

func spawn(ctx: StageContext, visual: PackedScene, move: Node, shoot: Node, pos: Vector2, opts: Dictionary = {}) -> Enemy:
	var e := ENEMY_SCENE.instantiate()
	
	if visual:
		var vis := visual.instantiate()
		e.add_child(vis)
	
	var data := EnemyData.new()
	data.max_hp = opts.get("hp", 100)
	data.item_power = opts.get("drop_power", 1)
	data.item_point = opts.get("drop_point", 2)
	e.enemy_data = data
	e.global_position = pos
	
	if move and move is MoveScript:
		e.add_child(move)
		var move_ctx := StageContext.new(move)
		(move as MoveScript).start_moving(move_ctx, e)
	
	if shoot and shoot is CreateScript:
		e.add_child(shoot)
		var shoot_ctx := StageContext.new(shoot)
		(shoot as CreateScript).start_creating(shoot_ctx)
	
	return e
