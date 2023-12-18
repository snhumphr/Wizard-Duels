extends CanvasLayer

#TODO: FIX TARGETING BEING RESET TO DEFAULT WHEN YOU CHANGE THE TARGET(?) OF YOUR OTHER HAND

var spellArray = Array()
var entityArray = Array()

var effectDict = Dictionary()

var gestureQueue = Array()
var spellQueue = Array()
var targetQueue = Array()

var ordersDict = Dictionary()
# What needs to be in a set of orders submitted:
	#Left hand gesture order
	#Right hand gesture order
	#Left hand spell order
	#Right hand spell order
	#Left hand targeting order
	#Right hand targeting order
	#Any number of hand/gesture/wizard triplets
		#These are checked client-side as to whether they're valid for the effects
	#Any number of monster/target couplets
		#Again, these are checked client-side to make sure you can't order enemy/neutral monsters
		
# Experimental heat/cold rework idea:
	#Fireball/Fire Storm/Ice Storm no longer deal damage
	#Instead, they apply 0 duration Burn or Freeze
	#Burn and Freeze stack with themselves, but cancel each other out
	#Heat res protects against Burn and cold res protects against Freeze
	#Applying either status to an elemental destroys them before they can attack
	#At the end of the turn, having Burn or Freeze on you deals 5 damage
	#Problem: This makes fire/ice damage trigger after healing spells
	#Solution: Use a similar solution for healing spells, where they apply Heal effects
	#Problem: Fire Storm mutually cancelling an Ice Elemental still a problem
	#THE ABOVE SYSTEM WAS IMPLEMENTED!
	
var monsterTemplate
var adjectiveCount = 0
var stabID

var oncePerDuelSpells = Array()

var player_data
var peers = Array()

var player
var numPlayers
var turn = 0

var validGestures = ["N", "P", "W", "S", "D", "F", "C", ">"]
var validCharmGestures =  ["P", "W", "S", "D", "F", "C", ">"]
var validSpookedGestures = ["N", "P", "W", ">"]

# Called when the node enters the scene tree for the first time.
func _ready():
	player_data = load("res://player.gd")
	
	peers.append(multiplayer.get_unique_id())
	for peer in multiplayer.get_peers():
		peers.append(peer)
	peers.sort()
	seed(peers.back())
	player = peers.find(multiplayer.get_unique_id()) + 1
	#print(peers)
	
	loadSpells("res://resources/spells", spellArray)
	
	spellArray.sort_custom(spellPowerSort)
	
	for i in spellArray.size():
		spellArray[i].id = i
		if spellArray[i].name == "Stab":
			stabID = i
	spellArray.sort_custom(spellSort)
	
	self.get_node("Scroll/UI/SpellList").init(spellArray)
	
	loadEffects("res://resources/effects", effectDict)
	
	# TODO: Sort the wizardarray?
	
	var emptySpace = {}
	emptySpace.id = 0
	emptySpace.name = "Empty Space"
	emptySpace.is_wizard = false
	emptySpace.is_monster = false
	
	entityArray.append(emptySpace)
	entityArray.append(load("res://resources/wizards/wizard_one.tres"))
	entityArray.append(load("res://resources/wizards/wizard_two.tres"))
	
	monsterTemplate = load("res://resources/monsters/base.tres")
	monsterTemplate.adjectives.shuffle()
	
	for i in range(1, entityArray.size()):
		entityArray[i].id = i
		
	numPlayers = entityArray.size() - 1
	
	for i in range(0, entityArray.size()):
		gestureQueue.append(["N", "N"])
		spellQueue.append([null, null])
		targetQueue.append([-1, -1])

	process_turn()

