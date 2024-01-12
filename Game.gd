extends Control

#TODO: FIX TARGETING BEING RESET TO DEFAULT WHEN YOU CHANGE THE TARGET(?) OF YOUR OTHER HAND
#TODO: MAGIC MIRROR DOESN'T WORK(TESTED WITH AMNESIA)
	#Can't reproduce for some reason? strange
#TODO: AFTER A DUEL, GIVE THE OPTION TO EXPORT THE ENTIRE GAME'S TURNLOG TO A TXT FILE
#TODO: MAKE SURE THAT IF YOU REMOVE ENCHANTMENT + HEAL A SUMMON, IT STILL DIES
	#Should be fixed by making remove enchantment set them to dead = 1 instead of dealing 99 damage
	#Dispel magic doesn't need this to happen because it prevents healing spells and monster attacks anyways
		#But could be nice for internal consistency I guess
#TODO: Fix desync involving maladroit and default targeting overriding later targets
	#It doesn't, somehow the local value of the buttons is overriding the submitted order version
	#I don't know how this happens, but a workaround is disabling any input after submitting a turn
		#This is probably prudent anyways, because re-submitting orders could lead to weirdness
		#if the turn starts processing just as a resubmission happens
#TODO: Fix bug involving 3 wizards, invisibility and paralysis on the bottom wizard's left hand
	#The paralyzed wizard is different then the invisibility one
#TODO: Fix bug where you can set default target to dead creatures
	#Should be fixed
#TODO: Fix bug where double paralysis doesn't cancel each other out
	#Tricky problem, because the following needs to happen:
		#Two paralyzes applied on the same turn should cancel
		#Two paralyzes applied on different turns shouldn't
		#Should be fixed
		#Also, see if other hexes need to gain the overlapping tag as well
			#They did, but this should be fixed now
#TODO: Fix bug where two healing spells don't stack
	#Should be fixed by setting the heal effect to allow overlapping

var spellArray = Array()
var entityArray = Array()

var effectDict = Dictionary()

var gestureQueue = Array()
var spellQueue = Array()
var targetQueue = Array()

