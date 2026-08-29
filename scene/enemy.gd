extends CharacterBody2D

class_name Enemy

const DEFAULT_BULLET_DAMAGE:=1
const BLINK_ENABLED_SHADER_PARAMETER:=&"blink_enabled"
const PICKUP_SCENE:=preload("res://scene/pickup.tscn")
const EXPLOSION_QUERY_MAX_RESULTS:=16
const DEATH_SEQUENCE_MAX_DURATION:=2.5

enum  DeathsequenthStage{
	NODE,
	DEATH,
	EXPLOSION,
}

@export var config:EnemyConfig
@export var touch_damage:float =1
@export var touch_damage_interval:float=0.5
@export var hurt_blink_duration:float=0.16
@onready var animated_sprite:AnimatedSprite2D=$AnimatedSprite2D
@onready var collision_shape:CollisionShape2D=$CollisionShape2D
@onready var touch_damage_area:Area2D=$TouckDamageArea
@onready var touch_damage_shape:CollisionShape2D=$TouckDamageArea/CollisionShape2D
@onready var explosion_area:Area2D=$ExplosionArea
@onready var explosion_shape:CollisionShape2D=$ExplosionArea/CollisionShape2D


var target_player:Player=null
var current_health:int=1
var is_dead:bool=false
var touch_damage_cooldown_left:float=0.0
var touched_player:Player=null
var hurt_blink_time_left:float=0.0
var death_sequence_stage:DeathsequenthStage=DeathsequenthStage.NODE
var death_animation_name_in_use:StringName=&""
var random_generator:RandomNumberGenerator=RandomNumberGenerator.new()

func _ready() -> void:
	random_generator.randomize()
	touch_damage_area.body_entered.connect(_on_touch_damage_area_body_entered)
	touch_damage_area.body_exited.connect(_on_touch_damage_area_body_exited)
	touch_damage_area.area_entered.connect(_on_touch_damage_area_area_entered)
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	_apply_config()


func setup(enemy_config:EnemyConfig,player:Player)->void:
	config=enemy_config
	target_player=player
	_apply_config()

func apply_damage(amount:int)->bool:
	if is_dead:
		return false
	if amount<=0:
		return false
	current_health-=amount
	if current_health<=0:
		_die()
		return true
	_start_hurt_blink()
	return true



func _physics_process(delta: float) -> void:
	_update_hurt_blink(delta)
	_update_touch_damage(delta)
	if is_dead:
		velocity=Vector2.ZERO
		return
	if not is_instance_valid(target_player):
		velocity=Vector2.ZERO
		move_and_slide()
		return
	
	var move_direction:=global_position.direction_to(target_player.global_position)
	_update_facing(move_direction)
	velocity=move_direction*_get_move_speed()
	move_and_slide()
func _apply_config()->void:
	if config==null:
		return
	current_health=config.max_heath
	_apply_collision_radius(config.collision_radius)
	_apply_explosion_radius(config.explosion_radius)
	if config.enemy_frames!=null:
		animated_sprite.sprite_frames=config.enemy_frames
		if config.enemy_frames.has_animation(config.move_animation_name):
			animated_sprite.play(config.move_animation_name)
		else:
			push_warning("missing enemy move animation")
func _apply_collision_radius(radius:float)->void:
	var body_shape:=collision_shape.shape as CircleShape2D
	if body_shape!=null:
		body_shape.radius=radius
	var damage_shape:=touch_damage_shape.shape as CircleShape2D
	if damage_shape!=null:
		damage_shape.radius=radius


func _apply_explosion_radius(radius:float)->void:
	var explosion_circle_shape:=explosion_shape.shape as CircleShape2D
	if explosion_circle_shape!=null:
		explosion_circle_shape.radius=maxf(radius,0.0)

func _get_move_speed()->float:
	if config==null:
		return 0.0
		
	return config.move_speed

func _update_facing(move_direction:Vector2)->void:
	if is_zero_approx(move_direction.x):
		return
	animated_sprite.flip_h=move_direction.x<0.0


func _on_touch_damage_area_body_entered(body:Node2D)->void:
	if is_dead:
		return
	var player:=body as Player
	if player==null:
		return
	touched_player=player
	_try_deal_touch_damage()

func _on_touch_damage_area_body_exited(body:Node2D)->void:
	if body==touched_player:
		touched_player=null
		
		
		
		
func _on_touch_damage_area_area_entered(area:Area2D)->void:
	if is_dead:
		return
	var bullet:=area as Bullet
	if bullet==null:
		return
		
	var damaged:=apply_damage(DEFAULT_BULLET_DAMAGE)
	if damaged:
		bullet.queue_free()

func _update_touch_damage(delta:float)->void:
	if touch_damage_cooldown_left>0.0:
		touch_damage_cooldown_left=maxf(touch_damage_cooldown_left-delta,0.0)
		
	if touched_player==null:
		return
	if not is_instance_valid(touched_player):
		touched_player=null
		return
	if touch_damage_cooldown_left>0.0:
		return
	_try_deal_touch_damage()

func _try_deal_touch_damage():
	if touched_player==null:
		return
		
	touched_player.apply_damage(touch_damage)
	touch_damage_cooldown_left=touch_damage_interval


func _start_hurt_blink()->void:
	hurt_blink_time_left=hurt_blink_duration
	_set_hurt_blink_enabled(true)

func _update_hurt_blink(delta:float)->void:
	if hurt_blink_time_left<=0.0:
		return
		
	hurt_blink_time_left=maxf(hurt_blink_time_left-delta,0.0)
	if hurt_blink_time_left>0.0:
		return
	_set_hurt_blink_enabled(false)


