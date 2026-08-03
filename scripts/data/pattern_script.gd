class_name PatternScript
extends CoroutineScript
## 自定义弹幕模式基类 —— "接脚本的接口"
## 想做一个新弹幕形状（内置 ring/aim/fan 之外）：
##   1. extends PatternScript
##   2. 覆写 _tick(ctx)：用 pattern_params() / bullet_data() / emit_at() 发弹
##   3. 注册：PatternRegistry.register_script("名字", 你的脚本)
## 之后它和内置模式一样出现在下拉框/蓝图里，驱动方式一致。
##
## _tick 返回值约定（同 CoroutineScript）：
##   float/int > 0 → 等待该秒后再次调用（返回 config.interval 即可按节奏发射）
##   true          → 下帧立即再次调用
##   false         → 结束
##
## 由 PatternDriver 启动：start(ctx, target) 后 target = 挂载者（Boss/敌人）。

## 注入的蓝图配置（PatternDriver 启动前设置）
var config: BulletPattern


## 模式参数（BulletPattern.params，含难度数组语义）
func pattern_params() -> Dictionary:
	return config.params if config else {}


## 发射间隔（BulletPattern.interval）
func pattern_interval() -> float:
	return config.interval if config else 0.2


## 弹丸配置（从 BulletPattern.bullet_params 构造的 BulletData）
func bullet_data() -> BulletData:
	return PatternDriver.build_bullet(config) if config else null


## 发射原点（由 origin 字段解析：self/player/pos/edge）
func emit_at() -> Vector2:
	return PatternDriver.resolve_origin(ctx, target, config)


## 基准方向（默认向下，含 rotate_step 累计由 Driver 侧注入；脚本模式自管旋转）
func base_dir() -> Vector2:
	return Vector2.DOWN