var namesDict = Dictionary()
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
	
	loadSpells("res://resources/spells", spellArray)
	
	spellArray.sort_custom(spellPowerSort)
	
	for i in spellArray.size():
		spellArray[i].id = i
		if spellArray[i].name == "Stab":
			stabID = i
	spellArray.sort_custom(spellSort)
	
	var spellInfoTab = self.get_node("Scroll/UI/MainColumn/SpellInfoTab")
	self.get_node("Scroll/UI/SpellList").init(spellArray)
	self.get_node("Scroll/UI/MainColumn/SpellInfoTab").init(spellArray)
	
	loadEffects("res://resources/effects", effectDict)
	
	# TODO: Sort the wizardarray?
	
	var emptySpace = {}
	emptySpace.id = 0
	emptySpace.name = "Empty Space"
	emptySpace.is_wizard = false
	emptySpace.is_monster = false
	
	var wizTemplate = load("res://resources/wizards/wizard_template.tres")
	entityArray.append(emptySpace)
		
	for i in peers.size():
		var new_wizard = wizTemplate.duplicate()
		new_wizard.name = GlobalDataSingle.namesDict[peers[i]]
		entityArray.append(new_wizard)
	
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
			
			#TODO: remove these messages if there's invisibility involved
			
			if clap == 2:
				gestureQueue[i][0] = "C"
				gestureQueue[i][1] = "C"
				addMessage(entityArray[i].name + " claps " + entityArray[i].pronouns[2] + " hands.",turnLogQueue, entityArray[i])
			else:
				for gesture in gestureQueue[i]:
					var text = gesture_to_text(gesture, entityArray[i])
					if text != "":
						addMessage(text, turnLogQueue, entityArray[i])
		
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
				addMessage("The conflicting hexes on " + entityArray[i].name + " cancel each other out!", turnLogQueue, entityArray[i])
	
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
			addMessage(entityArray[i].name + " remains unscathed between conflicting heat and cold!", turnLogQueue, entityArray[i])
		else:
			for b in burn:
				entityArray[i].take_damage(b)
				addMessage(entityArray[i].name + " is burned for " + str(b) + " damage.", turnLogQueue, entityArray[i])
			for f in freeze:
				entityArray[i].take_damage(f)
				addMessage(entityArray[i].name + " is chilled for " + str(f) + " damage.", turnLogQueue, entityArray[i])
			for h in heals:
				entityArray[i].take_damage(-1*h)
				addMessage(entityArray[i].name + " healed for " + str(h) + " hp.", turnLogQueue, entityArray[i])
	
	var activePlayer = 0
	numPlayers = 0
		
	for i in range(1, entityArray.size()):
		
		if entityArray[i].is_wizard and entityArray[i].is_active():
			
			var spellsDisrupted = false
			var invisible = false
			for effect in entityArray[i].effects:
				if effect[0].anti_spell:
					spellsDisrupted = true
			
			var unseen = not canSee(entityArray[player], entityArray[i])
			
			if not spellsDisrupted:
				entityArray[i].right_hand_gestures.append(gestureQueue[i][0])
				entityArray[i].right_hidden.append(unseen)
				entityArray[i].left_hand_gestures.append(gestureQueue[i][1])
				entityArray[i].left_hidden.append(unseen)
			else:
				turnLogQueue.append(entityArray[i].name + "'s magic is disrupted!")
				entityArray[i].right_hand_gestures.append("N")
				entityArray[i].left_hand_gestures.append("N")
				entityArray[i].right_hidden.append(false)
				entityArray[i].right_hidden.append(false)
		
		if entityArray[i].dead == 1:
			turnLogQueue.append(entityArray[i].name + " perishes!")
			entityArray[i].dead = 2
		elif entityArray[i].dead == 0 and entityArray[i].is_wizard:
			for effect in entityArray[i].effects:
				if effect[0].surrender:
					entityArray[i].surrendered = true
					turnLogQueue.append(entityArray[i].name + " surrenders!")
					
		if entityArray[i].is_wizard or entityArray[i].is_monster:
			var removeEffectList = []
			for effect in entityArray[i].effects:
				effect[0].delayed = false
				if not effect[0].permanent:
					effect[1] -= 1
					if effect[1] <= 0 or not entityArray[i].is_active():
						if effect[0].fatal and entityArray[i].is_active():
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
		self.get_node("Scroll/UI/MainColumn/EndTurnButton").hide()
		self.get_node("Scroll/UI/MainColumn/RightHand").hide()
		self.get_node("Scroll/UI/MainColumn/LeftHand").hide()
	elif numPlayers == 0:
		turnLogQueue.append("All wizards have been eliminated. The duel ends in a draw.")
		self.get_node("Scroll/UI/MainColumn/EndTurnButton").hide()
		self.get_node("Scroll/UI/MainColumn/RightHand").hide()
		self.get_node("Scroll/UI/MainColumn/LeftHand").hide()
	else:
		turn += 1
		#player = 1
		
		while not entityArray[player].is_active():
			#player += 1
			pass
	
	self.get_node("Scroll/UI/MainColumn/TurnReport").render(turnLogQueue)
	
	self.renderWizardSection()
	
	#self.get_node("Scroll/UI/MainColumn/EndTurnButton").set_disabled(false)
	setAllButtonsTo(false)

func setAllButtonsTo(value: bool):
	get_tree().set_group("buttons", "disabled", value)
	
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
						#eff[0].stackable = true
						#eff[0].overlapping = false
			elif effect[1] == "Right" or effect[1] == "Left":
				for eff in entityArray[effect[0]].effects:
					if eff[0].charm_person and eff[0].caster_id == order.id:
						eff[0].hand = effect[1]
						eff[0].gesture = effect[2]
			else:
				printerr("Invalid command")
			#TODO: Check the validity of these orders too

func paralyze_gesture(gesture: String):
	match gesture:
		"S":
			return "D"
		"C":
			return "F"
		"W":
			return "P"
		_:
			return gesture

func gesture_to_text(gesture: String, wizard: Wizard):
	
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

