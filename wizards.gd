extends Entity
class_name Wizard

@export var is_wizard: bool = true
@export var is_monster: bool = false

@export var left_hand_gestures: Array = []
@export var right_hand_gestures: Array = []
@export var left_hidden: Array = []
@export var right_hidden: Array = []

func is_active():
	return not surrendered and is_alive()
	
