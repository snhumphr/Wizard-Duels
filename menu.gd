extends MarginContainer

const PORT : int = 1337

func start_duel():
	get_tree().change_scene_to_file("res://preduel.tscn")

func _on_quit_pressed():
	get_tree().quit()

func _on_host_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	start_duel()

func _on_join_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_client("localhost", PORT)
	multiplayer.multiplayer_peer = peer
	start_duel()