func castSpells(spellExecutionList: Array, entityArray: Array, turnLogQueue: Array):
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
					addMessage(target.pronouns[2].capitalize() + " spell reflects back at " + target.pronouns[1] + "!", turnLogQueue, target)
					targets.append(caster)
				else:
					targets.append(target)
		else:
			spellFailed = true
			#TODO: Custom text for missing vs failing to cast
		
		if magicDispelled and spell.dispellable:
			spellFailed = true
			
		if spell.targetable and targets.size() > 0 and not canSee(caster, targets[0]):
			spellFailed = true
			
		var fire_elemental
		var ice_elemental
			
		if spell.once_per_duel and not spellFailed:
			for s in oncePerDuelSpells.size():
				if oncePerDuelSpells[s][0] == caster.id and oncePerDuelSpells[s][1] == spell.id:
					spellFailed = true
			
			if not spellFailed:
				oncePerDuelSpells.append([caster.id, spell.id])
		#TODO: add more spell failure conditions
					
		for e in entityArray:
			if e.is_monster and e.aoe:
				if e.fire:
					fire_elemental = e
				elif e.ice:
					ice_elemental = e
					
		if spell.once_per_turn and not spellFailed:
			for spell_id in oncePerTurnSpells:
				if spell_id == spell.id:
					spellFailed = true
			if not spellFailed:
				oncePerTurnSpells.append(spell.id)
				if spell.fire_spell and fire_elemental:
					fire_elemental.dead = 2
					turnLogQueue.append("The " + fire_elemental.name + " loses it's form in the sudden torrent of it's own element!")
				if spell.ice_spell and ice_elemental:
					ice_elemental.dead = 2
					turnLogQueue.append("The " + ice_elemental.name + " loses it's form in the sudden torrent of it's own element!")

		if not spellFailed and spell.fire_spell and targets.has(ice_elemental):
			turnLogQueue.append("The " + ice_elemental.name + " melts!")
			ice_elemental.dead = 2
			spellFailed = true
			
		if not spellFailed and spell.ice_spell and targets.has(fire_elemental):
			turnLogQueue.append("The " + fire_elemental.name + " is doused!")
			fire_elemental.dead = 2
			spellFailed = true
		#TODO: THIS DEFINITELY NEEDS A CUSTOM FAILURE MESSAGE
			
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
				addMessage(message, turnLogQueue, caster)
			
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
							addMessage(spellCheck, turnLogQueue, t)
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
								var adjective = " "
								var purpose = " to serve "
								if not (spell.fire_spell or spell.ice_spell):
									monster.summoner_id = summoner
									adjective = adjective + monster.adjectives[adjectiveCount]
									monster.name = entityArray[summoner].name + "'s " + monster.adjectives[adjectiveCount] + " " + spell.effect_name
									purpose += entityArray[summoner].name
								else:
									if spell.ice_spell:
										adjective = "n"
									else:
										adjective = ""
									purpose = ""
									monster.summoner_id = -1
									monster.name = spell.effect_name
									monster.aoe = true
									monster.fire = spell.fire_spell
									monster.ice = spell.ice_spell
								monster.max_hp = spell.intensity
								monster.hp = spell.intensity
								
								monster.id = entityArray.size()
								entityArray.append(monster)
								
								addMessage("A" + adjective + " " + spell.effect_name + " appears" + purpose + "!", turnLogQueue, entityArray[summoner])
								adjectiveCount += 1
							else:
								addMessage("The summoning fails!", turnLogQueue, caster)
				Spell.SpellEffect.applyTempEffect:
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							var effect = effectDict[spell.effect_name]
							effect.caster_id = caster.id
							if effect.unstable and t.is_monster:
								turnLogQueue.append(t.name + " is overloaded with magic and explodes!")
								t.dead = 2
							else:
								t.addEffect(effect, spell.intensity)
						else:
							addMessage(spellCheck, turnLogQueue, t)
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
								t.dead = 1
						else:
							addMessage(spellCheck, turnLogQueue, t)
				Spell.SpellEffect.dealDamage:
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							t.take_damage(spell.intensity)
							addMessage(t.name + " is " + spell.effect_name + " for " + str(spell.intensity) + " damage.", turnLogQueue, t)
						else:
							addMessage(spellCheck, turnLogQueue, t)
				Spell.SpellEffect.Heal:
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
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
							addMessage(spellCheck, turnLogQueue, t)
				Spell.SpellEffect.Kill:
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							addMessage(t.name + " is " + spell.effect_name + "!", turnLogQueue, t)
							t.take_damage(99)
							t.dead = 2
						else:
							addMessage(spellCheck, turnLogQueue, t)
				_:
					printerr("Spell effect not recognized")
		else:
			addMessage(caster.name + "'s spell fizzles!", turnLogQueue, caster)