func process_turn():
	
	decodeOrders()
	
	var turnLogQueue = []
	
	turnLogQueue.append("It is turn " + str(turn+1))
	
	for i in range(1, entityArray.size()):
		
		#Resolve gesture changes from charm/paralysis
		if entityArray[i].is_wizard and entityArray[i].is_active():
			for effect in entityArray[i].effects:
				if effect[0].paralysis:
					if effect[0].hand == "Right":
						gestureQueue[i][0] = paralyze_gesture(entityArray[i].right_hand_gestures.back())
					elif effect[0].hand == "Left":
						gestureQueue[i][1] = paralyze_gesture(entityArray[i].left_hand_gestures.back())
				elif effect[0].charm_person:
					if effect[0].hand == "Right":
						gestureQueue[i][0] = effect[0].gesture
					elif effect[0].hand == "Left":
						gestureQueue[i][1] = effect[0].gesture
		
			#Analyze gestures to determine which spells they can cast this turn
			var leftSpellOptions = analyzeGestures(i, true)
			var rightSpellOptions = analyzeGestures(i, false)
			var leftSpell = spellQueue[i][1]
			var rightSpell = spellQueue[i][0]
			
			#If the spell in their spell queue is a spell they can cast, select that spell
			if not rightSpellOptions.has(rightSpell):
				#Otherwise, select another valid spell for their current gestures
				#This automatically chooses mandatory spells if any are allowed, or the most complex spell available otherwise
				if rightSpellOptions.size() > 0 and rightSpellOptions[0]:
					#If the spell is the same hostility as the original spell, keep the old target
					#Otherwise, use the default target for that type of spell
					if not rightSpell or rightSpell.hostile != rightSpellOptions[0].hostile:
						targetQueue[i][0] = findValidTargets(rightSpellOptions[0], entityArray[i])[1]
					spellQueue[i][0] = rightSpellOptions[0]
				else:
					spellQueue[i][0] = null
				
			#Same as the above block, but hand flipped. TODO: Consider eliminating these kinds of duplicate code blocks
			if not leftSpellOptions.has(leftSpell):
				if leftSpellOptions.size() > 0 and leftSpellOptions[0]:
					if not leftSpell or leftSpell.hostile != leftSpellOptions[0].hostile:
						targetQueue[i][1] = findValidTargets(leftSpellOptions[0], entityArray[i])[1]
					spellQueue[i][1] = leftSpellOptions[0]
				else:
					spellQueue[i][1] = null
		
			var clap = 0
			
			if gestureQueue[i][0] == "C":
				clap +=1
				gestureQueue[i][0] = "N"
				
			if gestureQueue[i][1] == "C":
				clap += 1
				gestureQueue[i][1] = "N"
			#If only one clap gesture is performed, then turn it into a null gesture
			#This greatly simplifies the gesture analysis code if we assume C only exists with a successful clap
			if clap == 2:
				gestureQueue[i][0] = "C"
				gestureQueue[i][1] = "C"
				turnLogQueue.append(entityArray[i].name + " claps " + entityArray[i].pronouns[2] + " hands.")
			else:
				for gesture in gestureQueue[i]:
					var message = gesture_to_text(gesture, entityArray[i])
					if message != "":
						turnLogQueue.append(message)
		
	var spellExecutionList = []
	
	for i in range(1, entityArray.size()):
		if entityArray[i].is_wizard and entityArray[i].is_active():
			for s in spellQueue[i].size():
				var spell = spellQueue[i][s]
				if spell != null and not(s > 0 and spell.is_two_handed()):
					spellExecutionList.append([spell, i, targetQueue[i][s]]) #spell, caster, target

	castSpells(spellExecutionList, entityArray, turnLogQueue)
	
	for i in range(1, entityArray.size()):
		if entityArray[i].is_active():
			var hexList = []
			for effect in entityArray[i].effects:
				if effect[0].hex and (effect[1] == 2 or effect[1] == 0):
					hexList.append(effect[0].name)
					
			if hexList.size() > 1:
				for effectName in hexList:
					entityArray[i].removeEffect(effectName)
				turnLogQueue.append("The conflicting hexes on " + entityArray[i].name + " cancel each other out!")
	
	monsterActions(entityArray, turnLogQueue)
	
	for i in range(1, entityArray.size()):
		var burn = []
		var freeze = []
		var heals = []
		for effect in entityArray[i].effects:
			if effect[0].burn > 0:
				burn.append(effect[0].burn)
			if effect[0].freeze > 0:
				freeze.append(effect[0].freeze)
			if effect[0].heal > 0:
				heals.append(effect[0].heal)
				
		if burn.size() > 0 and freeze.size() > 0:
			turnLogQueue.append(entityArray[i].name + " remains unscathed between conflicting heat and cold!")
		else:
			for b in burn:
				entityArray[i].take_damage(b)
				turnLogQueue.append(entityArray[i].name + " is burned for " + str(b) + " damage.")
			for f in freeze:
				entityArray[i].take_damage(f)
				turnLogQueue.append(entityArray[i].name + " is chilled for " + str(f) + " damage.")
			for h in heals:
				entityArray[i].take_damage(-1*h)
				turnLogQueue.append(entityArray[i].name + " healed for " + str(h) + " hp.")
	
	var activePlayer = 0
	numPlayers = 0
		
	for i in range(1, entityArray.size()):
		
		if entityArray[i].is_wizard and entityArray[i].is_active():
			
			var spellsDisrupted = false
			for effect in entityArray[i].effects:
				if effect[0].anti_spell:
					spellsDisrupted = true
			
			if not spellsDisrupted:
				entityArray[i].right_hand_gestures.append(gestureQueue[i][0])
				entityArray[i].left_hand_gestures.append(gestureQueue[i][1])
			else:
				turnLogQueue.append(entityArray[i].name + "'s magic is disrupted!")
				entityArray[i].right_hand_gestures.append("N")
				entityArray[i].left_hand_gestures.append("N")
		
		if entityArray[i].dead == 1:
			turnLogQueue.append(entityArray[i].name + " perishes!")
			entityArray[i].dead = 2
		elif entityArray[i].dead == 0 and entityArray[i].is_wizard:
			for effect in entityArray[i].effects:
				if effect[0].surrender:
					entityArray[i].surrendered = true
					turnLogQueue.append(entityArray[i].name + " surrenders!")
					
		if entityArray[i].is_wizard or entityArray[i].is_monster:
			entityArray[i].hot = false
			entityArray[i].cold = false
			var removeEffectList = []
			for effect in entityArray[i].effects:
				if not effect[0].permanent:
					effect[1] -= 1
					if effect[1] <= 0 or not entityArray[i].is_active():
						if effect[0].fatal:
							turnLogQueue.append(entityArray[i].name + " succumbs to " + effect[0].name.to_lower() + "!")
							entityArray[i].dead = 2
						removeEffectList.append(effect[0].name)
							
			for effect_name in removeEffectList:
				entityArray[i].removeEffect(effect_name)
		
		if entityArray[i].is_wizard and entityArray[i].is_active():
			numPlayers += 1
			activePlayer = i
			
			gestureQueue[i] = ["N", "N"]
			spellQueue[i] = [null, null]
			targetQueue[i] = [-1, -1]
		elif entityArray[i].is_monster:
			entityArray[i].target_id = -1
		
	ordersDict = {}
		
	if numPlayers == 1:
		turnLogQueue.append(entityArray[activePlayer].name + " has won the duel!")
		self.get_node("Scroll/UI/EndTurnButton").hide()
		self.get_node("Scroll/UI/RightHand").hide()
		self.get_node("Scroll/UI/LeftHand").hide()
	elif numPlayers == 0:
		turnLogQueue.append("All wizards have been eliminated. The duel ends in a draw.")
		self.get_node("Scroll/UI/EndTurnButton").hide()
		self.get_node("Scroll/UI/RightHand").hide()
		self.get_node("Scroll/UI/LeftHand").hide()
	else:
		turn += 1
		#player = 1
		
		while not entityArray[player].is_active():
			#player += 1
			pass
	
	self.get_node("Scroll/UI/TurnReport").render(turnLogQueue)
	
	self.renderWizardSection()

