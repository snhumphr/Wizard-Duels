extends VBoxContainer

var length = 22

func init(spellArray: Array):
	
	var titleBox = HBoxContainer.new()
	self.add_child(titleBox)
	var title = Label.new()
	title.set_text("List of Spells:")
	titleBox.add_child(title)
	#self.add_text("List of Spells:")
	#self.newline()
	
	var spellDict = {}
	var descDict = {}
	
	for spell in spellArray:
		if not spellDict.has(spell.name):
			spellDict[spell.name] = [spell.gestures]
			descDict[spell.name] = spell.description
		else:
			spellDict[spell.name].append(spell.gestures)
	
	for spell in spellDict.keys():
		var line = HBoxContainer.new()
		self.add_child(line)
		
		#var spellButton = Button.new()
		#spellButton.set_text(spell)
		#line.add_child(spellButton)
		#spellButton.pressed.connect(_on_spell_button_pressed.bind(spellButton.get_text()))
		
		var desc = descDict[spell]
		var text = "[hint=" + desc + "]"
		
		
		text += spell
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
		text += "[/hint]"
		
		var gestures = RichTextLabel.new()
		gestures.custom_minimum_size = Vector2(500, 35)
		gestures.set_fit_content(true)
		gestures.set_use_bbcode(true)
		gestures.set_text("")
		gestures.append_text(text)
		
		line.add_child(gestures)

func _on_spell_button_pressed(spell: String):
	get_tree().call_group("spellinfo", "displaySpellInfo", spell)
