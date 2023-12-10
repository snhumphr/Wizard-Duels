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
			for effect in entityArray[i].effects:
				self.add_text(" " + effect[0].name + "(" + str(effect[1]) + ")")
			if player == i:
				self.add_text(" (you)")
			self.newline()
			self.add_text("    HP: " + str(wizard.hp) + "/" + str(wizard.max_hp))
			self.newline()
			self.add_text("    Right Hand: ")
			self.add_text("-".join(wizard.right_hand_gestures))
			self.newline()
			self.add_text("    Left Hand:  ")
			self.add_text("-".join(wizard.left_hand_gestures))
			self.newline()
			for e in entityArray:
				if e.is_monster and e.is_active() and e.summoner_id == wizard.id:
					self.add_text("    " + e.name)
					for effect in e.effects:
						self.add_text(" " + effect[0].name + "(" + str(effect[1]) + ")")
					self.newline()
					self.add_text("        " + "HP: " + str(e.hp) + "/" + str(e.max_hp))
					self.newline()
	self.newline()
