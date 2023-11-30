extends Resource
class_name Monster

@export var id: int = -1
@export var name: String = ""
@export var summoner_id: int = -1
@export var pronouns: Array = ["they", "them", "their"]
@export var adjectives: PackedStringArray

@export var is_wizard: bool = false
@export var is_monster: bool = true

@export var fire: bool = false
@export var ice: bool = false

@export var hp: int = 1
@export var max_hp: int = 1
@export var aoe: bool = false

@export var effects: Array = []

func is_alive():
	return hp > 0
	
func is_active():
	return is_alive()
	
func take_damage(amount):
	hp -= amount
	if hp < 0:
		hp = 0
	elif hp > max_hp:
		hp = max_hp

func addEffect(effectName, effectDuration, effectDict):
	if not hasEffect(effectName):
		effects.append([effectDict[effectName], effectDuration])
	
func removeEffect(effectName):
	var index = 0
	for i in effects:
		if effects[i][0] == effectName:
			index = i
	effects.remove_at(index)
	
func hasEffect(effectName):
	for effect in effects:
		if effect[0].name == effectName:
			return true
	return false
