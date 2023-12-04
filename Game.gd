extends CanvasLayer

#TODO: FIX TARGETING BEING RESET TO DEFAULT WHEN YOU CHANGE THE TARGET(?) OF YOUR OTHER HAND
#TODO: MAKE IT SO THAT BEING TARGETED BY A FIREBALL PROTECTS FROM ICE STORM AND VICE VERSA

var spellArray = Array()
var entityArray = Array()

var effectDict = Dictionary()

var gestureQueue = Array()
var spellQueue = Array()
var targetQueue = Array()

var player
var numPlayers
var turn = 0

var validGestures = ["N", "P", "W", "S", "D", "F", "C", ">"]
var validSpookedGestures = ["N", "P", "W", ">"]

# Called when the node enters the scene tree for the first time.
func _ready():
	loadSpells("res://resources/spells", spellArray)
	
	spellArray.sort_custom(spellPowerSort)
	
	for i in spellArray.size():
		spellArray[i].id = i
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
	
	for i in range(1, entityArray.size()):
		entityArray[i].id = i
		
	numPlayers = entityArray.size() - 1
	
	for i in validGestures.size(): #TODO: make this also add the ID, to support fear, charm, etc
		var gesture = validGestures[i]
		self.get_node("Scroll/UI/LeftHand/LeftHandGestureOptions").add_item(gesture, i)
		self.get_node("Scroll/UI/RightHand/RightHandGestureOptions").add_item(gesture, i)
	
	for i in range(0, entityArray.size()):
		gestureQueue.append(["N", "N"])
		spellQueue.append([null, null])
		targetQueue.append([-1, -1])

	process_turn()