func decodeOrders():
	for key in ordersDict.keys():
		var order = ordersDict[key]
		#TODO: Check the validity of more orders
		gestureQueue[order.id] = order.gestures
		for i in order.spells.size():
			spellQueue[order.id][i] = spellSearch(order.spells[i])
		targetQueue[order.id] = order.targets
		for monster in order.monster_orders:
			if entityArray[monster[0]].is_monster and entityArray[monster[0]].summoner_id == order.id:
				entityArray[monster[0]].target_id = monster[1]
			else:
				printerr("Illegal command")
				
		for effect in order.effect_orders:
			if effect[2] == "Paralyze":
				for eff in entityArray[effect[0]].effects:
					if eff[0].paralysis and eff[0].hand == "choose" and eff[0].caster_id == order.id:
						eff[0].hand = effect[1]
			elif effect[1] == "Right" or effect[1] == "Left":
				for eff in entityArray[effect[0]].effects:
					if eff[0].charm_person and eff[0].caster_id == order.id:
						eff[0].hand = effect[1]
						eff[0].gesture = effect[2]
			else:
				printerr("Invalid command")
			#TODO: Check the validity of these orders too

func paralyze_gesture(gesture):
	match gesture:
		"S":
			return "D"
		"C":
			return "F"
		"W":
			return "P"
		_:
			return gesture

func gesture_to_text(gesture, wizard):
	
	var message = wizard.name
	var pronouns = wizard.pronouns
	
	match gesture:
		"S":
			message += " snaps " + pronouns[2] + " fingers."
		"D":
			message += " points with a single digit."
		"W":
			message += " waves " + pronouns[2] + " hand."
		"F":
			message += " wriggles " + pronouns[2] + " fingers."
		"P":
			message += " proffers " + pronouns[2] + " palm."
		">":
			message += " produces a knife!"
		_:
			message = ""
	
	return message

