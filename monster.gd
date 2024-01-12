extends Entity
class_name Monster

@export var summoner_id: int = -1
@export var adjectives: Array

@export var is_wizard: bool = false
@export var is_monster: bool = true

@export var fire: bool = false
@export var ice: bool = false

@export var aoe: bool = false
@export var target_id: int = -1

func is_active():
	return is_alive()
