# 🔍 CODE REVIEW · 东方星 STG

## 🔴 P0 致命
- #1 Player.miss() await → 函数态重叠/泄露
- #2 EnemyVisual 巡逻端点动画抖闪 ✅
- #3 RNG 未使用 → replay 不可行 ✅
- #4 场景切换时 BulletManager 仍在碰撞
- #5 碰撞链路 miss() await → _physics_process 重叠（同 #1）

## 🟠 P1 高优
- #6 GameUI 碎片图标 +30px 偏移
- #7 GameUI entry_finished 时机偏小
- #8 Bomb 输入/功能缺失
- #9 `range` 变量名冲突
- #10 难度/角色菜单硬编码 keycode
- #11 SceneTransition 只等一帧

## 🟡 P2 性能/技术债
- #12 GameState._process 非游戏时跑
- #13 EnemyVisual 每帧 get_parent
- #14 BulletPool 扩容无上限
- #15 BulletMultiMesh 每帧 is_instance_valid
- #16 HitEffectPool 每帧 current_scene
- #17 StageBackground._process_events O(n)
- #18 StageAPI 持 runner 强引用
- #19 return_bullet disconnect fog 脆弱
- #20 BulletMultiMesh._groups 不清理
- #21 CurvedLaser 池复用残留
- #22 BulletFog 同纹理跳过 → tween 冲突
- #23 CoroutineRunner Array[Task] 无效注解

## 🟢 P3 风格
- #24 子弹/敌人挂载点不一致
- #25 _blur_rect 语义混乱
- #26 _on_init/start_background 时序不文档化
- #27 菜单输入体系不统一
- #28 @export 无注释
- #29 无统一日志

## 🔵 缺失功能
- #30 Item/道具系统
- #31 Boss/Spell Card
- #32 Replay 系统
- #33 关卡结算
- #34 暂停菜单缺选项
- #35 StageData 缺 bgm 字段
- #36 无手柄支持
- #37 await 深度污染（多处非协程用 await）
