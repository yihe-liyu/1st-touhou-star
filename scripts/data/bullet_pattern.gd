class_name BulletPattern
extends Resource
## 弹幕蓝图 —— 一个"发射模式 + 节奏 + 弹丸配置"的描述
## 数据驱动弹幕的核心：PhaseData.patterns / 敌人模板 / PatternDriver 读取
##
## 字段说明：
##   pattern       注册表名（PatternRegistry：ring/aim/fan/自定义脚本名）
##   interval      发射间隔（秒）
##   repeats       发射次数（-1 = 无限，直到阶段结束/超时）
##   start_delay   相对阶段开始延迟启动（秒）
##   duration      运行时长（秒；<0 = 无限）
##   rotate_step   每次发射后基准方向旋转（度）→ 转环/涡旋效果
##   origin        发射原点：self(挂载者) / player(玩家) / pos(固定坐标) / edge(屏幕边)
##   origin_pos    origin="pos" 时的坐标
##   origin_side   origin="edge" 时的边（top/left/right/bottom）
##   params        形状参数（支持难度数组 [easy,normal,hard,lunatic]）
##                 ring: {n, speed, aim} / aim: {n, spread, speed} / fan: {n, spread, speed}
##   bullet_params 弹丸配置：{tex, color, speed, blend, behavior, coroutine_script, accelerate...}

@export var pattern: String = "ring"
@export var interval: float = 0.2
@export var repeats: int = -1
@export var start_delay: float = 0.0
@export var duration: float = -1.0
@export var rotate_step: float = 0.0
@export var origin: String = "self"
@export var origin_pos: Vector2 = Vector2.ZERO
@export var origin_side: String = "top"
@export var params: Dictionary = {}
@export var bullet_params: Dictionary = {}


## 配置校验：返回错误列表（空 = 合法）
func validate() -> Array[String]:
	var errs: Array[String] = []
	if pattern.is_empty():
		errs.append("BulletPattern.pattern 不能为空")
	if interval <= 0.0:
		errs.append("BulletPattern[%s].interval = %s 必须 > 0（除零/死循环）" % [pattern, interval])
	return errs
