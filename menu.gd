extends MarginContainer

const PORT = 7777
const DEFAULT_SERVER_IP = "192.168.1.67" # IPv4 LAN
const MAX_CONNECTIONS = 2

func start_duel():
	get_tree().change_scene_to_file("res://preduel.tscn")

func _on_quit_pressed():
	get_tree().quit()

func _on_host_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_CONNECTIONS)
	multiplayer.multiplayer_peer = peer
	start_duel()

func _on_join_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(DEFAULT_SERVER_IP, PORT)
	multiplayer.multiplayer_peer = peer
	start_duel()
