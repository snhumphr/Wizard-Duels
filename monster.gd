extends Resource
class_name Monster

@export var id: int = -1
@export var name: String = ""
@export var summoner_id: int = -1
@export var pronouns: Array = ["they", "them", "their", "themselves"]
@export var adjectives: Array

@export var is_wizard: bool = false
@export var is_monster: bool = true

@export var fire: bool = false
@export var ice: bool = false

@export var hp: int = 1
@export var max_hp: int = 1
@export var dead: int = 0

@export var aoe: bool = false
@export var target_id: int = -1

@export var effects: Array = []

func is_alive():
	return dead <= 1
	
func is_active():
	return is_alive()
	
func take_damage(amount):
	hp -= amount
	if hp <= 0:
		hp = 0
		dead = 1
	else:
		if hp > max_hp:
			hp = max_hp
		dead = 0

func addEffect(effectBase, effectDuration):
	var effect = effectBase.duplicate()
	var effectName = effect.name
	
	if hasEffect(effectName):
		var oldEff = ""
		var oldDur = -1
		for eff in effects:
			if eff[0].name == effectName:
				oldEff = eff[0]
				oldDur = eff[1]
		
		if effect.stackable and effectDuration > oldDur:
			for eff in effects:
				if eff[0].name == effectName:
					eff[1] = effectDuration
		elif effect.overlapping:
			effects.append([effect, effectDuration])
	else:
		effects.append([effect, effectDuration])
	
func removeEffect(effectName):
	var index = 0
	for i in effects.size():
		if effects[i][0].name == effectName:
			index = i
	effects.remove_at(index)
	
func hasEffect(effectName):
	for effect in effects:
		if effect[0].name == effectName:
			return true
	return false
