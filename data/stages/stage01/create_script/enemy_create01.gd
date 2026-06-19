extends CreateScript

const BULLET01 = preload("res://data/stages/stage01/bullet/bullet01.tres")
const BULLET_SFX = preload("res://assets/Sound/bullet01.wav")

func start_creating(p_ctx: StageContext):
	ctx = p_ctx
	
	var me := get_parent() as Node2D
	var tl := start_timeline()
	var p := ctx.player.get_player()
	
	tl.at(1.5).every(0.8).do(func():
		var dir := (p.global_position - me.global_position).normalized()
		ctx.bullets.shoot_spread(BULLET01, 1, TAU, dir, me.global_position, BULLET_SFX)
	)
	
	super.start_creating(p_ctx)
