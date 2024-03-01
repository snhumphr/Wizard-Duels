extends ItemList

var length = 22

func init(spellArray: Array):
	
	var spellDict = {}
	var descDict = {}
	var gesturesDict = {}
	
	for spell in spellArray:
		if not spellDict.has(spell.name):
			spellDict[spell.name] = spell
			gesturesDict[spell.name] = [spell.gestures]
			descDict[spell.name] = spell.description
		else:
			gesturesDict[spell.name].append(spell.gestures)
	
	for s in spellDict.keys().size():
		
		var spell = spellDict[spellDict.keys()[s]]
		var gestures = gesturesDict[spell.name]
		var desc = descDict[spell.name]
		var text = spell.name
		
		for i in range(length-text.length()):
			text += " "
		for g in range(gesturesDict[spell.name].size()):
			if g > 0:
				text += " or "
			for i in gestures[g].size():
				if gestures[g][i] == "C":
					text += "CC"
				else:
					text += gestures[g][i]
				if i + 1 < gestures[g].size():
					text += "-"
		
		
		var index = self.add_item(text)
		self.set_item_tooltip(index, desc)

func _on_spell_button_pressed(spell: String):
	get_tree().call_group("spellinfo", "displaySpellInfo", spell)
