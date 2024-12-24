extends CharacterBody3D

# How fast the player moves in meters per second.
@export var speed = 14
@export var turn_speed_rad = 3.14 / 40
# The downward acceleration when in the air, in meters per second squared.
@export var fall_acceleration = 75

var target_velocity = Vector3.ZERO


# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	# We create a local variable to store the input direction.
	var direction = Vector3.ZERO
	
	var child_camera = get_node("camera")
	var forward: Vector3 = self.global_transform.basis.z
	var right = self.global_transform.basis.x
	
	# We check for each move input and update the direction accordingly.
	if Input.is_action_pressed("move_right"):
		direction += right
	if Input.is_action_pressed("move_left"):
		direction -= right
	if Input.is_action_pressed("move_back"):
		direction += forward
	if Input.is_action_pressed("move_forward"):
		direction -= forward
	if Input.is_action_just_pressed("jump"):
		target_velocity.y = 30
	
	var mouse_right_clicked = Input.is_action_pressed("mouse_right_click")
	var turn_left = Input.is_action_pressed("turn_left")
	var turn_right = Input.is_action_pressed("turn_right")
	
	if turn_left or turn_right:
		if mouse_right_clicked:
			if turn_right:
				direction += right
			if turn_left:
				direction -= right
		else:
			# Create a quaternion for the rotation around the Y-axis (up vector)
			var sign = 1.0
			if turn_right:
				sign *= -1
			self.rotate_object_local(Vector3(0, 1, 0), turn_speed_rad * sign)
		
	# Ground Velocity
	target_velocity.x = direction.x * speed
	target_velocity.z = direction.z * speed

	# Vertical Velocity
	if not is_on_floor(): # If in the air, fall towards the floor. Literally gravity
		target_velocity.y = target_velocity.y - (fall_acceleration * delta)

	velocity = target_velocity
	move_and_slide()

func _input(event):
	
	var mouse_right_clicked = Input.is_action_pressed("mouse_right_click")
	var turn_left = Input.is_action_pressed("turn_left")
	var turn_right = Input.is_action_pressed("turn_right")
	if mouse_right_clicked or turn_left or turn_right:
		if event is InputEventMouseMotion:
			var child_camera = get_node("camera")
			var mouse_sensitivity = child_camera.mouse_sensitivity
			# Get the mouse motion in the horizontal direction
			var delta_x = -event.relative.x * mouse_sensitivity
			var delta_y = -event.relative.y * mouse_sensitivity
			
			# Create a quaternion for the rotation around the Y-axis (up vector)
			var rot_about_y = Quaternion(Vector3(0, 1, 0), delta_x)
			self.rotate_object_local(Vector3(0, 1, 0), delta_x)
