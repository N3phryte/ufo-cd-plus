extends Node3D

@export var player_scene: PackedScene = preload("res://objects/multiplayer_player.tscn")

# Keep track of spawned players
var players: Dictionary = {}

func _ready():
	# Spawn existing players
	for peer_id in Network.connected_players.keys():
		_spawn_player_server(peer_id, Network.connected_players[peer_id])

	# Listen for new connections
	multiplayer.peer_connected.connect(_on_peer_connected)

# --- SERVER: spawns a player node and notifies all clients ---
func _spawn_player_server(peer_id: int, info: Dictionary):
	if players.has(peer_id):
		return

	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.global_position = Vector3(randi_range(-50, 50), 1, randi_range(-50, 50))

	# IMPORTANT: assign authority BEFORE add_child()
	player.set_multiplayer_authority(peer_id)

	add_child(player)
	players[peer_id] = player

	if multiplayer.is_server():
		for id in multiplayer.get_peers():
			rpc_id(id, "_rpc_spawn_player", peer_id, player.global_position)


# --- CLIENT RPC: spawn a player node ---
@rpc("any_peer", "reliable")
func _rpc_spawn_player(peer_id: int, pos: Vector3):
	if players.has(peer_id):
		return

	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.global_position = pos

	# IMPORTANT: assign authority BEFORE add_child()
	if peer_id == multiplayer.get_unique_id():
		player.set_multiplayer_authority(peer_id)

	add_child(player)
	players[peer_id] = player



# --- handle new peers connecting late ---
func _on_peer_connected(id: int):
	if multiplayer.is_server():
		var info = Network.connected_players.get(id, {"name": "Player_%d" % id})
		_spawn_player_server(id, info)
