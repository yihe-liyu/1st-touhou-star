# 背景系统重构计划

> 分步推进，每步完成后肉眼确认效果，再进下一步。

---

## 总目标

从现在的「一个 256×256 PlaneMesh + 手写 meta」升级为：
- **积木式节点**（Plane / Cylinder / Scroll / 装饰物）拖进场景即用
- **舞台状态机**（NORMAL → BOSS_WARNING → BOSS → SPELL）自动渐变
- **配置在 Inspector**，不用写代码

---

## Step 1：BackgroundPlane 节点 ✅ 完成

### 做什么
新建一个 `BackgroundPlane` 节点，把一个彩色测试平面渲染到背景上。

### 文件
新建 `scripts/background/background_plane.gd`

```gdscript
class_name BackgroundPlane
extends MeshInstance3D

@export var plane_size: Vector2 = Vector2(256, 256)
@export var tiling: Vector2 = Vector2(6, 6)
@export var scroll_speed: Vector2 = Vector2(0, 1.0)
@export var modulate: Color = Color.WHITE

func _ready():
    var mesh := PlaneMesh.new()
    mesh.size = plane_size
    mesh.orientation = PlaneMesh.FACE_Z  # 平放
    self.mesh = mesh
    
    var mat := ShaderMaterial.new()
    mat.shader = preload("res://gdshader/background_plane.gdshader")
    mat.set_shader_parameter("tiling", tiling)
    mat.set_shader_parameter("modulate", modulate)
    self.material_override = mat

func _process(delta):
    var mat := material_override as ShaderMaterial
    if mat:
        var uv := mat.get_shader_parameter("uv_offset") as Vector2
        uv += scroll_speed * delta
        mat.set_shader_parameter("uv_offset", uv)
```

