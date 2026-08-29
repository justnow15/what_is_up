extends CharacterBody2D
class_name Player

signal died

const BULLET_SCENE:=preload("res://scene/Bullet.tscn")
const ARMED_ANIMATION_PREFIX:=&"armed"
const DEFAULT_MOVE_SPEED_MULTIPLIER:=1.0
const DEFAULT_FIRE_RATE_MULTIPLIER:=1.0
const  SPIRAL_PHASE_STEP:=PI/12
const NORMAL_ANIMATION_PREFIX:=&"normal_"

@export var fire_interval:float=0.18
@export var bullet_spawn_distance:float=18.0
@export var move_speed: float=120.0

@onready var body_sprite:AnimatedSprite2D=$BodySprite
@onready var armed_effect_sprite:AnimatedSprite2D=$ArmedEffectSprite
@onready var shooting_timer:Timer=$ShootingTimer

var facing_suffix:StringName=&"right"
var current_move_speed_multiplier:float=DEFAULT_MOVE_SPEED_MULTIPLIER
var rapid_fire_rate_multiplier:float=DEFAULT_FIRE_RATE_MULTIPLIER
var form_fire_rate_multiplier:float=DEFAULT_FIRE_RATE_MULTIPLIER
var current_shot_pattern:int =PickupConfig.ShotPattern.NORMAL
var speed_buff_time_left:float=0.0
var form_buff_time_left:float=0.0
var rapid_buff_time_left:float=0.0
var spiral_phase:float=0.0
var current_from_mode:int=PickupConfig.PlayerFormMode.NORMAL
@export var max_health:float=100.0
@export var invulnerable_time:float=1.0
var health:float=0.0
var is_invulnerable:bool=false
var invulnerable_time_left:float=0.0

func _physics_process(delta: float) -> void:
	_update_pickup_effects(delta)
	_update_invulnerability(delta)
	var move_input:=Input.get_vector("move_left","move_right","move_up","move_down")
	var shoot_input:=Input.get_vector("shoot_left","shoot_right","shoot_up","shoot_down")
	
	velocity=move_input*move_speed*current_move_speed_multiplier
	move_and_slide()
	if current_shot_pattern==PickupConfig.ShotPattern.SPIRAL:
		_try_auto_spiral_shoot()
	elif shoot_input!=Vector2.ZERO:
		_try_shoot(shoot_input)
	
	_update_facing(move_input,shoot_input)
	_update_animation()
	_update_armed_effect()

func apply_pickup(config:PickupConfig)->bool:
	if config==null:
		return false
	var applied:=false
	var should_refresh_shooting_timer:=false
	var buff_duration:=maxf(config.duration,0.0)
	var has_form_override:=(
		config.player_form_mode!=PickupConfig.PlayerFormMode.NORMAL
		or config.shot_pattern!=PickupConfig.ShotPattern.NORMAL
	)
	var has_fire_rate_override:=not is_equal_approx(
		config.fire_rate_multiplier,
		DEFAULT_FIRE_RATE_MULTIPLIER
	)
	if not is_equal_approx(config.move_speed_multiplier,DEFAULT_MOVE_SPEED_MULTIPLIER):
		current_move_speed_multiplier=config.move_speed_multiplier
		speed_buff_time_left=buff_duration
		applied=true
	if has_fire_rate_override and not has_form_override:
		rapid_fire_rate_multiplier=config.fire_rate_multiplier
		rapid_buff_time_left=buff_duration
		should_refresh_shooting_timer=true
		applied=true
	if has_form_override:
		current_move_speed_multiplier=config.move_speed_multiplier
		current_shot_pattern=config.shot_pattern
		form_fire_rate_multiplier=(
			config.fire_rate_multiplier if has_fire_rate_override else DEFAULT_FIRE_RATE_MULTIPLIER
			
		)
		form_buff_time_left=buff_duration
		spiral_phase=0.0
		should_refresh_shooting_timer=true
		applied=true
	if should_refresh_shooting_timer:
		_refresh_shooting_timer_wait_time()
	return applied

func apply_damage(amount:float)->void:
	if amount<=0.0 or is_invulnerable or health<=0.0:
		return
	health=maxf(health-amount,0.0)
	if health<=0.0:
		_die()
		return
	_start_invulnerability()

func _start_invulnerability()->void:
	is_invulnerable=true
	invulnerable_time_left=invulnerable_time

func _update_invulnerability(delta:float)->void:
	if not is_invulnerable:
		return
	invulnerable_time_left=maxf(invulnerable_time_left-delta,0.0)
	body_sprite.visible=not body_sprite.visible
	if invulnerable_time_left<=0.0:
		is_invulnerable=false
		body_sprite.visible=true

func _die()->void:
	died.emit()
	queue_free()
	
func _get_effective_move_interval()->float:
	return maxf(fire_interval/ _get_effective_fire_rate_multiplier(),0.01)

func _refresh_shooting_timer_wait_time()->void:
	var new_interval:=_get_effective_fire_interval()
	shooting_timer.wait_time=new_interval
	if shooting_timer.is_stopped():
		return
	if shooting_timer.time_left<=new_interval:
		return
	shooting_timer.start(new_interval)


