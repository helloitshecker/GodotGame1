extends CharacterBody3D

@export var sensitivity := 0.0005
@export var controller_sensitivity := 0.08
@export var speed := 5.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var anim: AnimationPlayer = $AnimeGirl1_Final/AnimationPlayer

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		
		spring_arm.rotate_x(event.relative.y * sensitivity)
		
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-60), deg_to_rad(45))
	
	if event.is_action_pressed("open_menu"):
		get_tree().quit()

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	anim.play("Breathing Idle")

func _physics_process(delta: float) -> void:
	if !is_on_floor():
		velocity += get_gravity() * delta

	# Controller Look
	var look := Input.get_vector("look_left", "look_right", "look_down", "look_up")
	
	if (look.length() > 0.1):
		rotate_y(look.x * -controller_sensitivity) # Left Right
		spring_arm.rotate_x(look.y * -controller_sensitivity) # Up Down
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-60), deg_to_rad(45))

	# Moveent code

	var input := Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
	
	var forward : Vector3 = -camera.global_transform.basis.z
	var right : Vector3 = camera.global_transform.basis.x
	
	forward.y = 0
	right.y = 0
	
	forward = forward.normalized()
	right = right.normalized()
	
	var direction := (forward * input.y + right * input.x).normalized()
	
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		anim.play("Fast Run")
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		anim.play("Breathing Idle")
		
	move_and_slide()