func addMessage(message: String, turnLogQueue : Array, subject): #TODO: Needs static typing
	if canSee(entityArray[player], subject):
		turnLogQueue.append(message)

func monsterActions(entityArray: Array, turnLogQueue: Array):
	
	var fire_elementals = []
	var ice_elementals = []
	
	for i in range(1, entityArray.size()):
		var entity = entityArray[i]

		if entity.is_monster and entity.aoe and entity.is_active():
			if entity.fire:
				fire_elementals.append(entity)
			if entity.ice:
				ice_elementals.append(entity)
	
	if fire_elementals.size() > 0 and ice_elementals.size() > 0:
		for fire_ele in fire_elementals:
			fire_ele.dead = 2
		for ice_ele in ice_elementals:
			ice_ele.dead = 2
		turnLogQueue.append("The opposing elementals violently annihilate one another!")
	elif fire_elementals.size() > 1:
		var highest_hp = 1
		for f in range(fire_elementals.size()):
			highest_hp = max(fire_elementals[f].hp, highest_hp)
			if f > 0:
				fire_elementals[f].dead = 2
			else:
				fire_elementals[0].hp = max(highest_hp, fire_elementals[0].max_hp)
		turnLogQueue.append("The similar elementals merge into one!")
	elif ice_elementals.size() > 1:
		var highest_hp = 1
		for c in range(ice_elementals.size()):
			highest_hp = max(ice_elementals[c].hp, highest_hp)
			if c > 0:
				ice_elementals[c].dead = 2
			else:
				ice_elementals[0].hp = max(highest_hp, ice_elementals[0].max_hp)
		turnLogQueue.append("The similar elementals merge into one!")
		
	for i in range(1, entityArray.size()):
		var entity = entityArray[i]
		if entity.is_monster and entity.is_active():
			if entity.target_id > 0 or entity.aoe:
				var targets = []
				if not entity.aoe:
					targets = [entityArray[entity.target_id]]
				else:
					for enemy in entityArray:
						if (enemy.is_monster or enemy.is_wizard) and enemy.id != entity.id and enemy.is_active():
							targets.append(enemy)
				for target in targets: 
					var target_name = target.name
					if entity.id == target.id:
						target_name = entity.pronouns[3]
					var shield = false
					var fire_res = false
					var cold_res = false
					for effect in target.effects:
						if effect[0].shield:
							shield = true
						if effect[0].fire_res:
							fire_res = true
						if effect[0].cold_res:
							cold_res = true
		
					var hexed = false
					var charmed = false
					for effect in entity.effects:
						if effect[0].hex:
							hexed = true
							effect[1] = 0
							if effect[0].charm_monster and entity.summoner_id != -1:
								entity.summoner_id = effect[0].caster_id
								var old_name = entity.name.split(" ")
								entity.name = entityArray[entity.summoner_id].name + "'s " + old_name[old_name.size()-2] + " " + old_name[old_name.size()-1]
					if hexed:
						addMessage(entity.name + " tries to attack " + target_name + ", but " + entity.pronouns[2] + " hex prevents " + entity.pronouns[1], turnLogQueue, target)
					elif shield:
						addMessage(entity.name + " attacks " + target_name + ", but " + target.pronouns[2] + " shield protects " + target.pronouns[1] + "!", turnLogQueue, target)
					elif not entity.aoe and not canSee(entity, target):
						addMessage(entity.name + " attacks " + target_name + ", but misses!", turnLogQueue, target)
					elif entity.fire and fire_res or entity.ice and cold_res:
						addMessage(entity.name + " attacks " + target_name + ", but " + target.pronouns[0] + " resist!", turnLogQueue, target)
					else:
						addMessage(entity.name + " attacks " + target_name + " for "+ str(entity.max_hp) + " damage.", turnLogQueue, target)
						target.take_damage(entity.max_hp)

func checkSpellInterference(spell: Spell, target): #TODO: Needs static typing
	
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
		if target.is_monster and target.fire:
			return target.name + " resists the fire!"
			
	if spell.ice_spell:
		for effect in target.effects:
			if effect[0].cold_res and spell.hostile:
				return target.name +  " resists the cold!"
		if target.is_monster and target.ice:
			return target.name + " resists the cold!"
		
	return ""

