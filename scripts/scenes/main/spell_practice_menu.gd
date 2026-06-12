# SpellPracticeMenu.gd
extends Control

const SPELL_ITEM = preload("res://scenes/ui/spell_practice_item.tscn")

@onready var _list: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var _detail_name: Label = $Detail/Name
@onready var _detail_story: Label = $Detail/Story
@onready var _detail_practice: Label = $Detail/Practice
@onready var _detail_best: Label = $Detail/Best

var _records: SpellRecordBook
var _selected_index: int = 0
var _items: Array[Control] = []


func _ready() -> void:
	visible = false
	_records = GameState.spell_book
	_build_list()
	_select(0)

func _build_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	_items.clear()
	
	for rec in _records.records:
		var item := SPELL_ITEM.instantiate()
		_list.add_child(item)
		item.text = rec.get("spell_name")
		_items.append(item)

func _select(idx: int) -> void:
	if _items.is_empty(): return
	
	_selected_index = clampi(idx, 0, _items.size() - 1)
	
	for i in range(_items.size()):
		_items[i].selected = (i == _selected_index)
	
	var rec := _records.records[_selected_index]
	_detail_name.text = rec.get("spell_name")
	_detail_story.text = "故事: %d/%d" % [rec.get("captures"), rec.get("attempts")]
	_detail_practice.text = "练习: %d/%d" % [rec.get("practice_captures"), rec.get("practice_attempts")]
	_detail_best.text = "最高分: %d" % rec.get("best_score")

func _input(event: InputEvent) -> void:
	if not visible: return
	
	if event.is_action_pressed("ui_up"):
		_select(_selected_index - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_select(_selected_index + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_start_practice()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	visible = false
	queue_free()

func _start_practice() -> void:
	if _items.is_empty(): return
	var rec := _records.records[_selected_index]
	var spell_id: int = rec.get("spell_id")
	# TODO: 找 PhaseData 传进 game_scene 练习模式
	print("开始练习: ", rec.get("spell_name"), " (id=", spell_id, ")")

func open() -> void:
	visible = true
	_select(0)