func castSpells(spellExecutionList, entityArray, turnLogQueue):
	#sort spells by the order their effects resolves:
	#1: dispel magic goes off
	#1.5: counterspells goes off
	#2: summons go off
	#3: temp effect applications go off
	#3.5 Reflection effects are applied before other temp effects
	#4: damage spells go off
	#5: healing spells go off
	#6: kill spells go off
	
	spellExecutionList.sort_custom(spellOrderSort)
	
	var magicDispelled = false
	var oncePerTurnSpells = []
	
	for i in spellExecutionList.size():
		
		var spell = spellExecutionList[i][0]
		var caster = entityArray[spellExecutionList[i][1]]
		var target = entityArray[spellExecutionList[i][2]]
		
		var spellFailed = false
		var targets = []
		
		if target.is_wizard or target.is_monster:
			if not spell.targetable:
				for entity in entityArray:
					if entity.is_wizard and entity.is_active() or entity.is_monster and entity.is_alive():
						targets.append(entity)
			else:
				var reflected = false
				for effect in target.effects:
					if effect[0].reflect:
						reflected = true
						break
				if reflected and spell.reflectable:
					turnLogQueue.append(target.pronouns[2].capitalize() + " spell reflects back at " + target.pronouns[1] + "!")
					targets.append(caster)
				else:
					targets.append(target)
		else:
			spellFailed = true
			#TODO: Custom text for missing vs failing to cast
		
		if magicDispelled and spell.dispellable:
			spellFailed = true
			
		if spell.once_per_turn and not spellFailed:
			for spell_id in oncePerTurnSpells:
				if spell_id == spell.id:
					spellFailed = true
			if not spellFailed:
				oncePerTurnSpells.append(spell.id)
				
		if spell.once_per_duel and not spellFailed:
			for s in oncePerDuelSpells.size():
				if oncePerDuelSpells[s][0] == caster.id and oncePerDuelSpells[s][1] == spell.id:
					spellFailed = true
			
			if not spellFailed:
				oncePerDuelSpells.append([caster.id, spell.id])
		#TODO: add more spell failure conditions
		
		if not spellFailed: 
			
			var verb = " casts "
			var target_string = ""
			var spell_name = spell.name
			if targets.size() == 1:
				if caster.id == target.id:
					target_string = caster.pronouns[3]
				else:
					target_string =  targets[0].name
				
			if not spell.is_spell:
				verb = " "
				target_string = "s " + target_string
				spell_name = spell_name.to_lower()
			elif targets.size() == 1:
				target_string = " on " + target_string
					
			var message = caster.name + verb + spell_name + target_string
			
			if not spell.is_silent:
				turnLogQueue.append(message)
			
			match spellExecutionList[i][0].effect:	
				Spell.SpellEffect.dispelMagic:
					magicDispelled = true
					for t in targets:
						if t.is_wizard:
							var dispelList = []
							for e in t.effects.size():
								if t.effects[e][0].dispellable:
									dispelList.append(t.effects[e][0].name)
								
							for effectName in dispelList:
								t.removeEffect(effectName)
								
							t.addEffect(effectDict["Shield"], 0)
						elif t.is_monster:
							t.take_damage(99)
				Spell.SpellEffect.Counter:
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							t.addEffect(effectDict["Counterspell"], 0)
						else:
							turnLogQueue.append(spellCheck)
				Spell.SpellEffect.Summon:
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							var summoner = -1
							if t.is_wizard:
								summoner = t.id
							elif t.is_monster:
								summoner = t.summoner_id
							if summoner != -1:
								var monster = monsterTemplate.duplicate()
								monster.summoner_id = summoner
								monster.name = entityArray[summoner].name + "'s " + monster.adjectives[adjectiveCount] + " " + spell.effect_name
								monster.max_hp = spell.intensity
								monster.hp = spell.intensity
								
								monster.id = entityArray.size()
								entityArray.append(monster)
								
								turnLogQueue.append("A " + monster.adjectives[adjectiveCount] + " " + spell.effect_name + " appears to serve " + entityArray[summoner].name + "!")
								adjectiveCount += 1
							else:
								turnLogQueue.append(spellCheck)
				Spell.SpellEffect.applyTempEffect:
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							var effect = effectDict[spell.effect_name]
							effect.caster_id = caster.id
							t.addEffect(effect, spell.intensity)
						else:
							turnLogQueue.append(spellCheck)
				Spell.SpellEffect.removeEnchantment:
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							if not t.is_monster:
								var dispelList = []
								for e in t.effects.size():
									if t.effects[e][0].dispellable:
										dispelList.append(t.effects[e][0].name)
									
								for effectName in dispelList:
									t.removeEffect(effectName)
							else:
								t.take_damage(99)
						else:
							turnLogQueue.append(spellCheck)
				Spell.SpellEffect.dealDamage:
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							t.take_damage(spell.intensity)
							turnLogQueue.append(t.name + " is " + spell.effect_name + " for " + str(spell.intensity) + " damage.")
						else:
							turnLogQueue.append(spellCheck)
				Spell.SpellEffect.Heal:
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							#turnLogQueue.append(t.name + " is healed for " + str(spell.intensity) + " damage.")
							var cureList = []
							for effect in t.effects:
								if effect[0].curable != 0 and spell.intensity >= effect[0].curable:
									cureList.append(effect[0].name)
							for item in cureList:
								t.removeEffect(item)
							var effect = effectDict["Heal"]
							effect.caster_id = caster.id
							effect.heal = spell.intensity
							t.addEffect(effect, 0)
						else:
							turnLogQueue.append(spellCheck)
				Spell.SpellEffect.Kill:
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							turnLogQueue.append(t.name + " is " + spell.effect_name + "!")
							t.take_damage(99)
							t.dead = 2
						else:
							turnLogQueue.append(spellCheck)
				_:
					printerr("Spell effect not recognized")
		else:
			turnLogQueue.append(caster.name + "'s spell fizzles!")

