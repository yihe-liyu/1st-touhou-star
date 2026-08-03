extends CoroutineScript
## 凭空弹幕演出：在任意位置定时发射环形弹幕（无需敌人/Boss）
##
## 挂到 StageTimeline.events（type=custom，script 填本脚本路径）
## 参数可被工作台暴露编辑（events 的 params 字典 → 同名属性覆盖）
## auto_stop = false（total_rings 用尽或关卡结束自动停）

var pos := Vector2(GameConfig.FIELD_CENTER_X, 300.0)  ## 发射位置（舞台中心偏上）
var interval := 0.5        ## 发射间隔（秒）
var total_rings := 5       ## 总环数（-1 = 无限到关卡结束）
var count := 32            ## 每环子弹数
var speed := 240.0         ## 子弹速度
var color := Color(0.9, 0.4, 0.9)  ## 弹色
var tex := "小玉"          ## 子弹贴图名
var spread := TAU          ## 环形总角度（TAU = 整圈）

var _rings_fired := 0


func _tick(p_ctx: StageContext) -> Variant:
	var bd := BulletData.new().tex(tex).speed(speed).color(color).enemy()
	var dir := Vector2.DOWN.rotated(RNG.randf() * TAU)
	p_ctx.bullets.shoot_spread(bd, count, spread, dir, pos)
	_rings_fired += 1
	if total_rings >= 0 and _rings_fired >= total_rings:
		stop()
		return null
	return p_ctx.clock.wait(interval)
