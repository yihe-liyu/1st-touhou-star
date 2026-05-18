extends Resource
class_name BgLayerConfig

## 该层的纹理（QuadMesh 平铺显示）
@export var texture: Texture2D
## UV 滚动速度（像素/秒），Y 负值 = 向下滚动
@export var scroll_speed: Vector2 = Vector2(0, -0.1)
## 在 3D 空间中的 Z 深度。越远视差越弱
@export var z_position: float = 10.0
## QuadMesh 缩放倍数，调整纹理平铺大小
@export var scale: float = 2.0
## 色调乘算颜色（白色 = 不改变原色）
@export var tint: Color = Color(1, 1, 1, 1)
