extends MarginContainer

var numWizards = 1
var player_data

func _ready():
	multiplayer.peer_connected.connect(newWizard)
	player_data = load("res://player.gd")

func newWizard(id: int):
	numWizards += 1
	if numWizards == 2:
		startDuel()
	
func startDuel():
	get_tree().change_scene_to_file("res://game.tscn")
