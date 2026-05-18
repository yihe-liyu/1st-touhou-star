extends Resource
class_name StageBackgroundData

@export_group("Layers")
## 天空层纹理（QuadMesh, z=30），可选
@export var sky_texture: Texture2D
## 天空 UV 滚动速度
@export var sky_scroll: Vector2 = Vector2(0, -0.02)
## 天空 QuadMesh 缩放倍数
@export var sky_scale: float = 3.0
## 天空色调
@export var sky_tint: Color = Color(1, 1, 1, 1)

## 中景层配置数组。从远到近排列，每层自动生成 QuadMesh
@export var layers: Array[BgLayerConfig] = []

@export_group("Ground")
## 地面纹理（平铺在 PlaneMesh 上）
@export var ground_texture: Texture2D
## 地面 UV 滚动速度
@export var ground_scroll: Vector2 = Vector2(0, -0.2)
## 网格线密度（值越大约密）
@export var ground_grid_scale: float = 20.0
## 网格线粗细（0~1）
@export var ground_grid_line_width: float = 0.03
## 网格线颜色（Alpha=0 可隐藏网格）
@export var ground_grid_color: Color = Color(0.3, 0.5, 1.0, 0.0)
## 地面纹理色调
@export var ground_tint: Color = Color(1, 1, 1, 1)

@export_group("Environment")
## 雾颜色
@export var fog_color: Color = Color(0.15, 0.15, 0.31, 1)
## 雾浓度
@export var fog_density: float = 1.0
## 雾垂直衰减（高度雾）
@export var fog_height_density: float = 0.5
## 雾起始深度
@export var fog_depth_begin: float = 3.0
## 雾结束深度
@export var fog_depth_end: float = 35.0
## 3D 视口背景色（天空盒基色）
@export var background_color: Color = Color(0.15, 0.15, 0.31, 1)

@export_group("Camera")
## 相机特效配置（震动、倾斜等）
@export var camera_config: BgCameraConfig
