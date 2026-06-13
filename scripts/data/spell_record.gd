# SpellRecord.gd
extends Resource
class_name SpellRecord

enum Character { REIMU, MARISA }
const CHAR_NAMES := ["博丽灵梦", "雾雨魔理沙"]

enum Difficulty { EASY, NORMAL, HARD, LUNATIC, EXTRA }
const DIFF_NAMES := ["Easy", "Normal", "Hard", "Lunatic", "Extra"]

enum PhaseType { NONSPELL, SPELL }

@export var spell_uid: int = 0
@export var character: int = 0
@export var stage: int = 1
@export var phase_type: int = 0
@export var phase_number: int = 1
@export var difficulty: int = 1
@export var spell_name: String = ""
@export var phase_order: int = 1
@export var attempts: int = 0
@export var captures: int = 0
@export var practice_attempts: int = 0
@export var practice_captures: int = 0
@export var best_score: int = 0
@export var best_time: float = 0.0
