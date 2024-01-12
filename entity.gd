extends Resource
class_name Entity

@export var id: int
@export var name: String = ""
@export var pronouns: Array = ["they", "them", "their", "themselves"]

@export var hp: int = 15
@export var max_hp: int = 15
@export var surrendered: bool = false
@export var dead: int = 0

@export var effects: Array = []

func is_alive():
	return dead <= 1
	
func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		hp = 0
		dead = 1
	else:
		if hp > max_hp:
			hp = max_hp
		dead = 0

func addEffect(effectBase: Effect, effectDuration: int):
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
	
func removeEffect(effectName: String):
	var index = 0
	for i in effects.size():
		if effects[i][0].name == effectName:
			index = i
	effects.remove_at(index)
	
func hasEffect(effectName: String):
	for effect in effects:
		if effect[0].name == effectName:
			return true
	return false
