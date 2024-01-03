extends RichTextLabel


var length = 22

# Future ideas:
# Make thunderclap get a strikethrough mark if it's already been used


# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func init(spellArray):
	self.add_text("List of Spells:")
	self.newline()
	
	var spellDict = {}
	
	for spell in spellArray:
		if not spellDict.has(spell.name):
			spellDict[spell.name] = [spell.gestures]
		else:
			spellDict[spell.name].append(spell.gestures)
	
	for spell in spellDict.keys():
		self.add_text(spell)
		for i in range(length-spell.length()):
			self.add_text(" ")
		for s in range(spellDict[spell].size()):
			if s > 0:
				self.add_text(" or ")
			for i in spellDict[spell][s].size():
				if spellDict[spell][s][i] == "C":
					self.add_text("CC")
				else:
					self.add_text(spellDict[spell][s][i])
				if i + 1 < spellDict[spell][s].size():
					self.add_text("-")
		self.newline()
	self.newline()
	
	for spell in spellArray:
		break
		self.add_text(spell.name)
		for i in range(length-spell.name.length()):
			self.add_text(" ")
		for i in spell.gestures.size():
			if spell.gestures[i] == "C":
				self.add_text("CC")
			else:
				self.add_text(spell.gestures[i])
			if i + 1 < spell.gestures.size():
				self.add_text("-")
		self.newline()
	self.newline()
