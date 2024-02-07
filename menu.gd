extends MarginContainer

const PORT = 7777
var defaultIP
var numButton
var addressButton
var numbers = [2, 3, 4, 5, 6, 7]
var max_connections
var numWizards = 1

var path = "user://mywizard.name"
var wizardName = ""

func _ready():
	GlobalDataSingle.namesDict = {}
	numButton = self.get_node("MenuItems/HostBar/NumWizButton")
	addressButton = self.get_node("MenuItems/JoinBar/IpAddressField")
	for number in numbers:
		numButton.add_item(str(number), number)
	numButton.select(0) #Default to a 2 player duel
	if OS.has_feature("windows"):
		defaultIP = IP.resolve_hostname(str(OS.get_environment("COMPUTERNAME")),1)
	else: #This needs testing on non-windows devices
		defaultIP = IP.resolve_hostname(str(OS.get_environment("HOSTNAME")),1)
	addressButton.set_text(defaultIP)

	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		wizardName = file.get_pascal_string()
	else:
		setGameStartButtonsDisabled(true)

func setGameStartButtonsDisabled(value: bool):
	self.get_node("MenuItems/HostBar/HostButton").set_disabled(value)
	self.get_node("MenuItems/JoinBar/JoinButton").set_disabled(value)

func swapToLobby():
	self.get_node("WaitingLobby").set_visible(true)
	
	self.get_node("WizardCustomization").set_visible(false)
	self.get_node("MenuItems").set_visible(false)
	
	multiplayer.peer_connected.connect(newWizard)
	
func swapToMenu():
	self.get_node("MenuItems").set_visible(true)
	
	self.get_node("WaitingLobby").set_visible(false)
	self.get_node("WizardCustomization").set_visible(false)
	
func swapToWizCustom():
	self.get_node("WizardCustomization").set_visible(true)
		
	self.get_node("MenuItems").set_visible(false)
	self.get_node("WaitingLobby").set_visible(false)
	
func newWizard(_id: int):
	self.rpc("receive_name", wizardName, multiplayer.get_unique_id())
	await get_tree().create_timer(2.0).timeout
	if multiplayer.is_server() and multiplayer.get_peers().size() + 1 == max_connections:
		self.rpc("start_duel")

@rpc("any_peer", "reliable", "call_remote")
func receive_name(player_name: String, id: int):
	
	if not GlobalDataSingle.namesDict.has(id):
		var label = Label.new()
		label.set_text(player_name + " is waiting for the duel to begin")
		self.get_node("WaitingLobby").add_child(label)
	
	GlobalDataSingle.namesDict[id] = player_name

@rpc("authority", "reliable", "call_local")
func start_duel():
	GlobalDataSingle.namesDict[multiplayer.get_unique_id()] = wizardName
	get_tree().change_scene_to_file("res://game.tscn")

func _on_quit_pressed():
	get_tree().quit()

func _on_host_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	max_connections = numButton.get_selected_id()
	numWizards = max_connections
	peer.create_server(PORT, max_connections)
	multiplayer.multiplayer_peer = peer
	swapToLobby()

func _on_join_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	defaultIP = addressButton.get_text()
	peer.create_client(defaultIP, PORT)
	multiplayer.multiplayer_peer = peer
	swapToLobby()

func _on_custom_button_pressed():
	self.get_node("WizardCustomization/NameBar/NameField").set_text(wizardName)
	swapToWizCustom()

func _on_save_button_pressed():
	var newName = self.get_node("WizardCustomization/NameBar/NameField").get_text()
	wizardName = newName
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_pascal_string(newName)
	if wizardName != "":
		setGameStartButtonsDisabled(false)
	swapToMenu()
