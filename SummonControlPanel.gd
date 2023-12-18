extends VBoxContainer

var monsterList = []

signal requestValidTargets

func render(entityArray, player):
	
	clearInvalidMonsters(entityArray, player)
	
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
			box.add_child(button)
				
			requestValidTargets.emit(entity, button)
				
			monsterList.append([box, entity.id])
			
func clearInvalidMonsters(entityArray, player):
	
	for child in self.get_children():
		remove_child(child)
		
	monsterList = []
	
	#var deletionArray = []
	#for i in monsterList.size():
	#	remove_child(monsterList[i][0])
	#	deletionArray.append(i)
	
	#for index in deletionArray:
	#	monsterList.remove_at(index)
		#print(str(index))
			
func getMonsterList():
	return monsterList
