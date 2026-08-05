extends SceneTree
## Debug 工具：一键生成所有符卡记录（spell_records.tres）
## 遍历 spell_registry.tres 的全部 CardDef，为每张符卡生成
## （角色 0/1 × 难度 E/N/H/L）记录 → 符卡练习菜单所有卡所有难度可直接练
##
## 用法：godot --headless --path . -s res://scripts/debug/gen_spell_records.gd


func _initialize() -> void:
	var reg: CardRegistry = load("res://data/registry/spell_registry.tres")
	var book: SpellRecordBook = load("res://data/registry/spell_records.tres")
	if not reg or not book:
		push_error("加载注册表失败")
		quit(1)
		return

	var before: int = book.records.size()
	var made := 0
	for card in reg.cards:
		if not card.phase_data or card.phase_data.uid < 0:  # 真符卡与非符都生成
			continue
		for char_idx in [0, 1]:          # 博丽灵梦 / 雾雨魔理沙
			for diff in [0, 1, 2, 3]:  # Easy / Normal / Hard / Lunatic
				var r := book.get_or_create(card.stage_id, card.order - 1, char_idx, diff,
					card.phase_data.uid, 1, 1, card.phase_data.name)
				made += 1

	book.prune_empty()  # 顺带清幽灵记录
	var err := ResourceSaver.save(book, "res://data/registry/spell_records.tres")
	if err != OK:
		push_error("保存失败 err=", err)
		quit(1)
		return
	print("✅ 符卡记录生成完成：%d 张符卡 → 新增 %d 条（原 %d 条，现 %d 条）"
		% [reg.cards.size(), made, before, book.records.size()])
	quit(0)
