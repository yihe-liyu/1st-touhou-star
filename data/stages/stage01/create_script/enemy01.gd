extends CreateScript

const BULLET01 = preload("res://data/stages/stage01/bullet/bullet01.tres")
const BULLET02 = preload("res://data/stages/stage01/bullet/bullet02.tres")
const BULLET_SFX = preload("res://assets/Sound/bullet01.wav")

func start_creating(p_ctx: StageContext):
	ctx = p_ctx
	
	var me := get_parent() as Node2D
	var tl := start_timeline()
	var p := ctx.player.get_player()
	
	tl.at(1.5).every(2.0).times(3).do(func():
		var dir := (p.global_position - me.global_position).normalized()
		for i in diff_pick([1, 4, 4, 7]):
			var mlt = 0.4 + i * 0.3
			ctx.bullets.shoot_spread(BULLET01, 1, TAU, dir, me.global_position, BULLET_SFX, mlt)
		if GameState.selected_difficulty >= 2:
			for i in diff_pick([0, 0, 1, 2]):
				var mlt2 = 0.8 + i * 0.4
				var angle = PI / (3 - i + 1)
				ctx.bullets.shoot_spread(BULLET02, diff_pick([0, 0, 3, 5]), angle, -dir, me.global_position, BULLET_SFX, mlt2)
	)
			
	super.start_creating(p_ctx)
