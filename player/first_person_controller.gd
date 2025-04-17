extends CharacterBody3D

@export var move_speed: float = 2.0
@export var sprint_speed: float = 10.0
@export var jump_impulse: float = 4.0
@export var gravity: float = -9.81
@export var mass: float = 100

@export var camera: Camera3D = null
var swimming: bool = false

var locked: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("player", true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if locked:
		return
	# if on floor, zero out horizontal motion so we don't slide
	if self.swimming:
		self.velocity.x *= 0.6
		self.velocity.z *= 0.6
	else:
		self.velocity.x = 0.0
		self.velocity.z = 0.0
	
	var speed: float = move_speed
	if Input.is_action_pressed("sprint"):
		move_speed = sprint_speed
	
	if Input.is_action_pressed("move_forward"):
		var forward: Vector3 = self.camera.basis.z * -1.0 
		var forward_proj: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()
		self.velocity += forward_proj * speed
	
	if Input.is_action_pressed("move_backward"):
		var backward: Vector3 = self.camera.basis.z
		var backward_proj: Vector3 = Vector3(backward.x, 0.0, backward.z).normalized()
		self.velocity += backward_proj * speed
		
	if Input.is_action_pressed("move_left"):
		var left: Vector3 = self.camera.basis.x * -1.0
		var left_proj: Vector3 = Vector3(left.x, 0.0, left.z).normalized()
		self.velocity += left_proj * speed
		
	if Input.is_action_pressed("move_right"):
		var right: Vector3 = self.camera.basis.x
		var right_proj: Vector3 = Vector3(right.x, 0.0, right.z).normalized()
		self.velocity += right_proj * speed
	
	if Input.is_action_pressed("jump") and self.is_on_floor():
		self.velocity += Vector3.UP * jump_impulse

func _physics_process(delta: float) -> void:
	if not self.is_on_floor() and not self.swimming:
		self.velocity.y += self.gravity * delta
	
	move_and_slide()
	

func _input(_event: InputEvent):
	pass
