extends GutTest
## StageContext 生命周期：验证服务弱引用 ctx 后不形成 RefCounted 环
## 关卡退出后 ctx 应能被正常回收（阶段 2 服务层核心防泄漏回归）

func _make_runner() -> CoroutineRunner:
	var runner := CoroutineRunner.new()
	add_child_autofree(runner)
	return runner


func test_stage_context_with_dialogue_service_is_freed():
	var runner := _make_runner()
	var ctx := StageContext.new(runner)
	var svc: DialogueService = ctx.dialogue
	assert_not_null(svc, "dialogue 服务应创建成功")
	assert_eq(svc.ctx, ctx, "服务应能访问回 ctx")
	var ctx_ref: WeakRef = weakref(ctx)
	var svc_ref: WeakRef = weakref(svc)
	ctx = null
	svc = null
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(ctx_ref.get_ref(), "StageContext 应被释放（无 RefCounted 环）")
	assert_null(svc_ref.get_ref(), "DialogueService 应随 ctx 释放")


func test_stage_context_with_item_service_is_freed():
	var runner := _make_runner()
	var ctx := StageContext.new(runner)
	var svc: ItemService = ctx.items
	assert_not_null(svc, "item 服务应创建成功")
	var ctx_ref: WeakRef = weakref(ctx)
	var svc_ref: WeakRef = weakref(svc)
	ctx = null
	svc = null
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(ctx_ref.get_ref(), "StageContext 应被释放（无 RefCounted 环）")
	assert_null(svc_ref.get_ref(), "ItemService 应随 ctx 释放")
