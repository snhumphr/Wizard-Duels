extends VBoxContainer

var length = 22

func init(spellArray):
	
	setupSpellList(spellArray)
	#self.get_node("SpellList").init(spellArray)

func setupSpellList(spellArray):
	
	var titleBox = HBoxContainer.new()
	self.add_child(titleBox)
	var title = Label.new()
	title.set_text("List of Spells:")
	titleBox.add_child(title)
	#self.add_text("List of Spells:")
	#self.newline()
	
	var spellDict = {}
	
	for spell in spellArray:
		if not spellDict.has(spell.name):
			spellDict[spell.name] = [spell.gestures]
		else:
			spellDict[spell.name].append(spell.gestures)
	
	for spell in spellDict.keys():
		var line = HBoxContainer.new()
		self.add_child(line)
		
		var spellButton = Button.new()
		spellButton.set_text(spell)
		line.add_child(spellButton)
		
		var text = ""
		for i in range(length-spell.length()):
			text += " "
		for s in range(spellDict[spell].size()):
			if s > 0:
				text += " or "
			for i in spellDict[spell][s].size():
				if spellDict[spell][s][i] == "C":
					text += "CC"
				else:
					text += spellDict[spell][s][i]
				if i + 1 < spellDict[spell][s].size():
					text += "-"
		var gestures = Label.new()
		gestures.set_text(text)
		line.add_child(gestures)
		#self.newline()

func addLine():
	pass