func process_turn():
	
	var turnLogQueue = []
	
	turnLogQueue.append("It is turn " + str(turn+1))
	
	for i in range(1, entityArray.size()):
		
		#TODO: resolve gesture changes from charm/paralysis here
		
		#TODO: analyze gestures to determine which spells they can cast this turn
		
		#TODO: if the spell in their spell queue is a spell they can cast, select that spell
		
		#TODO: otherwise, select another valid spell for their current gestures
		#TODO: if a spell would be mandatory, then automatically select that
		#TODO: otherwise, select the most complex spell of the possibilities
		
		#TODO: if the final spell to be cast was the same as their original spell, cast it on their original target
		#TODO: otherwise, pick the preferred target for the type of spell in question:
			#No target if it can't be targeted, obviously
			#On a random enemy wizard, if it was a hostile spell
			#On yourself, if it was a non-hostile spell
			
		# since this is all stuff that is only relevant if gestures can be changed before spells go off
		# for now we just skip all this stuff, and use the spellqueue and the targetqueue as they are
		
		if entityArray[i].is_wizard and entityArray[i].is_active():
		
			var clap = 0
			
			if gestureQueue[i][0] == "C":
				clap +=1
				gestureQueue[i][0] = "N"
				
			if gestureQueue[i][1] == "C":
				clap += 1
				gestureQueue[i][1] = "N"
				
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
				
	#sort spells by the order their effects resolves:
	#1: dispel magic goes off
	#1.5: counterspells goes off
	#2: summons go off
	#3: temp effect applications go off
	#4: damage spells go off
	#5: healing spells go off
	#6: kill spells go off
	#7: surrenders go off
	
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
			
		#TODO: add more spell failure conditions here?
		
		if not spellFailed: 
			
			var verb = " casts "
			var target_string = ""
			var spell_name = spell.name
			if targets.size() == 1:
				target_string =  targets[0].name
				
			if not spell.is_spell:
				verb = " "
				target_string = "s " + target_string
				spell_name = spell_name.to_lower()
			else:
				target_string = " on " + target_string
					
			var message = caster.name + verb + spell_name + target_string
			turnLogQueue.append(message)
			
			match spellExecutionList[i][0].effect:	
				Spell.SpellEffect.dispelMagic:
					magicDispelled = true
					for t in targets:
						if t.is_wizard:
							for e in t.effects.size():
								if t.effects[e].dispellable:
									t.effects.remove_at(e)
							t.addEffect("Shield", 0, effectDict)
						elif t.is_monster:
							t.take_damage(99)
					print("dispel magic")
				Spell.SpellEffect.Counter:
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							t.addEffect("Counterspell", 0, effectDict)
						else:
							turnLogQueue.append(spellCheck)
				Spell.SpellEffect.Summon:
					print("summon monster")
				Spell.SpellEffect.applyTempEffect:
					print("apply effect")
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							t.addEffect(spell.effect_name, spell.intensity, effectDict)
						else:
							turnLogQueue.append(spellCheck)
				Spell.SpellEffect.dealDamage:
					print("deal damage")
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							t.take_damage(spell.intensity)
							turnLogQueue.append(t.name + " is " + spell.effect_name + " for " + str(spell.intensity) + " damage.")
						else:
							turnLogQueue.append(spellCheck)
				Spell.SpellEffect.Heal:
					print("heal")
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							turnLogQueue.append(t.name + " is healed for " + str(spell.intensity) + " damage.")
							t.take_damage(spell.intensity * -1)
						else:
							turnLogQueue.append(spellCheck)
				Spell.SpellEffect.Kill:
					print("kill")
					for t in targets:
						var spellCheck = checkSpellInterference(spell, t)
						if spellCheck == "":
							turnLogQueue.append(t.name + " is " + spell.effect_name + "!")
							t.take_damage(99)
						else:
							turnLogQueue.append(spellCheck)
				Spell.SpellEffect.Surrender:
						if caster.is_alive():
							caster.surrendered = true
							#turnLogQueue.append(caster.name + " surrenders!")
				_:
					printerr("Spell effect not recognized")
		else:
			turnLogQueue.append(caster.name + "'s spell fizzles!")
	
	var activePlayer = 0
	numPlayers = 0
		
	for i in range(1, entityArray.size()):
		
		if entityArray[i].is_wizard or entityArray[i].is_monster:
			if entityArray[i].is_active():
				for effect in entityArray[i].effects:
					effect[1] -= 1
					if effect[1] <= 0:
						entityArray[i].removeEffect(effect[0].name)
		
		#TODO: resolve anti spells in this step
		
		if entityArray[i].is_wizard and entityArray[i].is_active():
			entityArray[i].right_hand_gestures.append(gestureQueue[i][0])
			entityArray[i].left_hand_gestures.append(gestureQueue[i][1])
			numPlayers += 1
			activePlayer = i
			
		gestureQueue[i] = ["N", "N"]
		spellQueue[i] = [null, null]
		targetQueue[i] = [-1, -1]
		
		
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
		player = 1
		
		while not entityArray[player].is_active():
			player += 1
	
	self.get_node("Scroll/UI/TurnReport").render(turnLogQueue)
	
	self.renderWizardSection()

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
			if effect[0].fire_res:
				return target.name +  " resists the fire!"
		
	if spell.ice_spell:
		for effect in target.effects:
			if effect[0].cold_res:
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
		print("An error occurred when trying to access the path.")

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
				spellOptionsArray.append(spell)
		elif spell.is_two_handed() and off_gestures.ends_with(main_spell_gestures) and main_gestures.ends_with(off_spell_gestures):
			spellOptionsArray.append(spell)
	
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
		
	# TODO: sort the spell options by how long the gesture string takes
	
	# TODO: Make it so that clapping with one hand automatically claps with both
	# TODO: And also that unclapping with one hand turns the other hand into the NULL gesture
	# ^ Maybe don't actually do the above things
	
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
	# TODO: if casting a two-handed spell, changing the target with one hand also changes target of the other
	var rightSpell = spellSearch(self.get_node("Scroll/UI/RightHand/RightHandSpellOptions").get_selected_id())
	
	var rightTarget = self.get_node("Scroll/UI/RightHand/RightHandTargetingOptions")
	var leftTarget = self.get_node("Scroll/UI/LeftHand/LeftHandTargetingOptions")
	
	if rightSpell.is_two_handed():
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
		var validTargets = findValidTargets(mainSpell)
		for target in validTargets[0]:
			mainTarget.add_item(target.name, target.id)
		
		mainTarget.select(mainTarget.get_item_index(validTargets[1]))
		if validTargets[1] == -1:
			mainTarget.set_disabled(true)

