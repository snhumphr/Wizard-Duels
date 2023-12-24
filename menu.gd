extends MarginContainer

const PORT = 7777
var defaultIP
var numButton
var addressButton
var numbers = [2, 3, 4, 5, 6, 7]
var max_connections
var numWizards = 1

func _ready():
	numButton = self.get_node("MenuItems/HostBar/NumWizButton")
	addressButton = self.get_node("MenuItems/JoinBar/IpAddressField")
	for number in numbers:
		numButton.add_item(str(number), number)
	numButton.select(0) #Default to a 2 player duel
	defaultIP = IP.resolve_hostname(str(OS.get_environment("COMPUTERNAME")),1)
	addressButton.set_text(defaultIP)

func preduel():
	self.get_node("MenuItems").set_visible(false)
	self.get_node("WaitingLobby").set_visible(true)
	multiplayer.peer_connected.connect(newWizard)
	
func newWizard(id: int):
	print(multiplayer.is_server())
	print(multiplayer.get_peers().size())
	print(str(max_connections))
	if multiplayer.is_server() and multiplayer.get_peers().size() + 1 == max_connections:
		print("awoo")
		self.rpc("start_duel")

@rpc("authority", "reliable", "call_local")
func start_duel():
	get_tree().change_scene_to_file("res://game.tscn")

func _on_quit_pressed():
	get_tree().quit()

func _on_host_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	max_connections = numButton.get_selected_id()
	numWizards = max_connections
	peer.create_server(PORT, max_connections)
	multiplayer.multiplayer_peer = peer
	preduel()

func _on_join_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	defaultIP = addressButton.get_text()
	peer.create_client(defaultIP, PORT)
	multiplayer.multiplayer_peer = peer
	preduel()
