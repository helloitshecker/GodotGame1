extends CharacterBody3D

@export var sensitivity : float = 0.001
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var turn_speed: float = 2.0
@export var jump_velocity: float = 3.0
@export var stick_sensitivity: float = 3.0
@export var stick_deadzone: float = 0.15

@onready var spring_arm: SpringArm3D = $CameraPivot/Spring
@onready var anim: = $F_1/AnimationPlayer
@onready var camera := $CameraPivot/Spring/Camera3D
@onready var camera_pivot := $CameraPivot
@onready var mesh := $F_1
@onready var anim_tree := $F_1/AnimationTree
@onready var state_machine : AnimationNodeStateMachinePlayback = anim_tree["parameters/playback"]

const BLEND_PARAM := "parameters/Locomotion/blend_position"
const WALK_BLEND := 0.4
const RUN_BLEND := 1.0
const BLEND_SMOOTH := 10.0

var pitch : float = 0.0
var was_on_floor: bool = true

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	anim_tree.active = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		camera_pivot.rotate_y(-event.relative.x * sensitivity)
		pitch = clamp(pitch + -event.relative.y * sensitivity, deg_to_rad(-60), deg_to_rad(45))
		spring_arm.rotation.x = pitch

func _handle_gamepad_camera(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_forward", "look_backward")
	if look.length() > stick_deadzone:
		camera_pivot.rotate_y(-look.x * stick_sensitivity * delta)
		pitch = clamp(pitch + -look.y * stick_sensitivity * delta, deg_to_rad(-60), deg_to_rad(45))
		spring_arm.rotation.x = pitch

func _physics_process(delta: float) -> void:
	_handle_gamepad_camera(delta)
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Input.get_vector("move_right", "move_left", "move_backward", "move_forward")
	var cam_basis : Basis = camera_pivot.global_transform.basis
	var direction := cam_basis * Vector3(input_dir.x, 0, input_dir.y)
	direction.y = 0
	direction = direction.normalized()

	var sprinting := Input.is_action_pressed("sprint")
	var speed := run_speed if sprinting else walk_speed
	
	var target_blend := 0.0
	if direction.length() > 0.01:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		var target_yaw := atan2(direction.x, direction.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_yaw, turn_speed * delta)
		target_blend = RUN_BLEND if sprinting else WALK_BLEND
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		state_machine.travel("RunJump")
	
	move_and_slide()

	var grounded := is_on_floor()
	if grounded and not was_on_floor:
		state_machine.travel("Locomotion")
	was_on_floor = grounded
	
	if grounded:
		var current : float = anim_tree.get(BLEND_PARAM)
		anim_tree.set(BLEND_PARAM, lerp(current, target_blend, BLEND_SMOOTH * delta))