func monsterActions(entityArray, turnLogQueue):
	for i in range(1, entityArray.size()):
		var entity = entityArray[i]
		if entity.is_monster and entity.is_active():
			if entity.target_id > 0:
				var target = entityArray[entity.target_id]
				var target_name = target.name
				if entity.id == target.id:
					target_name = entity.pronouns[3]
				var shield = false
				for effect in target.effects:
					if effect[0].shield:
						shield = true
	
				var hexed = false
				var charmed = false
				for effect in entity.effects:
					if effect[0].hex:
						hexed = true
						effect[1] = 0
						if effect[0].charm_monster:
							entity.summoner_id = effect[0].caster_id
							var old_name = entity.name.split(" ")
							entity.name = entityArray[entity.summoner_id].name + "'s " + old_name[old_name.size()-2] + " " + old_name[old_name.size()-1]
				
				if hexed:
					turnLogQueue.append(entity.name + " tries to attack " + target_name + ", but " + entity.pronouns[2] + " hex prevents " + entity.pronouns[1])
				elif shield:
					turnLogQueue.append(entity.name + " attacks " + target_name + ", but " + target.pronouns[2] + " shield protects " + target.pronouns[1] + "!")
				else:
					turnLogQueue.append(entity.name + " attacks " + target_name + " for "+ str(entity.max_hp) + " damage.")
					target.take_damage(entity.max_hp)
			elif entity.aoe:
				pass

func checkSpellInterference(spell, target):
	
	if spell.blockable:
		for effect in target.effects:
			if effect[0].shield:
				return target.name + "'s shield protects them!"
		
	if spell.counterable:
		for effect in target.effects:
			if effect[0].counterspell:
				return target.name +  "'s counterspell protects them!"
		
	if spell.fire_spell: #TODO: Add elemental innate resistance here
		for effect in target.effects:
			if effect[0].fire_res and spell.hostile:
				return target.name +  " resists the fire!"
		
	if spell.ice_spell:
		for effect in target.effects:
			if effect[0].cold_res and spell.hostile:
				return target.name +  " resists the cold!"
		
	return ""

func loadSpells(path, array):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				loadSpells(path + "/" + file_name, spellArray)
			else:
				spellArray.append(load(path + "/" + file_name))
				#print("Added spell: " + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		printerr("An error occurred when trying to access the path.")

func loadEffects(path, dict):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var effect = load(path + "/" + file_name)
				dict[effect.name] = effect
			file_name = dir.get_next()
		dir.list_dir_end()

func spellSort(spellA, spellB):
	if spellA.id < spellB.id:
		return true
	else:
		return false

func spellOrderSort(spellA, spellB):
	if spellA[0].effect < spellB[0].effect:
		return true
	elif spellA[0].effect == spellB[0].effect and spellA[0].effect_name == "Reflect":
		return true
	elif spellA[0].effect == spellB[0].effect and spellA[0].intensity > spellB[0].intensity:
		return true
	else:
		return false
		
func spellPowerSort(spellA, spellB):
	if spellA.gestures.size() < spellB.gestures.size():
		return true
	elif spellA.gestures.size() == spellB.gestures.size():
		if spellA.gestures[spellA.gestures.size()-1].length() < spellB.gestures[spellB.gestures.size()-1].length():
			return true
		else:
			return false
	else:
		return false

func spellCompare(spell, targetID):
	return spell.id < targetID

func spellSearch(targetID):
	var spell = spellArray[spellArray.bsearch_custom(targetID, spellCompare)]
	if spell.id == targetID:
		return spell
	else:
		return null

