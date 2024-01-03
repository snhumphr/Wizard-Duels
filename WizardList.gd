extends RichTextLabel


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func render(entityArray, player):
	self.clear()
	renderNeutrals(entityArray)
	var is_player = false
	for i in entityArray.size():
		if i == player:
			is_player = true
		var wizard = entityArray[i]
		if wizard.is_wizard:
			self.newline()
			self.add_text(wizard.name)
			for effect in entityArray[i].effects:
				if not effect[0].is_silent:
					var duration = str(effect[1])
					if effect[0].permanent:
						duration = "permanent"
					self.add_text(" " + effect[0].name + "(" + duration + ")")
			if player == i:
				self.add_text(" (you)")
			self.newline()
			self.add_text("    HP: " + str(wizard.hp) + "/" + str(wizard.max_hp))
			self.newline()
			self.add_text("    Right Hand: ")
			renderGestures(wizard.right_hand_gestures, wizard.right_hidden, is_player)
			self.newline()
			self.add_text("    Left Hand:  ")
			renderGestures(wizard.left_hand_gestures, wizard.left_hidden, is_player)
			self.newline()
			for e in entityArray:
				if e.is_monster and e.is_active() and e.summoner_id == wizard.id:
					renderMonster(e, "    ")
	self.newline()

func renderNeutrals(entityArray):
	for entity in entityArray:
		if entity.is_monster and entity.is_active() and entity.summoner_id == -1:
			renderMonster(entity, "")
	
func renderMonster(monster, padding):
	self.add_text(padding + monster.name)
	for effect in monster.effects:
		self.add_text(" " + effect[0].name + "(" + str(effect[1]) + ")")
	self.newline()
	self.add_text("    " + padding + "HP: " + str(monster.hp) + "/" + str(monster.max_hp))
	self.newline()

func renderGestures(gesture_list, hidden_list, is_player):
	for i in gesture_list.size():
		if i > 0:
			self.add_text("-")
		if hidden_list[i] and not is_player:
			self.add_text("?")
		else:
			self.add_text(gesture_list[i])
