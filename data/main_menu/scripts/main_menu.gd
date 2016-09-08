extends Node

# CONTAINERS
onready var menu_container = get_node("menu_container")
onready var join_container = get_node("join_container")
onready var host_container = get_node("host_container")
onready var lobby_container = get_node("lobby_container")

# Player Name
const PLAYER_NAME_DEFAULT = "Player"
const SERVER_NAME_DEFAULT = "Server"

# MAIN MENU - Join Game
# Opens up the 'Connect to Server' window
func _on_join_game_button_pressed():
	menu_container.hide()
	join_container.show() 


# MAIN MENU - Host Game
# Opens up the 'Choose a nickname' window
func _on_host_game_button_pressed():
	menu_container.hide()
	host_container.show()


# MAIN MENU - Quit Game
func _on_quit_game_button_pressed():
	get_tree().quit()


# JOIN CONTAINER - Connect
# Attempts to connect to the server
# If successful, continue to Lobby or jump in-game (if running)
func _on_connect_button_pressed():
	# Check entered IP address for errors
	var ip_address = join_container.find_node("lineedit_ip_address").get_text()
	if(!ip_address.is_valid_ip_address()):
		join_container.find_node("label_error").set_text("Invalid IP address")
		return
	
	# Check nickname for errors
	var player_name = join_container.find_node("lineedit_nickname").get_text()
	if(player_name == ""):
		join_container.find_node("label_error").set_text("Nickname cannot be empty")
		return
	
	# Clear error (if any)
	join_container.find_node("label_error").set_text("")
	
	# Connect to server
	gamestate.join_game(player_name, ip_address)
	
	# While we are attempting to connect, disable button for 'continue'
	join_container.find_node("connect_button").set_disabled(true)


# HOST CONTAINER - Continue (from choosing a nickname)
# Opens the server for connectivity from clients
func _on_continue_button_pressed():
	# Check if nickname is valid
	var player_name = host_container.find_node("lineedit_nickname").get_text()
	if(player_name == ""):
		host_container.find_node("label_error").set_text("Nickname cannot be empty")
		return
	
	# Clear error (if any)
	host_container.find_node("label_error").set_text("")
	
	# Establish network
	gamestate.host_game(player_name)
	
	# Refresh Player List (with your own name)
	refresh_lobby()
	
	# Toggle to Lobby
	host_container.hide()
	lobby_container.show()
	lobby_container.find_node("start_game_button").set_disabled(false)


# LOBBY CONTAINER - Starts the Game
func _on_start_game_button_pressed():
	gamestate.start_game()


# LOBBY CONTAINER - Cancel Lobby
# (The only time you are already connected from main menu)
func _on_cancel_lobby_button_pressed():
	# Toggle containers
	lobby_container.hide()
	menu_container.show()
	
	# Disconnect networking
	gamestate.quit_game()
	
	# Enable buttons
	join_container.find_node("connect_button").set_disabled(false)


# ALL - Cancel (from any container)
func _on_cancel_button_pressed():
	menu_container.show()
	join_container.hide() 
	join_container.find_node("label_error").set_text("")
	host_container.hide()
	host_container.find_node("label_error").set_text("")


func _ready():
	# Set default nicknames on host/join
	join_container.find_node("lineedit_nickname").set_text(PLAYER_NAME_DEFAULT)
	host_container.find_node("lineedit_nickname").set_text(SERVER_NAME_DEFAULT)
	
	# Setup Network Signaling between Gamestate and Game UI
	gamestate.connect("refresh_lobby", self, "refresh_lobby")
	gamestate.connect("server_ended", self, "_on_server_ended")
	gamestate.connect("server_error", self, "_on_server_error")
	gamestate.connect("connection_success", self, "_on_connection_success")
	gamestate.connect("connection_fail", self, "_on_connection_fail")

# Refresh Lobby's player list
# This is run after we have gotten updates from the server regarding new players
func refresh_lobby():
	# Get the latest list of players from gamestate
	var player_list = gamestate.get_player_list()
	player_list.sort()
	
	# Add the updated player_list to the itemlist
	var itemlist = lobby_container.find_node("itemlist_players")
	itemlist.clear()
	itemlist.add_item(gamestate.get_player_name() + " (YOU)") # Add yourself to the top
	
	# Add every other player to the list
	for player in player_list:
		itemlist.add_item(player)
	
	# If you are not the server, we disable the 'start game' button
	if(!get_tree().is_network_server()):
		lobby_container.find_node("start_game_button").set_disabled(true)


# Handles what to happen after server ends
func _on_server_ended():
	lobby_container.hide()
	join_container.hide()
	join_container.find_node("connect_button").set_disabled(false)
	menu_container.show()
	
	# If we are ingame, remove world from existence!
	if(has_node("/root/world")):
		get_node("/root/main_menu").show() # Enable main menu
		get_node("/root/world").queue_free() # Terminate world


func _on_server_error():
	print("_ON_SERVER_ERROR: Unknown error")


func _on_connection_success():
	join_container.hide()
	lobby_container.show()


func _on_connection_fail():
	# Display error telling the user that the server cannot be connected
	join_container.find_node("label_error").set_text("Cannot connect to server, try again or use another IP address")
	
	# Enable continue button again
	join_container.find_node("connect_button").set_disabled(false)