func analyzeGestures(wizard_index, isLeft):
	
	var left_gestures = "".join(entityArray[wizard_index].left_hand_gestures)
	left_gestures += gestureQueue[wizard_index][1]
	
	var right_gestures = "".join(entityArray[wizard_index].right_hand_gestures)
	right_gestures += gestureQueue[wizard_index][0]
	
	var main_gestures = right_gestures
	var off_gestures = left_gestures
	
	if isLeft:
		main_gestures = left_gestures
		off_gestures = right_gestures
	
	var spellOptionsArray = []
	
	for spell in spellArray:
		var main_spell_gestures = ""
		var off_spell_gestures = ""
		
		for gesture in spell.gestures:
			if gesture.length() == 1:
				main_spell_gestures += gesture
			else:
				main_spell_gestures += gesture[0]
				off_spell_gestures += gesture[1]
				
		if main_gestures.ends_with(main_spell_gestures) and off_gestures.ends_with(off_spell_gestures):
			if spell.mandatory:
				return [spell]
			else:
				var already_cast = false
				if spell.once_per_duel:
					for s in oncePerDuelSpells.size():
						if oncePerDuelSpells[s][0] == wizard_index and oncePerDuelSpells[s][1] == spell.id:
							already_cast = true
				if not already_cast:
					spellOptionsArray.append(spell)
		elif spell.is_two_handed() and off_gestures.ends_with(main_spell_gestures) and main_gestures.ends_with(off_spell_gestures):
			var already_cast = false
			if spell.once_per_duel:
				for s in oncePerDuelSpells.size():
					if oncePerDuelSpells[s][0] == wizard_index and oncePerDuelSpells[s][1] == spell.id:
						already_cast = true
			if not already_cast:
				spellOptionsArray.append(spell)
	
	spellOptionsArray.sort_custom(spellPowerSort)
	spellOptionsArray.reverse()
	
	return spellOptionsArray

func onGestureChange(isLeft):
	var spellOptionsArray = analyzeGestures(player, isLeft)
	var spellOptions
	if isLeft:
		spellOptions = self.get_node("Scroll/UI/LeftHand/LeftHandSpellOptions")
	else:
		spellOptions = self.get_node("Scroll/UI/RightHand/RightHandSpellOptions")
	spellOptions.clear()
	for i in spellOptionsArray.size():
		spellOptions.add_item(spellOptionsArray[i].name, spellOptionsArray[i].id)
	
	if spellOptions.get_selectable_item() != -1:
		spellOptions.set_disabled(false)
		spellOptions.select(0)
		onSpellChange(isLeft)
	else:
		spellOptions.set_disabled(true)
		onSpellChange(isLeft)

func onSpellChange(isLeft):
	
	var mainHand
	var offHand
	
	if isLeft:
		mainHand = self.get_node("Scroll/UI/LeftHand/LeftHandSpellOptions")
		offHand = self.get_node("Scroll/UI/RightHand/RightHandSpellOptions")
	else:
		mainHand = self.get_node("Scroll/UI/RightHand/RightHandSpellOptions")
		offHand = self.get_node("Scroll/UI/LeftHand/LeftHandSpellOptions")
	
	var mainSpell = spellSearch(mainHand.get_selected_id())
	var offSpell = spellSearch(offHand.get_selected_id())
	
	if not mainSpell == null and mainSpell.is_two_handed():
		offHand.select(offHand.get_item_index(mainSpell.id))
		#recalculateTarget(not isLeft)
	elif not offSpell == null and offSpell.is_two_handed():
		offHand.select(-1)
		recalculateTarget(not isLeft)
		
	if not mainSpell == null and mainSpell.once_per_wizard:
		if not offSpell == null and offSpell.id == mainSpell.id:
			offHand.select(-1)
			recalculateTarget(not isLeft)
			
	recalculateTarget(isLeft)

func onTargetChange(isLeft):
	var rightSpell = spellSearch(self.get_node("Scroll/UI/RightHand/RightHandSpellOptions").get_selected_id())
	
	var rightTarget = self.get_node("Scroll/UI/RightHand/RightHandTargetingOptions")
	var leftTarget = self.get_node("Scroll/UI/LeftHand/LeftHandTargetingOptions")
	
	if rightSpell != null and rightSpell.is_two_handed():
		if isLeft:
			rightTarget.select(rightTarget.get_item_index(leftTarget.get_selected_id()))
		else:
			leftTarget.select(leftTarget.get_item_index(rightTarget.get_selected_id()))

func recalculateTarget(isLeft):
	
	var mainHand
	var mainTarget
	var mainSpell
	
	var offHand
	var offTarget
	var offSpell
	
	if isLeft:
		mainHand = self.get_node("Scroll/UI/LeftHand/LeftHandSpellOptions")
		mainTarget = self.get_node("Scroll/UI/LeftHand/LeftHandTargetingOptions")
		
		offHand = self.get_node("Scroll/UI/RightHand/RightHandSpellOptions")
		offTarget = self.get_node("Scroll/UI/RightHand/RightHandTargetingOptions")
	else:
		mainHand = self.get_node("Scroll/UI/RightHand/RightHandSpellOptions")
		mainTarget = self.get_node("Scroll/UI/RightHand/RightHandTargetingOptions")
		
		offHand = self.get_node("Scroll/UI/LeftHand/LeftHandSpellOptions")
		offTarget = self.get_node("Scroll/UI/LeftHand/LeftHandTargetingOptions")
		
	if mainHand.get_selected_id() == -1:
		mainTarget.clear()
		mainTarget.set_disabled(true)
	else:
		mainTarget.clear()
		mainTarget.set_disabled(false)
		mainSpell = spellSearch(mainHand.get_selected_id())
		var validTargets = findValidTargets(mainSpell, entityArray[player])
		for target in validTargets[0]:
			mainTarget.add_item(target.name, target.id)
		
		mainTarget.select(mainTarget.get_item_index(validTargets[1]))
		if validTargets[1] == -1:
			mainTarget.set_disabled(true)

