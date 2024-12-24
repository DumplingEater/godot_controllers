extends Camera3D


@export var zoom_speed: float = 5.0
@export var mouse_sensitivity: float = 0.005

# Called when the node enters the scene tree for the first time.
func _ready():
	transform = transform.translated(Vector3(0, 10, 10))
	transform = transform.looking_at(Vector3(0, 0, 0))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var parent_body: CharacterBody3D = get_parent()
	var should_rotate_camera = false
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_back"):
		var left_mouse = Input.is_action_pressed("mouse_left_click")
		var right_mouse = Input.is_action_pressed("mouse_right_click")
		
		if not (left_mouse or right_mouse):
			should_rotate_camera = true
	
	if should_rotate_camera:
			var player_direction: Vector3 = parent_body.global_transform.basis.z.normalized()
			var cam_forward: Vector3 = self.global_transform.basis.z
			
			var cam_dir_proj: Vector3 = Vector3(cam_forward.x, 0.0, cam_forward.z)
			var player_dir_proj: Vector3 = Vector3(player_direction.x, 0.0, player_direction.z)
			
			var angle_between: float = cam_dir_proj.signed_angle_to(player_dir_proj, Vector3(0, 1, 0))
			
			var rot_y = Quaternion(Vector3(0, 1, 0), angle_between * 0.05)
			var pos_norm = transform.origin.normalized()
			var rotated = rot_y * pos_norm
			var rotated_and_scaled = rotated * transform.origin.length()
			var offset = rotated_and_scaled - transform.origin
			transform = transform.translated(offset)
			transform = transform.looking_at(Vector3(0, 0, 0))

func _input(event):
	if Input.is_action_pressed("scroll_down"):
		transform = transform.scaled(Vector3(1.1, 1.1, 1.1))
	if Input.is_action_pressed("scroll_up"):
		transform = transform.scaled(Vector3(0.9, 0.9, 0.9))		
	
	if Input.is_action_pressed("mouse_left_click") or Input.is_action_pressed("mouse_right_click"):
		if event is InputEventMouseMotion:
			# Get the mouse motion in the horizontal direction
			var delta_x = -event.relative.x * mouse_sensitivity
			var delta_y = -event.relative.y * mouse_sensitivity
			
			if not Input.is_action_pressed("mouse_left_click"):
				delta_x = 0
			
			# Create a quaternion for the rotation around the Y-axis (up vector)
			var rot_about_y = Quaternion(Vector3(0, 1, 0), delta_x)
			var rot_about_x = Quaternion(transform.basis.x, delta_y)
			var combined_rot = rot_about_x * rot_about_y
			
			# Calculate the current offset of the camera from the target
			#var offset = transform.origin
			var pos_norm = transform.origin.normalized()
			var rotated = combined_rot * pos_norm
			#var rot_about_y = pos_norm.rotated(Vector3(0, 1, 0), delta_x)
			
			var rotated_and_scaled = rotated * (transform.origin.length())
			var offset = rotated_and_scaled - transform.origin
			
			# Update the camera position while keeping the height constant
			transform = transform.translated(offset)
					
			# Ensure the camera is looking at the target
			transform = transform.looking_at(Vector3(0, 0, 0))
