extends Resource
class_name CurvedLaserData

## 头部前进速度（像素/秒）
var grow_speed: float = 600.0
## 尾巴离头部多远（像素）
var tail_distance: float = 300.0
## 梭形中间最粗处的宽度（像素）
var mid_width: float = 20.0
## 梭形两端细尖的宽度（像素）
var end_width: float = 3.0
## 激光颜色
var laser_color: Color = Color(1.0, 0.2, 0.1, 1.0)
## 光晕强度，0=无光晕
var glow_intensity: float = 0.6
## 发射点弹雾贴图
var spawn_fog_texture: Texture2D
## 判定宽度（半值）
var hitbox_width: float = 6.0
## 判定伤害（每秒）
var damage_per_second: float = 1.0
## 最大存活秒数，0=不限
var max_lifetime: float = 8.0

## ---- 构造链 ----
func speed(v: float) -> CurvedLaserData:
	grow_speed = v
	return self

func tail(d: float) -> CurvedLaserData:
	tail_distance = d
	return self

func width(mid: float, end: float = -1) -> CurvedLaserData:
	mid_width = mid
	if end >= 0: end_width = end
	return self

func color(c: Color) -> CurvedLaserData:
	laser_color = c
	return self

func glow(v: float) -> CurvedLaserData:
	glow_intensity = v
	return self

func hitbox(w: float) -> CurvedLaserData:
	hitbox_width = w
	return self

func lifetime(t: float) -> CurvedLaserData:
	max_lifetime = t
	return self