func findValidTargets(spell):
	
	var startIndex = 0
	var validTargets = []
	var preferredTargets = []
	var defaultTarget = 0
	var caster = entityArray[player]
	
	if not spell.targetable:
		return [[],-1]
	
	if not spell.requires_target:
		validTargets.append(entityArray[0])
		
	for i in range(1, entityArray.size()):
		if (entityArray[i].is_wizard and entityArray[i].is_active()) or (entityArray[i].is_monster and entityArray[i].is_alive()):
			validTargets.append(entityArray[i])
			#print("Caster ID: " + str(caster.id))
			#print("Target ID: " + str(entityArray[i].id))
			if entityArray[i].id == caster.id and not spell.hostile:
				#print("awoo")
				#print(entityArray[i].name)
				preferredTargets.append(entityArray[i])
			elif spell.hostile and isTargetHostile(entityArray[i], caster):
				preferredTargets.append(entityArray[i])
	
	randomize()
	preferredTargets.shuffle()
	
	return [validTargets, preferredTargets[0].id]

func isTargetHostile(target, caster):
	
	if target.is_wizard and target.id != caster.id:
		return true
	elif target.is_monster and target.master_id != caster.id:
		return true
	else:
		return false

func renderWizardSection():
	self.get_node("Scroll/UI/WizardList").render(entityArray, player)
	self.get_node("Scroll/UI/LeftHand/LeftHandGestureOptions").select(0)
	self.get_node("Scroll/UI/RightHand/RightHandGestureOptions").select(0)
	self.get_node("Scroll/UI/LeftHand/LeftHandSpellOptions").clear()
	self.get_node("Scroll/UI/RightHand/RightHandSpellOptions").clear()
	self.get_node("Scroll/UI/LeftHand/LeftHandSpellOptions").set_disabled(true)
	self.get_node("Scroll/UI/RightHand/RightHandSpellOptions").set_disabled(true)
	self.get_node("Scroll/UI/LeftHand/LeftHandTargetingOptions").clear()
	self.get_node("Scroll/UI/RightHand/RightHandTargetingOptions").clear()
	self.get_node("Scroll/UI/LeftHand/LeftHandTargetingOptions").set_disabled(true)
	self.get_node("Scroll/UI/RightHand/RightHandTargetingOptions").set_disabled(true)

func _on_end_turn_button_pressed():
	
	spellQueue[player][0] = spellSearch(self.get_node("Scroll/UI/RightHand/RightHandSpellOptions").get_selected_id())
	spellQueue[player][1] = spellSearch(self.get_node("Scroll/UI/LeftHand/LeftHandSpellOptions").get_selected_id())
		
	targetQueue[player][0] = self.get_node("Scroll/UI/RightHand/RightHandTargetingOptions").get_selected_id()
	targetQueue[player][1] = self.get_node("Scroll/UI/LeftHand/LeftHandTargetingOptions").get_selected_id()
	
	player += 1
	
	if player >= entityArray.size():
		process_turn()
	else:
		
		if not entityArray[player].is_wizard:
			process_turn()
		elif not entityArray[player].is_active():
			_on_end_turn_button_pressed()
		else:
			renderWizardSection()

func _on_right_hand_gesture_options_item_selected(index):
	var gesture_ID = self.get_node("Scroll/UI/RightHand/RightHandGestureOptions").get_item_id(index)
	gestureQueue[player][0] = validGestures[gesture_ID]
	
	if gestureQueue[player][0] == "C":
		var leftHand = self.get_node("Scroll/UI/LeftHand/LeftHandGestureOptions")
		#leftHand.select(index)
		#TODO: make sure to change this so that it doesn't break with fear, charm, etc
	
	onGestureChange(false)
	onGestureChange(true)

func _on_left_hand_gesture_options_item_selected(index):
	var gesture_ID = self.get_node("Scroll/UI/LeftHand/LeftHandGestureOptions").get_item_id(index)
	gestureQueue[player][1] = validGestures[gesture_ID]
	
	if gestureQueue[player][1] == "C":
		var rightHand = self.get_node("Scroll/UI/RightHand/RightHandGestureOptions")
		#rightHand.select(index)
	
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
