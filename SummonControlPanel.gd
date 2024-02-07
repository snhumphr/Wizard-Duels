extends VBoxContainer

var monsterList = []

signal requestValidTargets

func render(entityArray: Array, player: int):
	
	clearMonsters()
	
	for i in entityArray.size():
		assert(i == entityArray[i].id)
	
	for entity in entityArray:
		if entity.is_monster and entity.summoner_id == player and entity.is_active():
			var box = HBoxContainer.new()
			self.add_child(box)
				
			var label = Label.new()
			box.add_child(label)
			label.set_text("Order " + entity.name + " to attack: ")
			var button = OptionButton.new()
			button.add_to_group("buttons")
			box.add_child(button)
				
			requestValidTargets.emit(entity, button)
				
			monsterList.append([box, entity.id])
			
func clearMonsters():
	
	for child in self.get_children():
		remove_child(child)
		
	monsterList = []
			
func getMonsterList():
	return monsterList
