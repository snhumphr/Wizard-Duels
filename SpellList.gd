extends RichTextLabel


var length = 20

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func init(spellArray):
	self.add_text("List of Spells:")
	self.newline()
	for spell in spellArray:
		self.add_text(spell.name)
		for i in range(length-spell.name.length()):
			self.add_text(" ")
		self.add_text("-".join(spell.gestures))
		self.newline()
	self.newline()
