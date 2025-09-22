extends Camera3D

@export var look_speed: float = 1.0
@export var max_look_elevation: float = (3.0 * PI) / 8.0
var current_pitch: float = 0.0
@export var look_sensitivity: float = 1.0
@onready var body: CharacterBody3D = owner   # adjust path to your player body

var locked: bool = false

var original_y: float
var bob_timer: float = 0.0
var bob_speed: float = 6.0     # frequency of the bob (steps per second)
var bob_amount: float = 0.0125   # height of the bob

func _ready() -> void:
	original_y = position.y
	SignalManager.Players.LockPlayer.connect(_on_player_locked)
	SignalManager.Players.UnlockPlayer.connect(_on_player_unlocked)

func _on_player_locked():
	locked = true

func _on_player_unlocked():
	locked = false

func _process(delta: float) -> void:
	if locked:
		return
		
	var velocity = body.velocity
	var horiz_speed = Vector2(velocity.x, velocity.z).length()

	if horiz_speed > 0.1 and body.is_on_floor():
		bob_timer += delta * bob_speed * (horiz_speed / 5.0) # scale with speed
		var bob_y = sin(bob_timer * TAU) * bob_amount
		position.y = bob_y
	else:
		# reset smoothly when standing still
		bob_timer = 0.0
		position.y = lerp(position.y, 0.0, 10.0 * delta)

# Called when the node enters the scene tree for the first time.
func turn_off() -> void:
	current = false
	set_process_input(false)

func set_local() -> void:
	current = true
	set_process_input(true)

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