func findValidTargets(spell, caster):
	
	var startIndex = 0
	var validTargets = []
	var preferredTargets = []
	var defaultTarget = 0
	
	if not spell.targetable:
		return [[],-1]
		
	if spell.always_targets_self:
		return[[caster], caster.id]
	
	if not spell.requires_target:
		validTargets.append(entityArray[0])
		
	for i in range(1, entityArray.size()):
		if (entityArray[i].is_wizard and entityArray[i].is_active()) or (entityArray[i].is_monster and entityArray[i].is_alive()):
			validTargets.append(entityArray[i])
			if entityArray[i].id == caster.id and not spell.hostile:
				preferredTargets.append(entityArray[i])
			elif spell.hostile and isTargetHostile(entityArray[i], caster):
				preferredTargets.append(entityArray[i])
	
	#randomize()
	#preferredTargets.shuffle()
	
	return [validTargets, preferredTargets[0].id]

func isTargetHostile(target, caster):
	
	if target.is_wizard and target.id != caster.id:
		return true
	elif target.is_monster and target.summoner_id != caster.id:
		return true
	else:
		return false

func renderWizardSection():
	self.get_node("Scroll/UI/WizardList").render(entityArray, player)
	
	self.get_node("Scroll/UI/LeftHand/LeftHandSpellOptions").clear()
	self.get_node("Scroll/UI/RightHand/RightHandSpellOptions").clear()
	self.get_node("Scroll/UI/LeftHand/LeftHandSpellOptions").set_disabled(true)
	self.get_node("Scroll/UI/RightHand/RightHandSpellOptions").set_disabled(true)
	
	self.get_node("Scroll/UI/LeftHand/LeftHandTargetingOptions").clear()
	self.get_node("Scroll/UI/RightHand/RightHandTargetingOptions").clear()
	self.get_node("Scroll/UI/LeftHand/LeftHandTargetingOptions").set_disabled(true)
	self.get_node("Scroll/UI/RightHand/RightHandTargetingOptions").set_disabled(true)
	
	self.get_node("Scroll/UI/LeftHand/LeftHandGestureOptions").clear()
	self.get_node("Scroll/UI/RightHand/RightHandGestureOptions").clear()
	
	if player < entityArray.size():
		var spooked = false
		var forgetful = false
		for effect in entityArray[player].effects:
			if effect[0].fear:
				spooked = true
			elif effect[0].amnesia:
				forgetful = true
		
		if not forgetful:
			for i in validGestures.size():
				var gesture = validGestures[i]
				if not spooked or validSpookedGestures.has(gesture):
					self.get_node("Scroll/UI/LeftHand/LeftHandGestureOptions").add_item(gesture, i)
					self.get_node("Scroll/UI/RightHand/RightHandGestureOptions").add_item(gesture, i)
		else:
			for i in validGestures.size():
				var gesture = validGestures[i]
				if gesture == entityArray[player].right_hand_gestures.back():
					self.get_node("Scroll/UI/RightHand/RightHandGestureOptions").add_item(gesture, i)
					self.get_node("Scroll/UI/RightHand/RightHandGestureOptions").select(0)
					gestureQueue[player][0] = gesture
				if gesture == entityArray[player].left_hand_gestures.back():
					self.get_node("Scroll/UI/LeftHand/LeftHandGestureOptions").add_item(gesture, i)
					self.get_node("Scroll/UI/LeftHand/LeftHandGestureOptions").select(0)
					gestureQueue[player][1] = gesture
			onGestureChange(false)
			onGestureChange(true)
				
	self.get_node("Scroll/UI/EffectControlPanel").render(entityArray, player, validCharmGestures)
	self.get_node("Scroll/UI/SummonControlPanel").render(entityArray, player)

