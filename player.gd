extends Node

static var id = {}

static func get_wiz_id_from_peer_id(peer_id):
	return id[peer_id]
	
static func set_id(peer_id, wiz_id):
	if not id.has(peer_id):
		id[peer_id] = wiz_id
	print(str(peer_id) + "'s wiz id set to " + str(wiz_id))
