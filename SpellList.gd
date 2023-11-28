extends RichTextLabel


# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func init(spellArray):
	self.add_text("List of Spells:")
	self.newline()
	for spell in spellArray:
		self.add_text(spell.name)
		self.add_text("  ")
		self.add_text("-".join(spell.gestures))
		self.newline()
	self.newline()
