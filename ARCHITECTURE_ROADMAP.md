# 🏗️ 背景系统 & StageAPI 架构演进路线

> 版本 2026-06-18 · 基于现状分析的长远设计

---

## 目录

1. [现状分析](#一现状分析)
2. [Decor 分层 + 可移除](#二decor-分层--可移除)
3. [StageAPI 拆服务](#三stageapi-拆服务)
4. [BackgroundAsset 数据驱动](#四backgroundasset-数据驱动)
5. [时间线系统](#五时间线系统)
6. [编辑器集成](#六编辑器集成)
7. [迁移路线图](#七迁移路线图)

---

## 一、现状分析

### 当前架构

```
StageAPI (万物之源)
  ├─ 子弹 / 激光 / 敌机 / 道具 / 装饰 / 时间 / 玩家 …
  └─ 协程只能拿到这一个对象

BackgroundScript
  └─ 挂在一个 Node 上 → _on_init → start_background → _on_step(api)
       └─ DecorBatcher: 一张贴图 = 一个 MultiMesh 组
```

### 核心问题

| 问题 | 影响 |
|------|------|
| StageAPI 是上帝对象 | 200+ 行，职责不清，测试困难 |
| Decor 不分层 | 所有装饰物同质化，无 LOD，无远近 |
| 装饰物不可管理 | spawn 后无法移除/移动/查询 |
| 视觉效果硬编码 | 换雾色要改代码重跑 |
| 协程无时间感知 | 做时间线全靠手动计时 |
| 无编辑器工具 | 调参数靠猜 + 重跑 |

---

## 二、Decor 分层 + 可移除

### 目标

```
相机 → 往前走 →

    spawn_band: [-200, -100]         spawn_band: [-80, -20]
    ┌─────────────────────┐          ┌──────────────────┐
    │ Layer "橡树"         │          │ Layer "石头"       │
    │ tex: oak.png         │          │ tex: rock.png      │
    │ size: 8 (世界固定)   │          │ size: 3             │
    │ 密度: 0.3/m          │          │ 密度: 0.5/m         │
    │ LOD: 150m 裁剪       │          │ LOD: 80m 裁剪       │
    └─────────────────────┘          └──────────────────┘
                     │ 透视自然变小      │ 透视自然变大
                     ▼                  ▼
               远处看起来小         近处看起来大

★ 关键是：装饰物的世界空间尺寸固定不变。
  远小近大交给 3D 透视投影自动处理，不需要手动调。
  LOD 只做"远处跳过渲染省性能"这一个事。
  层按物种分（橡树/松树/石头/草），不按远近分。
```

### 新资源：DecorLayer

```gdscript
# data/decor_layers/forest_oak.tres
class_name DecorLayer
extends Resource

@export var name: String = ""             ## 层名（调试用）
@export var texture: Texture2D
@export var size_min: Vector2 = Vector2(4, 4)
@export var size_max: Vector2 = Vector2(16, 16)
@export var density: float = 0.5           ## 每米密度
@export var y_offset: float = 0.0           ## 垂直偏移
@export var y_variance: float = 0.0         ## 垂直随机
@export var scroll_mult: float = 1.0        ## 滚动倍率
@export var spawn_band: Vector2 = Vector2(-200, 0)  ## 在相机前方多远区间生成
@export var lod_distance: float = 150.0     ## 超过此距离裁剪
@export var alpha_mode: int = 0             ## 0=SCISSOR, 1=BLEND
@export var alpha_threshold: float = 0.5
@export var billboard: bool = true
```

> **spawn_band** 只决定**在什么 Z 区间生成新实例**。
> 生成后实例在世界空间里不动，靠透视自然呈现远近。
> 相机追上来后它变"近景"，大小由 3D 透视自然处理。

### 新类：DecorInstance

```gdscript
class DecorInstance:
    var position: Vector3
    var scale: Vector2
    var layer: DecorLayer
    var follow_plane: BackgroundPlane
    var spawn_time: float
    var lifetime: float = -1.0   ## -1 = 永久
    var alive: bool = true

    func age() -> float:         ## 存活时间
    func alpha() -> float:       ## 淡入淡出计算
```

### 新类：DecorManager

```gdscript
class_name DecorManager
extends Node3D

var _layers: Dictionary = {}  ## DecorLayer → _LayerGroup
var _all_instances: Array[DecorInstance] = []

class _LayerGroup:
    var multi_mesh: MultiMesh
    var mmi: MultiMeshInstance3D
    var instances: Array[DecorInstance]
    var dirty: bool

## API
func add_layer(layer: DecorLayer) -> void
func remove_layer(layer: DecorLayer) -> void
func spawn(layer: DecorLayer, pos: Vector3, scale: Vector2, follow: BackgroundPlane, lifetime: float = -1.0) -> DecorInstance
func remove(inst: DecorInstance) -> void
func clear_layer(layer: DecorLayer) -> void
func batch_spawn(layer: DecorLayer, count: int, band: Vector2, follow: BackgroundPlane) -> void

## 内部
func _process(delta):
    for each layer:
        for inst in instances:
            if inst.lifetime > 0 and inst.age() > inst.lifetime:
                inst.alive = false
                inst.fade_out()
            update_transform(inst)  ## 跟摄像机滚动
            lod_check(inst)         ## 距离裁剪（纯性能）
        flush_dirty_if_needed()   ## 定时刷新 MultiMesh
```

### LOD 裁剪（纯性能，不动尺寸）

```gdscript
func _is_visible(inst: DecorInstance, camera: Camera3D) -> bool:
    if camera.is_position_behind(inst.position):
        return false
    var dist := camera.global_position.distance_to(inst.position)
    return dist < inst.layer.lod_distance
```

- 距离镜头 0~lod/2 ：正常渲染
- 距离镜头 lod/2~lod ：跳过 MultiMesh 更新（省 CPU）
- 距离镜头 > lod ：直接裁剪（省 GPU）

> 裁剪只影响是否提交渲染，不影响世界大小。
> 透视投影自动处理"远的物体看起来小"。

### 好在哪里

#### 1. 物种分层 — 自然且灵活

```
Layer "橡树"    spawn_band: [-200, -80]   每层独立密度、独立裁剪距离
Layer "松树"    spawn_band: [-200, -120]  不同层可以重叠 spawn 区间
Layer "石头"    spawn_band: [-100, -20]
Layer "草"      spawn_band: [-40, 0]
```

同一张贴图可以注册多个层——"远景大橡树"和"近景小橡树"如果尺寸不同就两个层，
如果尺寸一样就一个层，靠 spawn_band 控制生成区间。

#### 2. 可移除 — 现在完全做不到

```gdscript
# Boss 符卡结束后：飘过的树被弹幕吹散
for tree in ctx.decor.get_in_region(aabb):
    tree.fade_out(1.0)
    tree.lifetime = 1.0

# 过场动画：树从黑雾里显现
var tree = ctx.decor.spawn("oak", pos, scale, ground)
tree.fade_in(3.0)
```

#### 3. 数据驱动 — 换关不换代码

```
关卡 1: add_layer(oak) + add_layer(rock)
关卡 2: add_layer(pine) + add_layer(snow_bush)
关卡 3: add_layer(pine) + add_layer(oak) + add_layer(grass)
```

创建一次 `.tres`，全局复用。

### 会有反而麻烦的地方

| 场景 | 会不会 | 说明 |
|------|--------|------|
| 简单关卡只有一种装饰 | 不会 | 保留 `default` 层，一行代码不用多 |
| 配置变多了 | 会 | 每层要建 `.tres`，但建一次全局复用 |
| 同贴图多层变多个 draw call | 会 | 但 GPU 瓶颈在 fill 不在 draw call，影响≈0 |
| 旧代码 | 不会 | DecorBatcher 保留，旧关卡不动 |

### 扩展方向（未实现）

- **alpha 控制**：DecorEntry 加 `modulate.a` 字段，支持 `fade_in(duration)` / `fade_out(duration)`
- **动画**：scale / rotation / position 随时间插值（摇摆、漂浮、散落）
- **查询**：`ctx.decor.get_in_region(aabb)` 拿范围内的实例列表，用于"弹幕吹散范围内的树"
- **条件生成**：`spawn_when(condition)` — 只在某个条件满足后才生成（如"雾散了才 spawn 中景"）
- **LOD 降级**：远距离用低分辨率贴图或减少实例密度
- **剔除回调**：实例被裁剪/回收时触发事件（播放粒子、掉道具等）

### 迁移步骤

1. 新建 `DecorLayer` 资源类 + 在 `data/decor_layers/` 创建第一个 `.tres`
2. 新建 `DecorManager` 替代 `DecorBatcher`
3. 更新 `StageAPI.spawn_decor_batched` → `DecorService.spawn`
4. `BackgroundScript._on_init` 里注册 layer
5. 旧 `DecorBatcher` 保留，新关卡用 `DecorManager`

---

## 三、StageAPI 拆服务

### 目标

```gdscript
# 协程只拿需要的服务
func _on_step(ctx: StageContext):
    ctx.bullets.shoot_spread(...)
    ctx.enemies.spawn(data, pos)
    ctx.decor.spawn("forest_trees", pos, scale)
    ctx.clock.wait(2.0)
    var player_pos = ctx.player.position
```

### 新类：StageContext

```gdscript
class_name StageContext
extends RefCounted

var bullets: BulletService
var enemies: EnemyService
var decor: DecorService
var player: PlayerService
var clock: ClockService
var events: GameEvents     ## 只读信号
var state: GameState       ## 只读数据
```

### 服务拆分

| 服务 | 职责 | 来源 |
|------|------|------|
| `BulletService` | 子弹发射、激光、消弹 | 拆自 BulletManager + StageAPI |
| `EnemyService` | 敌机/Boss 生成 | 拆自 StageManager |
| `DecorService` | 装饰物生成 | 拆自 DecorManager |
| `PlayerService` | 只读玩家（位置、无敌、低速、hitbox） | 拆自 Player |
| `ClockService` | 时间等待、帧计数、delta | 新增 |

### BulletService

```gdscript
class_name BulletService
extends RefCounted

func shoot_spread(data: BulletData, count: int, angle: float, dir: Vector2, origin: Vector2) -> Array[Bullet]
func shoot_aimed(data: BulletData, speed: float, target: Vector2, origin: Vector2) -> Bullet
func shoot_ring(data: BulletData, count: int, origin: Vector2, speed: float, offset_angle: float = 0)
func shoot_arc(data: BulletData, count: int, start_angle: float, end_angle: float, origin: Vector2)
func fire_laser(data: CurvedLaserData, origin: Vector2, length: float) -> CurvedLaser
func clear_area(center: Vector2, radius: float, duration: float)
func clear_all()
```

### ClockService

```gdscript
class_name ClockService
extends RefCounted

var elapsed: float = 0.0         ## 关卡总时长
var delta: float = 0.0           ## 当前帧 delta

func wait(seconds: float) -> bool   ## 替换 api.seconds()
func wait_frames(count: int) -> bool
func tick(dt: float) -> void
```

### 协程接口变更

```gdscript
# 旧
func _on_step(api: StageAPI) -> Variant:
    api.shoot_spread(...)
    return api.seconds(2.0)

# 新
func _on_step(ctx: StageContext) -> Variant:
    ctx.bullets.shoot_spread(...)
    return ctx.clock.wait(2.0)
```

### 向后兼容

`StageAPI` 保留，内部委托给各服务：

```gdscript
class StageAPI:
    var _ctx: StageContext

    func shoot_spread(...):
        return _ctx.bullets.shoot_spread(...)

    func seconds(d: float):
        return _ctx.clock.wait(d)
```

新旧协程都可以跑。

### 迁移步骤

1. 新建 5 个 Service 类
2. 新建 `StageContext`
3. `StageManager.load_stage` 创建 Context → 注入协程
4. `StageAPI` 改为薄门面，委托 Context
5. 逐步迁移所有协程到新接口
6. 删旧 StageAPI 大统一方法

---

## 四、BackgroundAsset 数据驱动

### 目标

一份 `.tres` 描述整个关卡的视觉演出。换关卡 = 换资源，不改代码。

```gdscript
# data/backgrounds/stage1_normal.tres
BackgroundAsset
  fog_keyframes = [
    {time: 0, color: Color.BLACK, density: 0.5, ease: LINEAR},
    {time: 6, color: Color("#191919"), density: 0.04, ease: EASE_OUT},
    {time: 30, color: Color("#2a2a3a"), density: 0.02, ease: LINEAR},
  ]
  light_keyframes = [
    {time: 0, energy: 0, color: Color.BLACK},
    {time: 8, energy: 1.0, color: Color("#ffe0c0")},
  ]
  camera_path = [
    {time: 0, pos: (0,10,0), rot: (0,0,0), fov: 55, ease: LINEAR},
    {time: 8, pos: (0,18,-3), rot: (-22,0,6), fov: 68, ease: EASE_IN_OUT},
  ]
  color_grading = [
    {time: 0, brightness: 0.8, contrast: 1.0, saturation: 0.9},
    {time: 10, brightness: 1.0, contrast: 1.1, saturation: 1.0},
  ]
  decor_phases = [
    {time: 0, layer: "forest_trees", count: 240, region: (-70,-200) ~ (70,0)},
    {time: 12, layer: "rocks", count: 60, region: (-50,-150) ~ (50,-50)},
  ]
  sun_rotation = [
    {time: 0, rot: (-30, 45, 0)},
    {time: 20, rot: (-10, 90, 0)},
  ]
```

### 新资源类

```gdscript
class_name BackgroundAsset
extends Resource

@export var fog_keyframes: Array[FogKeyframe] = []
@export var light_keyframes: Array[LightKeyframe] = []
@export var camera_path: Array[CameraKeyframe] = []
@export var color_grading: Array[ColorGradingKeyframe] = []
@export var decor_phases: Array[DecorPhase] = []
@export var sun_rotation: Array[SunRotationKeyframe] = []

# Keyframe 子资源
class FogKeyframe:
    extends Resource
    @export var time: float
    @export var color: Color
    @export var density: float
    @export var ease: int = 0
```

### 新类：BackgroundComposer

```gdscript
class_name BackgroundComposer
extends Node

var asset: BackgroundAsset
var env_timeline: EnvTimeline
var camera_animator: CameraAnimator
var decor_manager: DecorManager
var elapsed: float = 0.0

func load(asset: BackgroundAsset) -> void
func tick(delta: float) -> void       ## 每帧驱动
func seek(time: float) -> void        ## 跳转（预览用）
func play() / pause() / stop()

## 内部
func _eval_keyframes[T](keyframes: Array, time: float, getter: Callable, setter: Callable)
```

### EnvTimeline

```gdscript
class_name EnvTimeline
extends RefCounted

var fog_kf: Array[FogKeyframe]
var light_kf: Array[LightKeyframe]
var color_kf: Array[ColorGradingKeyframe]

func evaluate(time: float, env: Environment, sun: DirectionalLight3D) -> void
```

### CameraAnimator

```gdscript
class_name CameraAnimator
extends RefCounted

var path: Array[CameraKeyframe]

func evaluate(time: float, camera: Camera3D) -> void
func find_segment(time: float) -> Array  ## [prev_kf, next_kf]
func interpolate(prev, next: CameraKeyframe, t: float) -> Transform3D
```

### 迁移步骤

1. 新建 `FogKeyframe`, `LightKeyframe` 等子资源类
2. 新建 `BackgroundAsset` + `BackgroundComposer`
3. 新建 `EnvTimeline` + `CameraAnimator`
4. 把 `stage01_decor.gd` 里的雾/光/相机逻辑抽成第一个 `.tres`
5. 保留 `BackgroundScript` 作为自定义逻辑的兜底

---

## 五、时间线系统

### 目标

声明式编排。可跳转、可快进、可预览。

```gdscript
# StageScript 内部
var timeline: Timeline

func _on_init(ctx):
    timeline = Timeline.new(ctx)
    timeline.at(0).play_bgm("stage1.mp3")
    timeline.at(3).spawn_wave(wave1_data, pos, 5)
    timeline.at(8).spawn_boss(boss_data, pos, defer: true)
    timeline.at(14).call(boss, "begin_battle")
    timeline.at(60).fade_out()
    timeline.at(62).clear_screen()

func _on_step(ctx):
    return timeline.tick(ctx.clock.delta)
```

### 新类：Timeline

```gdscript
class_name Timeline
extends RefCounted

signal finished

var _events: Array[TimelineEvent] = []
var _elapsed: float = 0.0
var _paused: bool = false

## 流式 API
func at(time: float) -> TimelineBuilder:
    return TimelineBuilder.new(self, time)

func tick(delta: float) -> Variant:
    if _paused: return true
    _elapsed += delta
    _fire_due_events()
    return true  ## 未完继续

func seek(time: float) -> void
func pause() / resume()
func reset()

## 内部
func _fire_due_events():
    for ev in _events:
        if not ev.fired and _elapsed >= ev.time:
            ev.execute()
            ev.fired = true
```

### TimelineBuilder

```gdscript
class TimelineBuilder:
    var _timeline: Timeline
    var _time: float

    func spawn_wave(data, pos, count) -> TimelineBuilder
    func spawn_enemy(data, pos) -> TimelineBuilder
    func spawn_boss(data, pos, defer: bool) -> TimelineBuilder
    func play_bgm(path: String) -> TimelineBuilder
    func call(target, method: String, args: Array = []) -> TimelineBuilder
    func emit(sig: Signal) -> TimelineBuilder
    func wait(seconds: float) -> TimelineBuilder
    func fade_out(duration: float = 1.0) -> TimelineBuilder
    func clear_screen() -> TimelineBuilder
```

### TimelineEvent

```gdscript
class TimelineEvent:
    var time: float
    var callback: Callable
    var fired: bool = false
    var args: Array = []

    func execute():
        callback.callv(args)
```

### 与 BackgroundAsset 的关系

`BackgroundAsset` 里的 fog/light/camera keyframe 本质上也是时间线事件，但更专门化。可以共用基础设施：

```gdscript
class KeyframeTimeline[T]:
    extends Timeline
    var keyframes: Array[T]
    func tick(delta):
        super.tick(delta)
        evaluate_keyframes(_elapsed)
```

### 迁移步骤

1. 新建 `Timeline` + `TimelineBuilder` + `TimelineEvent`
2. 在 `StageScript` 基类加 `var timeline: Timeline`
3. `stage01_easy.gd` 改为时间线写法
4. 保留旧 `_on_step` 模式作为 fallback
5. `BackgroundComposer` 用 `KeyframeTimeline` 驱动 env

---

## 六、编辑器集成

### 目标

Godot 内实时预览 + 拖拽编排。

```
┌─ Background Editor ──────────────────────────────────┐
│                                                       │
│  [Timeline] ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░  0:08 / 60 │
│                                                       │
│  Fog ──────────────────────────────────────────────── │
│  ██ 0.0s  BLACK  dens 0.5                            │
│  ██ 6.0s  #1919  dens 0.04                           │
│  ██ 30.0s #2a2a  dens 0.02                           │
│                                      [+ Add Keyframe] │
│                                                       │
│  Light ────────────────────────────────────────────── │
│  ██ 0.0s  energy 0  color BLACK                       │
│  ██ 8.0s  energy 1  color #ffe0c0                     │
│                                      [+ Add Keyframe] │
│                                                       │
│  Camera ───────────────────────────────────────────── │
│  ▣ 0.0s  (0,10,0)  rot(0,0,0)  fov 55                │
│  ▣ 8.0s  (0,18,-3) rot(-22,0,6) fov 68               │
│                         [Record Current] [+ Add]      │
│                                                       │
│  Decor Layers ─────────────────────────────────────── │
│  ☑ forest_trees  tex:○  size:[16,24]  dens:0.3       │
│  ☑ rocks         tex:○  size:[4,8]    dens:0.5       │
│  ☐ grass         tex:○  size:[1,2]    dens:1.0       │
│                                      [+ Add Layer]    │
│                                                       │
│  [▶ Preview]  [⏸ Pause]  [🔽 Export .tres]           │
└───────────────────────────────────────────────────────┘
```

### 组件拆分

#### 6.1 BackgroundAssetInspector

自定义 Inspector 面板，`BackgroundAsset` 选中时显示时间轴 + 可编辑 keyframe。

```gdscript
@tool
class_name BackgroundAssetInspector
extends EditorInspectorPlugin

func _can_handle(object) -> bool:
    return object is BackgroundAsset

func _parse_begin(object) -> void:
    # 解析 fog_keyframes, light_keyframes 等数组
    # 在 Inspector 里渲染时间轴 UI
```

#### 6.2 BackgroundEditorPanel

底部面板（Bottom Panel），显示时间轴条形图 + 拖拽滑块。

```gdscript
@tool
class_name BackgroundEditorPanel
extends Control

var _asset: BackgroundAsset
var _timeline_slider: HSlider
var _selected_keyframe_index: int = -1

func load_asset(asset: BackgroundAsset) -> void
func _draw_timeline()          ## 画时间轴条形图
func _on_slider_changed(t)     ## 拖滑块 → 预览
func _add_keyframe(type)
func _remove_keyframe(index)
```

#### 6.3 LivePreview

实时预览系统：拖时间轴滑块时，游戏视口同步更新 fog/light/camera。

```gdscript
@tool
class_name BackgroundPreview
extends Node

var _composer: BackgroundComposer
var _camera: Camera3D
var _env: Environment

func setup(asset: BackgroundAsset, camera: Camera3D, env: Environment) -> void
func preview_at(time: float) -> void   ## 跳到指定时间点渲染
```

#### 6.4 CameraKeyframeRecorder

在 3D 视口里按快捷键记录当前相机位置为 keyframe。

```gdscript
@tool
class_name CameraKeyframeRecorder
extends Node

func _input(event):
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_K:  ## 按 K 记录
            _record_current()
```

#### 6.5 DecorLayer Editor

拖贴图 → 自动填充 `DecorLayer` 参数 → 实时在场景里预览生成效果。

```gdscript
@tool
class_name DecorLayerEditor
extends Control

var _layer: DecorLayer
var _preview_nodes: Array[Node3D] = []

func _on_texture_dropped(tex: Texture2D)
func _preview_spawn()
func _preview_clear()
```

### 文件清单

| 文件 | 说明 |
|------|------|
| `addons/background_editor/plugin.gd` | EditorPlugin 入口 |
| `addons/background_editor/inspector.gd` | 自定义 Inspector |
| `addons/background_editor/timeline_panel.gd` | 底部时间轴面板 |
| `addons/background_editor/live_preview.gd` | 实时预览驱动 |
| `addons/background_editor/camera_recorder.gd` | 相机记录快捷键 |
| `addons/background_editor/decor_layer_editor.gd` | DecorLayer 编辑器 |

### 迁移步骤

1. 新建 EditorPlugin，注册自定义 Inspector
2. 实现时间轴面板（先做 Fog + Light，最简单）
3. 实现 LivePreview（BackgroundComposer.seek）
4. 加 Camera Keyframe 记录
5. 加 DecorLayer 拖拽预览
6. 一键导出 BackgroundAsset

---

## 七、迁移路线图

```
Phase 1 ▓▓▓▓▓▓▓▓▓▓  Decor 分层 + 可移除
Phase 2 ▓▓▓▓▓▓▓▓▓▓  StageAPI 拆服务
Phase 3 ▓▓▓▓▓▓░░░░  BackgroundAsset 数据驱动
Phase 4 ▓▓▓▓▓▓░░░░  时间线系统
Phase 5 ▓▓▓░░░░░░░  编辑器集成
```

| 阶段 | 依赖 | 可并行？ | 预计文件数 |
|------|------|---------|----------|
| 1. Decor 分层 | 无 | ✅ 独立 | ~4 新文件 |
| 2. API 拆分 | Decor 分层做完更好 | ⚠️ 建议串行 | ~8 新文件 |
| 3. 数据驱动 | API 拆分做完更好 | ⚠️ 建议串行 | ~6 新文件 |
| 4. 时间线 | 数据驱动的基础设施 | ✅ 可并行 | ~4 新文件 |
| 5. 编辑器 | 数据驱动 + 时间线 | 🔴 最后的 | ~6 新文件 |

### 向后兼容策略

- 所有新系统保留旧接口作为 fallback
- `BackgroundScript._on_step(api)` 继续支持
- `DecorBatcher` 保留但标记 deprecated
- 新旧可混用——逐步迁移，不用一次性全部改完
