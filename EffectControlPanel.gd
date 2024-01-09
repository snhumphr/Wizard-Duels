extends VBoxContainer

var paraList = []
var charmList = []

func render(entityArray, player, validCharmGestures):
	clearEffects()
	for entity in entityArray:
		if entity.is_wizard and entity.is_active():
			for effect in entity.effects:
				if effect[0].paralysis and effect[0].hand == "choose" and effect[0].caster_id == player:
					var box = HBoxContainer.new()
					self.add_child(box)
					paraList.append([box, effect[0], entity.id])
					
					var label = Label.new()
					box.add_child(label)
					label.set_text("Paralyze " + entity.name + "'s ")
					
					var button = OptionButton.new()
					button.add_item("Left")
					button.add_item("Right")
					box.add_child(button)
					button.add_to_group("buttons")
					
					var label_two = Label.new()
					box.add_child(label_two)
					label_two.set_text(" hand.")
				elif effect[0].charm_person and effect[0].hand == "choose" and effect[0].gesture == "" and effect[0].caster_id == player and effect[0].caster_id != entity.id:
					var box = HBoxContainer.new()
					self.add_child(box)
					charmList.append([box, effect[0], entity.id])
					
					var label = Label.new()
					box.add_child(label)
					label.set_text("Charm " + entity.name + "'s ")
					
					var button_one = OptionButton.new()
					button_one.add_item("Left")
					button_one.add_item("Right")
					box.add_child(button_one)
					button_one.add_to_group("buttons")
					
					var label_two = Label.new()
					box.add_child(label_two)
					label_two.set_text(" hand into making ")
					
					var button_two = OptionButton.new()
					for gesture in validCharmGestures:
						button_two.add_item(gesture)
					box.add_child(button_two)
					button_two.add_to_group("buttons")

func clearEffects():
	for effect in paraList:
		remove_child(effect[0])
		
	for effect in charmList:
		remove_child(effect[0])
		
	paraList = []
	charmList = []

func getParaList():
	return paraList

func getCharmList():
	return charmList