### 需要新 Shader
新建 `gdshader/background_plane.gdshader`

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D base_texture : source_color;
uniform vec2 tiling = vec2(6.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec4 modulate : source_color = vec4(1.0);

void fragment() {
    vec2 uv = UV * tiling + uv_offset;
    vec4 col = texture(base_texture, uv);
    ALBEDO = col.rgb * modulate.rgb;
    ALPHA = col.a * modulate.a;
}
```

### 测试
在 `stage01_background.tscn` 里删掉现有地面 MeshInstance，换成：
```
Stage01Background (Node3D)
├─ BackgroundPlane  # 删掉旧 Mesh，加这个
│    plane_size = (256, 256)
│    tiling = (6, 6)
│    scroll_speed = (0, 1)
│    base_texture = grass.jpeg
├─ WorldEnvironment   # 保留
└─ Camera3D           # 保留 (SubViewport 里的)
```

### 验收标准
- ✅ 进游戏看到草地在滚动
- ✅ Inspector 改 scroll_speed 数值即时生效
- ✅ 改 tiling 即时生效

---

## Step 2：多平面视差测试

### 做什么
用一个**紫色平面**和一个**绿色平面**，放在不同 z 深度，确认视差效果。

### 不再写新代码
直接改 Step 1 的 tscn，临时加两个 BackgroundPlane：

```
Stage01Background
├─ BackgroundPlane "FarTest"
│   z = -200, base_texture = None, modulate = 紫色
│   scroll_speed = (0.1, 0)
├─ BackgroundPlane "NearTest"
│   z = -30, base_texture = None, modulate = 绿色  
│   scroll_speed = (1.0, 0)
├─ WorldEnvironment
└─ Camera3D
```

### 验收标准
- ✅ 远景紫色滚动慢，近景绿色滚动快
- ✅ 自然视差不用调 parallax 系数

---

## Step 3：替换草地图 + 加更多层

### 做什么
把彩色测试面换回真实贴图，组合出一个基本舞台背景。

### 结构
```
stage01_background
├─ BackgroundPlane "Sky"    z=-300  scroll=(0.02,0)  天空贴图
├─ BackgroundPlane "Clouds" z=-180  scroll=(0.1,0)   云层贴图
├─ BackgroundPlane "Hills"  z=-80   scroll=(0.4,0)   远山剪影
├─ BackgroundPlane "Ground" z=-30   scroll=(0, 1.5)  草地
├─ WorldEnvironment
└─ Camera3D
```

### 验收标准
- ✅ 四层同时滚动，速度逐级变快
- ✅ 远山比地面慢 = 视差正确
- ✅ 看起来像个舞台

---

## Step 4：BackgroundCylinder 节点

### 做什么
新建圆柱体节点，解决「天空穹顶」和「环绕云层」——平面走到边界就没了，圆柱体永远有内容。

### 文件
新建 `scripts/background/background_cylinder.gd`

```gdscript
class_name BackgroundCylinder
extends MeshInstance3D

@export var radius: float = 200.0
@export var height: float = 100.0
@export var tiling_u: float = 4.0
@export var tiling_v: float = 1.0
@export var scroll_speed: float = 0.05
@export var modulate: Color = Color.WHITE

func _ready():
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    self.mesh = mesh
    
    var mat := ShaderMaterial.new()
    mat.shader = preload("res://gdshader/background_plane.gdshader")  # 复用
    mat.set_shader_parameter("tiling", Vector2(tiling_u, tiling_v))
    mat.set_shader_parameter("modulate", modulate)
    self.material_override = mat

func _process(delta):
    var mat := material_override as ShaderMaterial
    if mat:
        var uv := mat.get_shader_parameter("uv_offset") as Vector2
        uv.x += scroll_speed * delta
        mat.set_shader_parameter("uv_offset", uv)
```

### 测试
```
stage01_background
├─ BackgroundCylinder "CloudDome"  z=-100  radius=200  height=80
└─ ...现有平面层...
```

### 验收标准
- ✅ 圆柱体外侧有贴图，水平循环
- ✅ 贴图水平滚动不断
- ✅ Inspector 改 radius / height 即时生效

---

## Step 5：BackgroundScroll 打包节点

### 做什么
有些东西不是平面——比如一棵树、一根柱子。把这些 3D 物体打包成一个组，统一滚动。

### 文件
新建 `scripts/background/background_scroll.gd`

```gdscript
class_name BackgroundScroll
extends Node3D

@export var scroll_speed: Vector2

func _process(delta):
    # 和 BackgroundPlane 不同 —— 这儿是移动整个节点，不是 UV
    # 循环：走完一个周期就重置回原位
    for child in get_children():
        if child is Node3D:
            child.position.x -= scroll_speed.x * delta
            # 循环逻辑：超出左边界 → 移到右边界
            # 具体范围由子类或 Inspector 设置
```

### 注意
循环滚动比较棘手——需要知道「一个周期」是多长。暂时先只做单向移动，循环以后再说。

### 验收标准
- ✅ 打包一组物体，统一往左滚
- ✅ 物体保留自己原来的形状/贴图

---

## Step 6：舞台状态机（StageBackground 基类改造）

### 做什么
给 `StageBackground` 加状态枚举和渐变切换。

### 改动 `scripts/background/stage_background.gd`

```gdscript
# 追加到现有 StageBackground 后面

enum State { NORMAL, BOSS_WARNING, BOSS, SPELL, CLEAR }

var _state: State = State.NORMAL
var _current_config: Dictionary = {}

# 每个状态的目标参数（子类在 _on_setup 里填）
var state_configs: Dictionary = {
    State.NORMAL:       { fog_color=Color.WHITE, fog_density=0.01, fov=70.0, scroll_mult=1.0 },
    State.BOSS_WARNING: { fog_color=Color(0.4,0.1,0.5), fog_density=0.03, fov=68.0, scroll_mult=0.7 },
    State.BOSS:         { fog_color=Color(0.2,0.05,0.3), fog_density=0.06, fov=60.0, scroll_mult=0.4 },
    State.SPELL:        { fog_color=Color.BLACK, fog_density=0.10, fov=55.0, scroll_mult=0.2 },
    State.CLEAR:        { fog_color=Color.WHITE, fog_density=0.0, fov=70.0, scroll_mult=1.0 },
}

var _fog_color: Color = Color.WHITE
var _fog_density: float = 0.00
var _scroll_mult: float = 1.0

func set_state(new_state: State, duration: float = 1.5):
    if new_state == _state:
        return
    var config = state_configs[new_state]
    var old_config = state_configs[_state]
    _state = new_state
    
    var t = create_tween().set_parallel(true)
    t.tween_method(_set_fog_color, old_config.fog_color, config.fog_color, duration)
    t.tween_method(_set_fog_density, old_config.fog_density, config.fog_density, duration)
    t.tween_property(self, "_scroll_mult", config.scroll_mult, duration)
    if camera:
        t.tween_property(camera, "fov", config.fov, duration)

func _set_fog_color(c: Color):
    _fog_color = c
    _apply_fog()

func _set_fog_density(d: float):
    _fog_density = d
    _apply_fog()

func _apply_fog():
    var env := _find_world_environment()
    if env and env.environment:
        env.environment.fog_light_color = _fog_color
        env.environment.fog_density = _fog_density

func _find_world_environment() -> WorldEnvironment:
    for child in get_children():
        if child is WorldEnvironment:
            return child
    return null
```

但等等——`_scroll_mult` 怎么影响 BackgroundPlane？

BackgroundPlane 的 `_process` 里：
```gdscript
uv += scroll_speed * delta * _scroll_mult
```

`_scroll_mult` 由父级 `StageBackground` 通知下来。两种方式：
- A) BackgroundPlane 自己 `get_parent()` 拿 `_scroll_mult`
- B) StageBackground 每帧遍历子节点 `set_meta`

选 B，因为不依赖结构：

```gdscript
# StageBackground._process 里追加
func _process(delta):
    # ... 现有逻辑 ...
    for child in get_children_recursive():
        if child.has_method("set_scroll_mult"):
            child.set_scroll_mult(_scroll_mult)
```

BackgroundPlane 加一个方法：
```gdscript
var _scroll_mult: float = 1.0
func set_scroll_mult(m: float): _scroll_mult = m
# _process 里 uv += scroll_speed * delta * _scroll_mult
```

### 测试
在某个舞台脚本里调用：
```gdscript
Background.set_state(StageBackground.State.BOSS_WARNING)
```

### 验收标准
- ✅ 调用后 fog 颜色渐变
- ✅ 滚动速度一起变
- ✅ 1.5s 内平滑过渡

---

## Step 7：StageData 不改动 + 实际关卡使用

### 做什么
把 Stage01 背景换成新节点，舞台脚本触发状态切换。

### 改动
- `stage01_background.tscn` — 用 BackgroundPlane/Cylinder 重建
- `test_stage.gd` — Boss 登场时调 `set_state(BOSS_WARNING)` → `BOSS`
- `test_enemy_data.tres` — 挂个 boss 标签

### 验收标准
- ✅ 打到最后，背景变暗变紫
- ✅ Boss 死了，背景恢复

---

## 步骤总览

| Step | 内容 | 新文件 | 预计量 |
|------|------|--------|--------|
| 1 | BackgroundPlane + Shader | 2 | 30行 + 15行 |
| 2 | 多平面视差测试 | 0 | 改 tscn 而已 |
| 3 | 拼真实舞台背景 | 0 | 改 tscn |
| 4 | BackgroundCylinder | 1 | 25行 |
| 5 | BackgroundScroll | 1 | 20行 |
| 6 | 状态机 | 0 (改现有) | ~60行 |
| 7 | 实际关卡串联 | 0 | ~10行 |

---

## 预备资源

需要准备的贴图（现在只有 grass.jpeg）：
- 天空底图 (渐变或星空)
- 云层 (带 alpha)
- 远山剪影 (带 alpha)
- 其他舞台素材按需

先做 Step 1，用现有 grass.jpeg 测试。后续贴图可以手绘 ASCII 风格或者找免费素材。

---

## 避坑提醒

1. ~~PlaneMesh 朝向~~：`FACE_Z` = 平放地面，`FACE_Y` = 竖立墙壁。选错看不到。
2. ~~Z 坐标~~：负的才在相机前方（Camera3D 默认看 -Z）。
3. ~~unshaded~~：背景不受灯光影响，贴图什么色就显示什么色。
4. **shader 不要写 `ALPHA =`**：unshaded spatial 里设 ALPHA 会触发 alpha blending，导致平面透明/消失。
5. **runtime `PlaneMesh.new()` 不靠谱**：在 `_ready()` 里 `self.mesh = PlaneMesh.new()` 会导致渲染位置异常（飞天上）。mesh 配置放 tscn 的 `[sub_resource]` 里，脚本只改 shader 参数。
6. **`material_override` 可能被父脚本覆盖**：如果 StageBackground 的 `_update_scroll` 还在跑，它会写 `child.material_override`。优先挂 `plane_mesh.material`。
