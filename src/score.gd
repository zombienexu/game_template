class_name Score
extends RefCounted

var value: int = 0

func add(amount: int) -> void:
	value = clampi(value + amount, 0, 100)