func _set_hurt_blink_enabled(enabled:bool)->void:
	var sprite_material:=animated_sprite.material as ShaderMaterial
	if sprite_material!=null:
		sprite_material.set_shader_parameter(BLINK_ENABLED_SHADER_PARAMETER,enabled)

func _die()->void:
	if is_dead:
		return
	is_dead=true
	velocity=Vector2.ZERO
	touched_player=null
	hurt_blink_time_left=0.0
	_set_hurt_blink_enabled(false)
	collision_shape.set_deferred("disabled",true)
	touch_damage_shape.set_deferred("disabled",true)
	touch_damage_area.set_deferred("monitoring",true)
	touch_damage_area.set_deferred("monitorable",true)
	_try_drop_pickup()
	_start_death_sequence()
	# 兜底保险：即使动画结束信号意外没触发，也强制删除敌人，防止特效/尸体卡住
	var death_safety_timer:=get_tree().create_timer(DEATH_SEQUENCE_MAX_DURATION)
	death_safety_timer.timeout.connect(queue_free)
	
	
func _start_death_sequence()->void:
	if config==null:
		queue_free()
		return
	if _play_death_sequence_animation(config.death_aniamtion_name,DeathsequenthStage.DEATH):
		return
	_finish_after_death_animation()
	

func _finish_after_death_animation()->void:
	if _should_play_explosion_sequence():
		_start_explosion_sequence()
		return
	queue_free()
	
	
func _start_explosion_sequence()->void:
	if not _should_play_explosion_sequence():
		queue_free()
		return
	_try_apply_explosion_damage()
	if _play_death_sequence_animation(config.explosion_animation_name,DeathsequenthStage.EXPLOSION):
		return
	queue_free()


func _play_death_sequence_animation(animation_name:StringName,stage:DeathsequenthStage)->bool:
	death_sequence_stage=stage
	death_animation_name_in_use=animation_name
	if config==null:
		return false
	if config.enemy_frames==null:
		return false
	if not config.enemy_frames.has_animation(animation_name):
		return false
	animated_sprite.play(animation_name)
	return true
	
func _should_play_explosion_sequence()->bool:
	return config!=null and config.explode_on_death


func _try_apply_explosion_damage()->void:
	if config==null:
		return
	if not config.explode_on_death:
		return
	if config.explosion_damage<=0 or config.explosion_radius<=0.0:
		return
	var space_state:=get_world_2d().direct_space_state
	if space_state==null:
		return
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=explosion_shape.shape
	query.transform=explosion_shape.global_transform
	query.collision_mask=explosion_area.collision_mask
	query.collide_with_bodies=true
	query.collide_with_areas=false
	query.exclude=[get_rid()]
	var  query_results:=space_state.intersect_shape(query,EXPLOSION_QUERY_MAX_RESULTS)
	if query_results.is_empty():
		return
	var damage_collider_ids:Dictionary={}
	for result in query_results:
		var collider:=result.get("collider") as Node
		if collider==null:
			continue
		if collider==null:
			continue
		var collider_id:=collider.get_instance_id()
		if damage_collider_ids.has(collider_id):
			continue
		damage_collider_ids[collider_id]=true
		var hit_player:=collider as Player
		if hit_player!=null:
			hit_player.apply_damage(config.explosion_damage)
			continue
		var hit_enemy:=collider as Enemy
		if hit_enemy!=null:
			hit_enemy.apply_damage(config.explosion_damage)


func _try_drop_pickup()->void:
	if config==null:
		return
	if config.pickup_drop_configs.is_empty():
		return
	if random_generator.randf()>config.pickup_drop_chance:
		return
	var pickup_config:=_pick_pickup_drop_config()
	if pickup_config==null:
		return
	call_deferred("_spawn_dropped_pickup",pickup_config,global_position)

func _pick_pickup_drop_config()->PickupConfig:
	if config==null:
		return null
	var available_pickup_configs:Array[PickupConfig]=[]
	var total_weight:=0.0
	for pickup_config in config.pickup_drop_configs:
		if pickup_config==null:
			continue
		if pickup_config.drop_weight<=0.0:
			continue
		available_pickup_configs.append(pickup_config)
		total_weight+=pickup_config.drop_weight
	if available_pickup_configs.is_empty():
		return null
	if total_weight<=0.0:
		return null
	var target_weight:=random_generator.randf_range(0.0,total_weight)
	var accumulated_weight:=0.0
	for available_config in available_pickup_configs:
		accumulated_weight+=available_config.drop_weight
		if target_weight<=accumulated_weight:
			return available_config
	return available_pickup_configs.back()
	


func _spawn_dropped_pickup(pickup_config:PickupConfig,spawn_position:Vector2)->void:
	var drop_parent:=get_parent()
	if drop_parent==null:
		return
	var pickup_instance:=PICKUP_SCENE.instantiate() as Pickup
	if pickup_instance==null:
		return
	pickup_instance.config=pickup_config
	drop_parent.add_child(pickup_instance)
	pickup_instance.global_position=spawn_position
func _on_animated_sprite_animation_finished()->void:
	if not is_dead:
		return
	if death_animation_name_in_use==&"":
		return
	match death_sequence_stage:
		DeathsequenthStage.DEATH:
			_finish_after_death_animation()
		DeathsequenthStage.EXPLOSION:
			queue_free()
		_:
			queue_free()