func _update_pickup_effects(delta:float)->void:
	if speed_buff_time_left>0.0:
		speed_buff_time_left=maxf(speed_buff_time_left-delta,0.0)
		if speed_buff_time_left<=0.0:
			current_move_speed_multiplier=DEFAULT_MOVE_SPEED_MULTIPLIER
	if rapid_buff_time_left>0.0:
		rapid_buff_time_left=maxf(rapid_buff_time_left-delta,0.0)
		if rapid_buff_time_left<=0.0:
			rapid_fire_rate_multiplier=DEFAULT_FIRE_RATE_MULTIPLIER
			_refresh_shooting_timer_wait_time()
	if form_buff_time_left>0.0:
		form_buff_time_left=maxf(form_buff_time_left-delta,0.0)
		if form_buff_time_left<=0.0:
			current_move_speed_multiplier=DEFAULT_MOVE_SPEED_MULTIPLIER
			current_shot_pattern=PickupConfig.ShotPattern.NORMAL
			form_fire_rate_multiplier=DEFAULT_FIRE_RATE_MULTIPLIER
			spiral_phase=0.0
			_refresh_shooting_timer_wait_time()
func _vector_to_facing_suffix(dir: Vector2)->StringName:
	if abs(dir.x)>abs(dir.y):
		return &"right" if dir.x>0 else &"left"
	return &"down" if dir.y>0 else &"up"

func _update_animation() -> void:
	var animation_name:=StringName("%s%s"%[NORMAL_ANIMATION_PREFIX,facing_suffix])
	
	if not body_sprite.sprite_frames.has_animation(animation_name):
		push_warning("missing animation name")
		return
	if body_sprite.animation!=animation_name:
		body_sprite.play(animation_name)
	

func _ready() -> void:
	health=max_health
	shooting_timer.one_shot=true
	shooting_timer.wait_time=_get_effective_fire_interval()
	_update_animation()
	_update_armed_effect()

func _try_shoot(shoot_input:Vector2)->void:
	if not shooting_timer.is_stopped():
		return
	var shoot_direction:=shoot_input.normalized()
	var has_spawned_bullet:=_fire_bullets(shoot_direction)
	if has_spawned_bullet:
		shooting_timer.start(_get_effective_fire_interval())

func _fire_bullets(base_direction:Vector2)->bool:
	if current_shot_pattern==PickupConfig.ShotPattern.SPIRAL:
		var has_spawn_forward_bullet:=_spawn_bullets(base_direction)
		var has_spawn_backward_bullet:=_spawn_bullets(base_direction.rotated(PI))
		spiral_phase=wrapf(spiral_phase+SPIRAL_PHASE_STEP,0.0,TAU)
		return has_spawn_backward_bullet or has_spawn_forward_bullet
	return _spawn_bullets(base_direction)

func _spawn_bullets(shoot_direction:Vector2)->bool:
	var bullet:=BULLET_SCENE.instantiate() as Bullet
	if bullet == null:
		return false
	bullet.top_level=true
	bullet.setup(shoot_direction)
	
	var spawn_parent:=get_tree().current_scene
	if spawn_parent==null:
		return false
		
		
	spawn_parent.add_child(bullet)
	bullet.global_position=global_position+shoot_direction*bullet_spawn_distance
	return true

func _try_auto_spiral_shoot()->void:
	if not shooting_timer.is_stopped():
		return
	
	var spiral_direction:=Vector2.RIGHT.rotated(spiral_phase)
	var has_spawned_bullet:=_fire_bullets(spiral_direction)
	if has_spawned_bullet:
		shooting_timer.start(_get_effective_fire_interval())


func _get_effective_fire_interval()->float:
	return maxf(fire_interval/_get_effective_fire_rate_multiplier(),0.01)

func _get_effective_fire_rate_multiplier()->float:
	if _has_active_form_override():
		return maxf(form_fire_rate_multiplier,0.01)
	return maxf(rapid_fire_rate_multiplier,0.01)

func _has_active_form_override()->bool:
	return(
		current_from_mode!=PickupConfig.PlayerFormMode.NORMAL or
		current_shot_pattern!=PickupConfig.ShotPattern.NORMAL
	)

func _get_animation_prefix()->StringName:
	if current_from_mode==PickupConfig.PlayerFormMode.ARMED:
		return ARMED_ANIMATION_PREFIX
	return NORMAL_ANIMATION_PREFIX

func _update_armed_effect()->void:
	var is_armed:=current_from_mode==PickupConfig.PlayerFormMode.ARMED
	if not is_armed:
		if armed_effect_sprite.visible:
			armed_effect_sprite.visible=false
		if armed_effect_sprite.is_playing():
			armed_effect_sprite.stop()
		return
	if not armed_effect_sprite.visible: 
		armed_effect_sprite.visible=true
	if armed_effect_sprite.is_playing():
		return
	if armed_effect_sprite.sprite_frames==null:
		return
	if armed_effect_sprite.sprite_frames.has_animation(&"default"):
		armed_effect_sprite.play(&"default")
		
	 
func _update_facing(move_input:Vector2,shoot_input:Vector2)->void:
	if current_shot_pattern==PickupConfig.ShotPattern.SPIRAL:
		if move_input!=Vector2.ZERO:
			facing_suffix=_vector_to_facing_suffix(move_input)
		return
	if shoot_input!=Vector2.ZERO:
		facing_suffix=_vector_to_facing_suffix(shoot_input)
	elif move_input!=Vector2.ZERO:
		facing_suffix=_vector_to_facing_suffix(move_input)
