# SpellPracticeItem.gd
extends Label

var selected: bool = false:
	set(v):
		selected = v
		modulate = Color.YELLOW if v else Color.WHITE
