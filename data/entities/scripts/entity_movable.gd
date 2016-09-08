# Hierarchy Mapping: 
# entity_movable.gd => RigidBody2D
extends RigidBody2D

onready var speed = 1000.0 # Movement speed
var force = Vector2(0, 0) # Movement force

# Force direction
const FORCE = {
	ZERO = Vector2(0, 0),
	UP = Vector2(0, -1),
	DOWN = Vector2(0, 1),
	LEFT = Vector2(-1, 0),
	RIGHT = Vector2(1, 0)
}

# Basically each 'slave var' is updated by other players, which make it look like they are moving 
# in your screen. They are set using rset("var_name", data), 
# where "var_name" is the name of the slave var you got here.
slave var slave_pos = Vector2()
slave var slave_motion = Vector2()
slave var slave_mouse_position = Vector2()
slave var slave_is_sprinting = false


# The process
func _integrate_forces(state):
	var final_vec = Vector2()
	
	# Apply force
	apply_force(state)
	
	# is_network_master() returns true if this is YOURS. 
	# It would return false another player (slave node) calls it.
	# Then you use the slave var (set by the other player) to update player position. 
	if (is_network_master()):
		# Get directional vector
		force = force.normalized()
		
		# Move object
		final_vec = state.get_linear_velocity() + (force * speed * state.get_step())
		
		# Update the slave vars for the other players playing.
		# This lets them know where you are moving, 
		# and is set in the "else:" below on their machine.
		rset("slave_motion",final_vec)
		rset("slave_pos",get_pos())
	else:
		# Move slave with the updated slave var you received from the other player
		set_pos(slave_pos)
		final_vec = slave_motion

	# Move
	state.set_linear_velocity(final_vec)


# This must be overwritten (in the player, but may be used for other movable objects in the future such as barrels, etc.)
func apply_force(state):
	pass
