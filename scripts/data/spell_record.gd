# SpellRecord.gd
extends Resource
class_name SpellRecord

enum Character { REIMU, MARISA }
const CHAR_NAMES := ["博丽灵梦", "雾雨魔理沙"]

enum Difficulty { EASY, NORMAL, HARD, LUNATIC, EXTRA }
const DIFF_NAMES := ["Easy", "Normal", "Hard", "Lunatic", "Extra"]

enum PhaseType { NONSPELL, SPELL }

var spell_uid: int = 0
var character: Character = Character.REIMU
var stage: int = 1
var phase_type: PhaseType = PhaseType.SPELL
var phase_number: int = 1
var difficulty: Difficulty = Difficulty.NORMAL
var spell_name: String = ""
var phase_order: int = 1

var attempts: int = 0
var captures: int = 0
var practice_attempts: int = 0
var practice_captures: int = 0
var best_score: int = 0
var best_time: float = 0.0
