extends VBoxContainer

var monsterList = []

signal requestValidTargets

func render(entityArray, player):
	
	clearInvalidMonsters(entityArray, player)
	
	for entity in entityArray:
		if entity.is_monster and entity.summoner_id == player and entity.is_active():
			var box = null
			for monster in monsterList:
				if entity.id == monster[1]:
					box = monster[0]
					break
			if not box:
				box = HBoxContainer.new()
				self.add_child(box)
				
				var label = Label.new()
				box.add_child(label)
				label.set_text("Order " + entity.name + " to attack: ")
				var button = OptionButton.new()
				box.add_child(button)
				
				requestValidTargets.emit(entity, button)
				
				monsterList.append([box, entity.id])
			else:
				for child in box.get_children():
					if child is OptionButton:
						requestValidTargets.emit(entity, child)
			
func clearInvalidMonsters(entityArray, player):
	for monster in monsterList:
		if not entityArray[monster[1]].is_active() or entityArray[monster[1]].summoner_id != player:
			remove_child(monster[0])
			monsterList.erase(monster)
