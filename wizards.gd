extends Resource
class_name Wizard

@export var id: int
@export var name: String = ""
@export var pronouns: Array = ["they", "them", "their"]

@export var is_wizard: bool = true
@export var is_monster: bool = false

@export var hp: int = 15
@export var max_hp: int = 15
@export var surrendered: bool = false

@export var effects: Array = []

@export var left_hand_gestures: Array = []
@export var right_hand_gestures: Array = []

func is_alive():
	return hp > 0
	
func is_active():
	return not surrendered and is_alive()
	
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