func _on_end_turn_button_pressed():
	
	var orders = {}
	orders.id = player
	orders.gestures = gestureQueue[player]
	orders.spells = [null, null]
	orders.spells[0] = self.get_node("Scroll/UI/RightHand/RightHandSpellOptions").get_selected_id()
	orders.spells[1] = self.get_node("Scroll/UI/LeftHand/LeftHandSpellOptions").get_selected_id()
	orders.targets = [null, null]
	orders.targets[0] = self.get_node("Scroll/UI/RightHand/RightHandTargetingOptions").get_selected_id()
	orders.targets[1] = self.get_node("Scroll/UI/LeftHand/LeftHandTargetingOptions").get_selected_id()
	orders.effect_orders = []
	orders.monster_orders = []
	
	if true:
		spellQueue[player][0] = spellSearch(self.get_node("Scroll/UI/RightHand/RightHandSpellOptions").get_selected_id())
		spellQueue[player][1] = spellSearch(self.get_node("Scroll/UI/LeftHand/LeftHandSpellOptions").get_selected_id())
		
		targetQueue[player][0] = self.get_node("Scroll/UI/RightHand/RightHandTargetingOptions").get_selected_id()
		targetQueue[player][1] = self.get_node("Scroll/UI/LeftHand/LeftHandTargetingOptions").get_selected_id()
	
	var monsterList = self.get_node("Scroll/UI/SummonControlPanel").getMonsterList()
	
	for monster in monsterList:
		for child in monster[0].get_children():
			if child is OptionButton:
				var target_id = child.get_selected_id()
				entityArray[monster[1]].target_id = target_id
				orders.monster_orders.append([monster[1], target_id])
	
	var paraList = self.get_node("Scroll/UI/EffectControlPanel").getParaList()
	
	for eff in paraList:
		for child in eff[0].get_children():
			if child is OptionButton:
				for effect in entityArray[eff[2]].effects:
					if eff[1] == effect[0]:
						var hand = child.get_item_text(child.get_selected_id())
						effect[0].hand = hand
						var old_gesture
						if hand == "Right":
							old_gesture = entityArray[eff[2]].right_hand_gestures.back()
						elif hand == "Left":
							old_gesture = entityArray[eff[2]].left_hand_gestures.back()
						orders.effect_orders.append([eff[2], hand, "Paralyze"])
	
	var charmList = self.get_node("Scroll/UI/EffectControlPanel").getCharmList()
	var hand
	var new_gesture
	for eff in charmList:
		for child in eff[0].get_children():
			if child is OptionButton:
				for effect in entityArray[eff[2]].effects:
					var text = child.get_item_text(child.get_selected_id())
					if text.length() > 1:
						effect[0].hand = text
						hand = text
					else:
						effect[0].gesture = text
						new_gesture = text
						
					if hand and new_gesture:
						orders.effect_orders.append([eff[2], hand, new_gesture])
						new_gesture = null
						hand = null
	
	submitOrders(orders)
	
	#player += 1
	
	if player >= entityArray.size():
		#process_turn()
		pass
	else:
		
		if not entityArray[player].is_wizard:
			#process_turn()
			pass
		elif not entityArray[player].is_active():
			pass
			#_on_end_turn_button_pressed()
		else:
			renderWizardSection()

func submitOrders(orders):
	#print(orders)
	self.rpc("receiveOrders", orders)
	ordersDict[orders.id] = orders
	#print("There are now " + str(ordersDict.size()) + " sets of received orders")
	if ordersDict.size() == numPlayers:
		process_turn()
	
@rpc("any_peer", "reliable")
func receiveOrders(orders):
	#print("orders received")
	#print(orders)
	ordersDict[orders.id] = orders
	#print("There are now " + str(ordersDict.size()) + " sets of received orders")
	if ordersDict.size() == numPlayers:
		process_turn()

func _on_right_hand_gesture_options_item_selected(index):
	var gesture_ID = self.get_node("Scroll/UI/RightHand/RightHandGestureOptions").get_item_id(index)
	gestureQueue[player][0] = validGestures[gesture_ID]
	
	var maladroit = false
	for effect in entityArray[player].effects:
		if effect[0].maladroit:
			maladroit = true
	
	if maladroit:
		var leftHand = self.get_node("Scroll/UI/LeftHand/LeftHandGestureOptions")
		leftHand.select(index)
	
	onGestureChange(false)
	onGestureChange(true)

func _on_left_hand_gesture_options_item_selected(index):
	var gesture_ID = self.get_node("Scroll/UI/LeftHand/LeftHandGestureOptions").get_item_id(index)
	gestureQueue[player][1] = validGestures[gesture_ID]
	
	var maladroit = false
	for effect in entityArray[player].effects:
		if effect[0].maladroit:
			maladroit = true
	
	if maladroit:
		var rightHand = self.get_node("Scroll/UI/RightHand/RightHandGestureOptions")
		rightHand.select(index)
	
	onGestureChange(true)
	onGestureChange(false)

func _on_right_hand_spell_options_item_selected(index):
	onSpellChange(false)

func _on_left_hand_spell_options_item_selected(index):
	onSpellChange(true)
	
func _on_right_hand_targeting_options_item_selected(index):
	onTargetChange(false)

func _on_left_hand_targeting_options_item_selected(index):
	onTargetChange(true)

func _on_summon_control_panel_request_valid_targets(monster, button):
	var attack = spellSearch(stabID)
	var targets = findValidTargets(attack, entityArray[monster.summoner_id])
	
	button.clear()
	
	for target in targets[0]:
		button.add_item(target.name, target.id)
	button.select(button.get_item_index(targets[1]))
	if targets[1] == -1:
		button.set_disabled(true)
