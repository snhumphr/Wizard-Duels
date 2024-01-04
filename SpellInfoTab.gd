extends RichTextLabel

var spellDict = {}

func _ready():
	add_to_group("spellinfo")

func init(spellArray):
	for spell in spellArray:
		if not spellDict.has(spell.name):
			spellDict[spell.name] = spell.description
		else:
			assert(spellDict[spell.name] == spell.description)

func displaySpellInfo(spell):
	var info = "\n\n"
	info += spell
	info += "\n\n"
	info += spellDict[spell]
	self.set_text(info)
