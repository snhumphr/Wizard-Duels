extends RichTextLabel


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func render(entityArray, player):
	self.clear()
	for i in entityArray.size():
		var wizard = entityArray[i]
		if wizard.is_wizard:
			self.newline()
			self.add_text(wizard.name)
			if player == i:
				self.add_text(" (you)")
			self.newline()
			self.add_text("    HP: " + str(wizard.hp) + "/" + str(wizard.max_hp))
			self.newline()
			self.add_text("    Right Hand: ")
			self.add_text("-".join(wizard.right_hand_gestures))
			self.newline()
			self.add_text("    Left Hand: ")
			self.add_text("-".join(wizard.left_hand_gestures))
			self.newline()
	self.newline()
