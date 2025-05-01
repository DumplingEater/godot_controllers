extends Camera3D

@export var look_speed: float = 1.0
@export var max_look_elevation: float = (3.0 * PI) / 8.0
var current_pitch: float = 0.0
@export var look_sensitivity: float = 1.0

var locked: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _input(event: InputEvent):
	if locked:
		return
	if event is InputEventMouseMotion:
		# get rotations
		var yaw = event.relative.x * look_speed * -1.0 * look_sensitivity
		var pitch = event.relative.y * look_speed * -1.0 * look_sensitivity
		
		# add pitch
		current_pitch += pitch
		current_pitch = max(min(current_pitch, max_look_elevation), -max_look_elevation)
		
		# now get clamped pitch delta
		pitch = current_pitch - self.rotation.x
		self.rotate(self.basis.x, pitch)
		
		# do yaw because that's easier
		self.rotate(Vector3.UP, yaw)
