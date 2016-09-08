# Hierarchy Mapping: 
# player_offline.gd => entity_movable.gd => RigidBody2D
extends "res://data/entities/scripts/entity_movable.gd"

# Player variables
export var speed_default = 1000.0 # Default speed
export var sprint_speed = 2.5 # Animation speed when sprinting

var position = Vector2(0, 0) # Player world position
var velocity = Vector2(0, 0) # Player velocity used for animation
var mouse_position = Vector2(0, 0) # Used to keep track if your mouse position (look_at)

# Used to make transition between a complete standstill to moving animation less strict
var padding = 25

# Player animations
onready var animation = find_node("animation_player")

# Initialize
func _ready():
	# Enable fixed processing (used for rotation and animation)
	set_fixed_process(true)


# Overwritten - Apply force based on input from client
func apply_force(state):
	var is_sprinting = null
	
	if (is_network_master()):
		# Reset force
		force = Vector2(0, 0)
		
		# Get Input from Player
		var move_left = Input.is_action_pressed("move_left")
		var move_right = Input.is_action_pressed("move_right")
		var move_up = Input.is_action_pressed("move_up")
		var move_down = Input.is_action_pressed("move_down")
		var sprint = Input.is_action_pressed("sprint")
		
		# If we are holding two opposet directions at the same time; 
		# move neither direction
		if (move_right and move_left):
			move_right = false
			move_left = false
			
		if (move_up and move_down):
			move_up = false
			move_down = false
		
		# If we are pressing any move button; we are moving
		var is_moving = move_down || move_left || move_right || move_up
		
		# If we are holding sprint and is moving at the same time;
		# toggle sprint to true
		is_sprinting = sprint && is_moving
		
		# rset_unreliable is the UDP version of rset (which is TCP).
		# The difference is that rset_unreliable may or may not be received
		# by the other players, and is most commonly used for movement; 
		# where it is more important to get the -latest- position, 
		# rather than getting every single position update in a row. 
		#
		# Used to trigger sprint animation for other players
		rset_unreliable("slave_is_sprinting",is_sprinting) 
		
		# We we are not moving, return right away
		if (! is_moving):
			return
		
		# Apply force
		if (move_up):
			force += FORCE.UP
		elif(move_down):
			force += FORCE.DOWN
		if(move_left):
			force += FORCE.LEFT
		elif(move_right):
			force += FORCE.RIGHT
	else:
		# Is slave sprinting?
		is_sprinting = slave_is_sprinting
	
	# If we are sprinting, speed up the animation and speed
	if(is_sprinting):
		animation.set_speed(2.5)
		speed = speed_default * sprint_speed
	else:
		animation.set_speed(1.2)
		speed = speed_default


# Process fixed frame
func _fixed_process(delta):
	# Update mouse position and player rotation
	if ( is_network_master() ):
		mouse_position = get_global_mouse_pos()
		look_at(mouse_position)
		rset_unreliable("slave_mouse_position",mouse_position)
	else:
		# We only need mouse position in order to calculate the direction we look at
		look_at(slave_mouse_position)
	
	# Reverse rotation on player HUD in order to make it appear stable
	get_node("hud").set_rot(-get_rot())
	
	# Get the velocity (used to determine if is_moving() is true or false
	velocity = get_linear_velocity()
	
	# Animate regardless who is moving (only on self)
	animate()


# Animate player movement
func animate():
	# If we are moving and the move animation is not playing; do it
	if(is_moving() && animation.get_current_animation() != "moving"):
		animation.play("moving")
	# If we are idle and the idle animation is not playing; do it
	elif(!is_moving() && animation.get_current_animation() != "idle"):
		animation.play("idle")


# Return true if player is within a certain velocity threshold.
# This prevents the player from playing the move animation when we are slightly moving.
func is_moving():
	return abs(velocity.x) > padding || abs(velocity.y) > padding
