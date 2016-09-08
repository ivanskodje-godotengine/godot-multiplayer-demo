extends Node

# NETWORK DATA
# Port Tip: Check the web for available ports that is not preoccupied by other important services
# Port Tip #2: If you are the server; you may want to open it (NAT, Firewall)
const SERVER_PORT = 31416

# GAMEDATA
var players = {} # Dictionary containing player names and their ID
var player_name # Your own player name

# SIGNALS to Main Menu (GUI)
signal refresh_lobby()
signal server_ended()
signal server_error()
signal connection_success()
signal connection_fail()


# Join a server
func join_game(name, ip_address):
	# Store own player name
	player_name = name
	
	# Initializing the network as server
	var host = NetworkedMultiplayerENet.new()
	host.create_client(ip_address, SERVER_PORT)
	get_tree().set_network_peer(host)

# Host the server
func host_game(name):
	# Store own player name
	player_name = name
	
	# Initializing the network as client
	var host = NetworkedMultiplayerENet.new()
	host.create_server(SERVER_PORT, 6) # Max 6 players can be connected
	get_tree().set_network_peer(host)


func _ready():
	# Networking signals (high level networking)
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")


# Client connected with you (can be both server or client)
func _player_connected(id):
	pass


# Client disconnected from you
func _player_disconnected(id):
	# If I am server, send a signal to inform that an player disconnected
	unregister_player(id)
	rpc("unregister_player", id)


# Successfully connected to server (client)
func _connected_ok():
	# Send signal to server that we are ready to be assigned;
	# Either to lobby or ingame
	rpc_id(1, "user_ready", get_tree().get_network_unique_id(), player_name)
	pass


# Server receives this from players that have just connected
remote func user_ready(id, player_name):
	# Only the server can run this!
	if(get_tree().is_network_server()):
		# If we are ingame, add player to session, else send to lobby	
		if(has_node("/root/world")):
			rpc_id(id, "register_in_game")
		else:
			rpc_id(id, "register_at_lobby")


# Register yourself directly ingame
remote func register_in_game():
	rpc("register_new_player", get_tree().get_network_unique_id(), player_name)
	register_new_player(get_tree().get_network_unique_id(), player_name)


# Register myself with other players at lobby
remote func register_at_lobby():
	rpc("register_player", get_tree().get_network_unique_id(), player_name)
	emit_signal("connection_success") # Sends command to gui & will send player to lobby


# Could not connect to server (client)
func _connected_fail():
	get_tree().set_network_peer(null)
	emit_signal("connection_fail")


# Server disconnected (client)
func _server_disconnected():
	quit_game()
	emit_signal("server_ended")


# Register the player and jump ingame
remote func register_new_player(id, name):
	# This runs only once from server
	if(get_tree().is_network_server()):
		# Send info about server to new player
		rpc_id(id, "register_new_player", 1, player_name) 
		
		# Send the new player info about the other players
		for peer_id in players:
			rpc_id(id, "register_new_player", peer_id, players[peer_id]) 
	
	# Add new player to your player list
	players[id] = name
	
	# Hardcoded spawns; could be done better by getting 
	# the number of spawns from the map and go from there.
	# At this stage, hardcoding will suffice...
	randomize() # If you dont add this line, rnd_spawn will always get the same number.
	var rnd_spawn = int(rand_range(1,7)) # 1-6
	
	var spawn_pos = {} # Dictionary
	spawn_pos[id] = rnd_spawn # Insert random spawn
	
	# Spawn player with id 'id' and at position 'spawn_pos[id]'
	print("Spawning " + str(name))
	spawn_player(spawn_pos) 


# Register player the ol' fashioned way and refresh lobby
remote func register_player(id, name):
	# If I am the server (not run on clients)
	if(get_tree().is_network_server()):
		rpc_id(id, "register_player", 1, player_name) # Send info about server to new player
		
		# For each player, send the new guy info of all players (from server)
		for peer_id in players:
			rpc_id(id, "register_player", peer_id, players[peer_id]) # Send the new player info about others
			rpc_id(peer_id, "register_player", id, name) # Send others info about the new player
	
	players[id] = name # update player list

	# Notify lobby (GUI) about changes
	emit_signal("refresh_lobby")


# Unregister a player, whether he is in lobby or ingame
remote func unregister_player(id):
	# If the game is running
	if(has_node("/root/world")):
		# Remove player from game
		if(has_node("/root/world/players/" + str(id))):
			get_node("/root/world/players/" + str(id)).queue_free()
		players.erase(id)
	else:
		# Remove from lobby
		players.erase(id)
		emit_signal("refresh_lobby")


# Returns a list of players (lobby)
func get_player_list():
	return players.values()


# Returns your name
func get_player_name():
	return player_name


# Quits the game, will automatically tell the server you disconnected; neat.
func quit_game():
	get_tree().set_network_peer(null)
	players.clear()


func start_game():
	# Set spawn pos for each player
	var spawn_points = {}

	# Generate spawn points associated with each player
	spawn_points[1] = 1 # Set first spawn point to server
	
	# Add spawn point with each player in spawn_points dictionary
	var count = 2
	for p in players:
		print(str(p) + ", spawn at " + str(count))
		spawn_points[p] = count
		count += 1
	
	# Tell each player 'p' with id 'spawn_points' to spawn at specified 'spawn_points[id]'
	for p in players:
		rpc_id(p, "spawn_player", spawn_points)
	
	spawn_player(spawn_points)
	pass


remote func spawn_player(spawn_points):
	# A world without identity.
	# To be, or not to be.
	var world
	
	# If your game have already started, we get the current reference, 
	# else we create our instance and add it to root
	if(has_node("/root/world")):
		world = get_node("/root/world")
	else:
		world = load("res://data/maps/world.tscn").instance()
		get_tree().get_root().add_child(world)
		get_tree().get_root().get_node("main_menu").hide() # Away with the menu! AWAY I SAY!
		world.get_node("hud/stats/name").set_text(player_name)
	
	# Create Scenes to instance (further down)
	var player_scene = load("res://data/entities/player/player.tscn")
	var camera_scene = load("res://data/entities/player/camera.tscn")
	
	# Spawn! Spawn ALL the players!
	# There are only multiple players when we wait for players in lobby before starting.
	# Else we generate a random spawn point and throw him in with the other players.
	for p in spawn_points:
		# Create player instance
		var player = player_scene.instance()
		
		# Set Player ID as node name - Unique for each player!
		player.set_name(str(p))
		
		# Set spawn position for the player (on a spawn point from the map)
		var spawn_pos = world.find_node(str(spawn_points[p])).get_pos()
		player.set_pos(spawn_pos)
		
		
		# If the new player is you
		if (p == get_tree().get_network_unique_id()):
			# Set as master on yourself
			player.set_network_mode( NETWORK_MODE_MASTER )
			player.add_child(camera_scene.instance()) # Add camera to your player
			
			
		else:
			# Slavery is legal here. 
			# No camera for you, slave! None!
			player.set_network_mode( NETWORK_MODE_SLAVE )
			# Add player name
			player.get_node("hud/player_name").set_text(str(players[p]))
		
		# Add the player (or you) to the world!
		world.get_node("players").add_child(player)