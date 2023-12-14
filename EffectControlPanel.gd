extends VBoxContainer

var effectList = []

func render(entityArray, player):
	clearEffects()
	for entity in entityArray:
		if entity.is_wizard and entity.is_active():
			for effect in entity.effects:
				if effect[0].paralysis and effect[0].hand == "choose" and effect[0].caster_id == player:
					var box = HBoxContainer.new()
					self.add_child(box)
					effectList.append([box, effect[0], entity.id])
					
					var label = Label.new()
					box.add_child(label)
					label.set_text("Paralyze " + entity.name + "'s ")
					
					var button = OptionButton.new()
					button.add_item("Left")
					button.add_item("Right")
					box.add_child(button)
					
					var label_two = Label.new()
					box.add_child(label_two)
					label_two.set_text(" hand.")

func clearEffects():
	for effect in effectList:
		remove_child(effect[0])
		
	effectList = []

func getEffectList():
	return effectList
