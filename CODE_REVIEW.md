# 🔍 东方星 STG 项目审查报告

## ✅ 已修复 (17)
| # | 问题 | 修法 |
|---|------|------|
| 1 | player.miss await 挂起 _physics_process | 无敌改 _physics_process 倒计时 |
| 2 | EnemyVisual 巡逻端点动画抖闪 | 延迟退出 idle（speed<30 持续 0.2s） |
| 3 | RNG 未使用 → replay 不可行 | 全项目 rand* → RNG.* |
| 4 | 场景切换时 bullet 碰撞 | BulletManager._processing_paused flag |
| 5 | 碰撞链路 miss await（同 #1） | 同 #1 |
| 6 | GameUI 碎片 +30px 偏移 | 碎片标记 meta 跳过位移 |
| 7 | GameUI entry_finished 偏小 | total +1.5s 缓冲最长动画 |
| 8 | Bomb 输入缺失 | cancel&bomb → X 键 |
| 9 | range 遮蔽内置 range() | → patrol_range |
| 10 | 菜单硬编码 keycode | → is_action_pressed |
| 12 | GameState 非游戏跑 _process | 监听 PLAYING 状态开关 |
| 13 | EnemyVisual 每帧 get_parent | 缓存 _parent |
| 14 | BulletPool 扩容无上限 | MAX_TOTAL=5000 硬上限 |
| 20 | BulletMultiMesh._groups 不清理 | clear() + clear_all 调 |
| 21 | CurvedLaser 复用泄漏 Line2D | _setup_line 加守卫 |
| 22 | BulletFog 旧 tween 残留 | play() 开头 kill |
| 37 | play_bgm await 杀协程 | → tween 回调 |

## ❌ 待定 (0) — 全部修完 🎉

## 🔵 Feature (7)
| # | 功能 |
|---|------|
| 30 | Item/道具系统 |
| 31 | Boss/Spell Card |
| 32 | Replay 系统 |
| 33 | 关卡结算流程 |
| 34 | 暂停菜单缺选项 |
| 35 | StageData 缺 bgm 字段 |
| 36 | 手柄支持 | 暂不需要 |
