extends RichTextLabel

var spellDict = {}

func _ready():
	add_to_group("spellinfo")

func init(spellArray):
	for spell in spellArray:
		if not spellDict.has(spell.name):
			spellDict[spell.name] = spell.description
			print(spell.description)
		else:
			assert(spellDict[spell.name] == spell.description)

func displaySpellInfo(spell):
	print("snork " + spellDict[spell])
	self.set_text(spellDict[spell])
