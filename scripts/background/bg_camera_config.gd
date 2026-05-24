extends Resource
class_name BgCameraConfig

## 默认震动幅度（0 = 不震）。可通过 trigger_shake() 临时覆盖
@export var shake_amplitude: float = 0.0
## 震动衰减速度，值越大约快停止
@export var shake_decay: float = 4.0
## 玩家位置偏移 → 地面倾斜的响应系数。0 = 不倾斜
@export var tilt_response: float = 2
## 倾斜过渡平滑度，值越大约快到目标角度
@export var tilt_smooth: float = 5.0
## FOV 拉伸系数，使远处纹理产生透视压缩感
@export var fov_stretch: float = 0.0
## 地面旋转角度（弧度），用于特殊关卡效果
@export var roll: float = 0.0
