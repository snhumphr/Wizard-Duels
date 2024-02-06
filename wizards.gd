extends Entity
class_name Wizard

@export var is_wizard: bool = true
@export var is_monster: bool = false

@export var left_hand_gestures: Array[String] = []
@export var right_hand_gestures: Array[String] = []
@export var left_hidden: Array[bool] = []
@export var right_hidden: Array[bool] = []

func is_active():
	return not surrendered and is_alive()
	