func canSee(viewer, subject): #TODO: Needs static typing
	
	if viewer.id == subject.id:
		return true
	
	for effect in viewer.effects:
		if effect[0].blindness and not effect[0].delayed:
			return false
			
	for effect in subject.effects:
		if effect[0].invisibility and not effect[0].delayed:
			return false
			
	return true

func loadSpells(path: String, array: Array): 
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				loadSpells(path + "/" + file_name, spellArray)
			else:
				spellArray.append(load(path + "/" + file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		printerr("An error occurred when trying to access the path.")

func loadEffects(path: String, dict: Dictionary):
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

func spellSort(spellA: Spell, spellB: Spell):
	if spellA.id < spellB.id:
		return true
	else:
		return false

func spellOrderSort(spellA, spellB): #TODO: Needs static typing
	if spellA[0].effect < spellB[0].effect:
		return true
	elif spellA[0].effect == spellB[0].effect and spellA[0].effect_name == "Reflect":
		return true
	elif spellA[0].effect == spellB[0].effect and spellA[0].intensity > spellB[0].intensity:
		return true
	else:
		return false
		
func spellPowerSort(spellA: Spell, spellB: Spell):
	if spellA.gestures.size() < spellB.gestures.size():
		return true
	elif spellA.gestures.size() == spellB.gestures.size():
		if spellA.gestures[spellA.gestures.size()-1].length() < spellB.gestures[spellB.gestures.size()-1].length():
			return true
		else:
			return false
	else:
		return false

func spellCompare(spell: Spell, targetID: int):
	return spell.id < targetID

func spellSearch(targetID: int):
	var spell = spellArray[spellArray.bsearch_custom(targetID, spellCompare)]
	if spell.id == targetID:
		return spell
	else:
		return null

func analyzeGestures(wizard_index: int, isLeft: bool):
	
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

func onGestureChange(isLeft: bool):
	var spellOptionsArray = analyzeGestures(player, isLeft)
	var spellOptions
	if isLeft:
		spellOptions = self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandSpellOptions")
	else:
		spellOptions = self.get_node("Scroll/UI/MainColumn/RightHand/RightHandSpellOptions")
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

func onSpellChange(isLeft: bool):
	
	var mainHand
	var offHand
	
	if isLeft:
		mainHand = self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandSpellOptions")
		offHand = self.get_node("Scroll/UI/MainColumn/RightHand/RightHandSpellOptions")
	else:
		mainHand = self.get_node("Scroll/UI/MainColumn/RightHand/RightHandSpellOptions")
		offHand = self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandSpellOptions")
	
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

func onTargetChange(isLeft: bool):
	var rightSpell = spellSearch(self.get_node("Scroll/UI/MainColumn/RightHand/RightHandSpellOptions").get_selected_id())
	
	var rightTarget = self.get_node("Scroll/UI/MainColumn/RightHand/RightHandTargetingOptions")
	var leftTarget = self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandTargetingOptions")
	
	if rightSpell != null and rightSpell.is_two_handed():
		if isLeft:
			rightTarget.select(rightTarget.get_item_index(leftTarget.get_selected_id()))
		else:
			leftTarget.select(leftTarget.get_item_index(rightTarget.get_selected_id()))

func recalculateTarget(isLeft: bool):
	
	var mainHand
	var mainTarget
	var mainSpell
	
	var offHand
	var offTarget
	var offSpell
	
	if isLeft:
		mainHand = self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandSpellOptions")
		mainTarget = self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandTargetingOptions")
		
		offHand = self.get_node("Scroll/UI/MainColumn/RightHand/RightHandSpellOptions")
		offTarget = self.get_node("Scroll/UI/MainColumn/RightHand/RightHandTargetingOptions")
	else:
		mainHand = self.get_node("Scroll/UI/MainColumn/RightHand/RightHandSpellOptions")
		mainTarget = self.get_node("Scroll/UI/MainColumn/RightHand/RightHandTargetingOptions")
		
		offHand = self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandSpellOptions")
		offTarget = self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandTargetingOptions")
		
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

func findValidTargets(spell: Spell, caster: Wizard):
	
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
	
	var defaultHostileTargetId = self.get_node("Scroll/UI/MainColumn/DefaultHostileTargetPanel/DefaultHostileTargetOptions").get_selected_id()
	var defaultHostileTargetIndex = -1
	
	for i in range(preferredTargets.size()):
		if preferredTargets[i].id == defaultHostileTargetId:
			defaultHostileTargetIndex = i
	
	if defaultHostileTargetIndex != -1:
		var temp = preferredTargets[0]
		preferredTargets[0] = preferredTargets[defaultHostileTargetIndex]
		preferredTargets[defaultHostileTargetIndex] = temp
	#randomize()
	#preferredTargets.shuffle()
	
	return [validTargets, preferredTargets[0].id]

func isTargetHostile(target, caster: Wizard): #TODO: Needs static typing
	
	if target.is_wizard and target.id != caster.id:
		return true
	elif target.is_monster and target.summoner_id != caster.id:
		return true
	else:
		return false

func renderWizardSection():
	self.get_node("Scroll/UI/MainColumn/WizardList").render(entityArray, player)
	
	self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandSpellOptions").clear()
	self.get_node("Scroll/UI/MainColumn/RightHand/RightHandSpellOptions").clear()
	self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandSpellOptions").set_disabled(true)
	self.get_node("Scroll/UI/MainColumn/RightHand/RightHandSpellOptions").set_disabled(true)
	
	self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandTargetingOptions").clear()
	self.get_node("Scroll/UI/MainColumn/RightHand/RightHandTargetingOptions").clear()
	self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandTargetingOptions").set_disabled(true)
	self.get_node("Scroll/UI/MainColumn/RightHand/RightHandTargetingOptions").set_disabled(true)
	
	self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandGestureOptions").clear()
	self.get_node("Scroll/UI/MainColumn/RightHand/RightHandGestureOptions").clear()
	
	var defaultTargetOptions = self.get_node("Scroll/UI/MainColumn/DefaultHostileTargetPanel/DefaultHostileTargetOptions")
	var oldTargetId = defaultTargetOptions.get_selected_id()
	defaultTargetOptions.clear()
	for i in range(1, entityArray.size()):
		if entityArray[i].is_active() and isTargetHostile(entityArray[i], entityArray[player]):
			defaultTargetOptions.add_item(entityArray[i].name, i)
	
	var oldTargetIndex = defaultTargetOptions.get_item_index(oldTargetId)
	if oldTargetIndex != -1:
		defaultTargetOptions.select(oldTargetIndex)
	else:
		defaultTargetOptions.select(defaultTargetOptions.get_selectable_item())
	
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
					self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandGestureOptions").add_item(gesture, i)
					self.get_node("Scroll/UI/MainColumn/RightHand/RightHandGestureOptions").add_item(gesture, i)
		else:
			for i in validGestures.size():
				var gesture = validGestures[i]
				if gesture == entityArray[player].right_hand_gestures.back():
					self.get_node("Scroll/UI/MainColumn/RightHand/RightHandGestureOptions").add_item(gesture, i)
					self.get_node("Scroll/UI/MainColumn/RightHand/RightHandGestureOptions").select(0)
					gestureQueue[player][0] = gesture
				if gesture == entityArray[player].left_hand_gestures.back():
					self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandGestureOptions").add_item(gesture, i)
					self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandGestureOptions").select(0)
					gestureQueue[player][1] = gesture
			onGestureChange(false)
			onGestureChange(true)
				
	self.get_node("Scroll/UI/MainColumn/EffectControlPanel").render(entityArray, player, validCharmGestures)
	self.get_node("Scroll/UI/MainColumn/SummonControlPanel").render(entityArray, player)

func _on_end_turn_button_pressed():
	
	setAllButtonsTo(true)
	
	var orders = {}
	orders.id = player
	orders.gestures = gestureQueue[player]
	orders.spells = [null, null]
	orders.spells[0] = self.get_node("Scroll/UI/MainColumn/RightHand/RightHandSpellOptions").get_selected_id()
	orders.spells[1] = self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandSpellOptions").get_selected_id()
	orders.targets = [null, null]
	orders.targets[0] = self.get_node("Scroll/UI/MainColumn/RightHand/RightHandTargetingOptions").get_selected_id()
	orders.targets[1] = self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandTargetingOptions").get_selected_id()
	orders.effect_orders = []
	orders.monster_orders = []
	
	if true:
		spellQueue[player][0] = spellSearch(self.get_node("Scroll/UI/MainColumn/RightHand/RightHandSpellOptions").get_selected_id())
		spellQueue[player][1] = spellSearch(self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandSpellOptions").get_selected_id())
		
		targetQueue[player][0] = self.get_node("Scroll/UI/MainColumn/RightHand/RightHandTargetingOptions").get_selected_id()
		targetQueue[player][1] = self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandTargetingOptions").get_selected_id()
	
	var monsterList = self.get_node("Scroll/UI/MainColumn/SummonControlPanel").getMonsterList()
	
	for monster in monsterList:
		for child in monster[0].get_children():
			if child is OptionButton:
				var target_id = child.get_selected_id()
				#entityArray[monster[1]].target_id = target_id 
				orders.monster_orders.append([monster[1], target_id])
	
	var paraList = self.get_node("Scroll/UI/MainColumn/EffectControlPanel").getParaList()
	
	for eff in paraList:
		for child in eff[0].get_children():
			if child is OptionButton:
				for effect in entityArray[eff[2]].effects:
					if eff[1] == effect[0]:
						var hand = child.get_item_text(child.get_selected_id())
						#effect[0].hand = hand 
						var old_gesture
						orders.effect_orders.append([eff[2], hand, "Paralyze"])
	
	var charmList = self.get_node("Scroll/UI/MainColumn/EffectControlPanel").getCharmList()
	var hand
	var new_gesture
	for eff in charmList:
		for child in eff[0].get_children():
			if child is OptionButton:
				for effect in entityArray[eff[2]].effects:
					var text = child.get_item_text(child.get_selected_id())
					if text.length() > 1:
						#effect[0].hand = text
						hand = text 
					else:
						#effect[0].gesture = text
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
			pass
			#renderWizardSection()

func submitOrders(orders: Dictionary):
	self.rpc("receiveOrders", orders)
	ordersDict[orders.id] = orders

	if ordersDict.size() == numPlayers:
		process_turn()
	
@rpc("any_peer", "reliable")
func receiveOrders(orders: Dictionary):
	ordersDict[orders.id] = orders
	if ordersDict.size() == numPlayers:
		process_turn()

func _on_right_hand_gesture_options_item_selected(index: int):
	var gesture_ID = self.get_node("Scroll/UI/MainColumn/RightHand/RightHandGestureOptions").get_item_id(index)
	gestureQueue[player][0] = validGestures[gesture_ID]
	
	var maladroit = false
	for effect in entityArray[player].effects:
		if effect[0].maladroit:
			maladroit = true
	
	if maladroit:
		var leftHand = self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandGestureOptions")
		leftHand.select(index)
		gestureQueue[player][1] = validGestures[gesture_ID]
	
	onGestureChange(false)
	onGestureChange(true)

func _on_left_hand_gesture_options_item_selected(index: int):
	var gesture_ID = self.get_node("Scroll/UI/MainColumn/LeftHand/LeftHandGestureOptions").get_item_id(index)
	gestureQueue[player][1] = validGestures[gesture_ID]
	
	var maladroit = false
	for effect in entityArray[player].effects:
		if effect[0].maladroit:
			maladroit = true
	
	if maladroit:
		var rightHand = self.get_node("Scroll/UI/MainColumn/RightHand/RightHandGestureOptions")
		rightHand.select(index)
		gestureQueue[player][0] = validGestures[gesture_ID]
	
	onGestureChange(true)
	onGestureChange(false)

func _on_right_hand_spell_options_item_selected(index: int):
	onSpellChange(false)

func _on_left_hand_spell_options_item_selected(index: int):
	onSpellChange(true)
	
func _on_right_hand_targeting_options_item_selected(index: int):
	onTargetChange(false)

func _on_left_hand_targeting_options_item_selected(index: int):
	onTargetChange(true)

func _on_summon_control_panel_request_valid_targets(monster, button): #TODO: Needs static typing
	var attack = spellSearch(stabID)
	var targets = findValidTargets(attack, entityArray[monster.summoner_id])
	
	button.clear()
	
	for target in targets[0]:
		button.add_item(target.name, target.id)
	button.select(button.get_item_index(targets[1]))
	if targets[1] == -1:
		button.set_disabled(true)
