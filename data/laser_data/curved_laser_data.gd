extends Resource
class_name CurvedLaserData
## 曲线激光数据 —— 像 BulletData 一样可存 .tres 调参

# ---- 生长阶段 ----
@export var grow_duration: float = 1.0        # 从 0 长到满的时间（head_speed = 1.0 / grow_duration）
@export var max_tail: float = 0.5              # 尾巴保留长度（归一化，0.5=曲线长度的一半）

# ---- 激活阶段 ----
@export var active_duration: float = 2.0       # 激活阶段时长（有判定）
@export var tail_follow_head: bool = true      # 激活时尾巴追赶头部？true=尾巴追上头部=激光消失

# ---- 消退阶段 ----
@export var fade_duration: float = 0.3         # 消退动画时长

# ---- 视觉 ----
@export var base_width: float = 14.0           # 根部宽度 px
@export var tip_width: float = 4.0             # 尖部宽度 px
@export var laser_color: Color = Color(1.0, 0.2, 0.1, 1.0)
@export var glow_intensity: float = 0.5

# ---- 判定 ----
@export var damage_per_second: float = 1.0     # 激活期每秒伤害
@export var hitbox_width: float = 8.0          # 判定宽度半值（判定比视觉窄）
