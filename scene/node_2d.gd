extends Node2D


# Called when the node enters the scene tree for the first time.
@export_group("刷怪资源")
@export var enemy_scene:PackedScene=preload("res://scene/Enemy.tscn")
@export var enemy_configs:Array[EnemyConfig]=[
	preload("res://config/enemy_basic.tres"),
	preload("res://config/enemy_bomber.tres"),
	preload("res://config/enemy_fast.tres"),
	preload("res://config/enemy_shelled.tres"),
	
]
@export_group("刷怪节奏")
@export_range(0,100,1,"or_greater") var initial_spawn_count:int =1
@export_range(1,20,1,"or_greater") var spawn_count_per_tick:int =1
@export_range(0.1,60.0,0.1,"or_greater") var spawn_interval:float=1.5
@export_range(0.1,60.0,0.1,"or_greater") var min_spawn_interval:float=0.6
@export_range(1,200,1,"or_greater") var max_alive_enemies:int =12
@export_range(1.0,3600.0,1.0,"or_greater") var spawn_acceleration_duration:float=60.0


@onready var player:Player=$Player
@onready var enemy_container:Node2D=$EnemyContainer
@onready var enemy_spawn_points_root:Node2D=$EenmySpawnPoints
@onready var enemy_spawn_timer:Timer=$EnemySpawnTimer
var random_generator:RandomNumberGenerator=RandomNumberGenerator.new()
var enemy_spawn_points:Array[Marker2D]=[]
var available_enemy_configs:Array[EnemyConfig]=[]
var game_time_elapsed:float=0.0
var arena_center:Vector2=Vector2.ZERO

func _ready() -> void:
	random_generator.randomize()
	_calc_arena_center()
	_collect_enemy_spawn_points()
	_collect_enemy_configs()
	_configure_enemy_spawn_timer()
	_spawn_initial_enemies()
	_start_enemy_spawn_timer()

func _calc_arena_center()->void:
	var tilemap_layer:=get_node_or_null("TileMapLayer") as TileMapLayer
	if tilemap_layer==null:
		arena_center=Vector2(136,136)
		return
	arena_center=tilemap_layer.map_to_local(tilemap_layer.get_used_rect().get_center())

func _process(delta: float) -> void:
	game_time_elapsed+=delta
	_update_spawn_interval()


func _collect_enemy_spawn_points()->void:
	enemy_spawn_points.clear()
	for child in enemy_spawn_points_root.get_children():
		var spawn_point:=child as Marker2D
		if spawn_point!=null:
			enemy_spawn_points.append(spawn_point)
	if enemy_spawn_points.is_empty():
		push_warning("no available points")
			
func _collect_enemy_configs()->void:
	available_enemy_configs.clear()
	for config_entry in enemy_configs:
		if config_entry!=null:
			available_enemy_configs.append(config_entry)
	if available_enemy_configs.is_empty():
		push_warning("no available resources")
func _configure_enemy_spawn_timer()->void:
	enemy_spawn_timer.one_shot=false
	enemy_spawn_timer.wait_time=_get_current_spawn_interval()
	if not enemy_spawn_timer.timeout.is_connected(_on_enemy_spawn_timer_timeout):
		enemy_spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)
		
		
func _update_spawn_interval()->void:
	var current_interval:=_get_current_spawn_interval()
	if  is_equal_approx(enemy_spawn_timer.wait_time,current_interval):
		return
	enemy_spawn_timer.wait_time=current_interval
	if enemy_spawn_timer.is_stopped():
		return
	if enemy_spawn_timer.time_left<=current_interval:
		return
		
	enemy_spawn_timer.start(current_interval)
func _get_current_spawn_interval()->float:
	var start_interval:=maxf(spawn_interval,0.1)
	var end_interval:=minf(maxf(min_spawn_interval,0.1),start_interval)
	if spawn_acceleration_duration<+0.0:
		return end_interval
	var difficulty_radio:=clampf(game_time_elapsed/spawn_acceleration_duration,0.0,1.0)
	return lerpf(start_interval,end_interval,difficulty_radio)
		
		
		
		
func _spawn_initial_enemies()->void:
	for _spawn_index in range(initial_spawn_count):
		if not _try_spawn_enemy():
			break
			
func _start_enemy_spawn_timer()->void:
	if not _is_spawn_system_ready():
		return
	enemy_spawn_timer.start()
func _on_enemy_spawn_timer_timeout()->void:
	for _spawn_index in range(spawn_count_per_tick):
		if not _try_spawn_enemy():
			break

func _try_spawn_enemy()->bool:
	if not _is_spawn_system_ready():
		return false
	if _get_alive_enemy_count()>=max_alive_enemies:
		return false
	var spawn_point:=_pick_spawn_point()
	if spawn_point ==null:
		return false
	var enemy_config:=_pick_enemy_config()
	if enemy_config==null:
		return false
	var enemy_instance:=enemy_scene.instantiate() as Enemy
	if enemy_instance==null:
		push_warning("initial failed")
		return false
	enemy_container.add_child(enemy_instance)
	enemy_instance.global_position=spawn_point.global_position
	enemy_instance.setup(enemy_config,player)
	if not _resolve_spawn_overlap(enemy_instance):
		enemy_instance.queue_free()
		return false
	return true

func _resolve_spawn_overlap(enemy_instance:Enemy)->bool:
	var space_state:=get_world_2d().direct_space_state
	if space_state==null:
		return true
	var shape:=enemy_instance.collision_shape.shape
	if shape==null:
		return true
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=shape
	query.collision_mask=enemy_instance.collision_mask
	query.collide_with_bodies=true
	query.collide_with_areas=false
	query.exclude=[enemy_instance.get_rid()]
	for _attempt in range(12):
		query.transform=enemy_instance.global_transform
		if space_state.intersect_shape(query).is_empty():
			return true
		enemy_instance.global_position=enemy_instance.global_position.move_toward(arena_center,8.0)
	enemy_instance.global_position=arena_center
	query.transform=enemy_instance.global_transform
	return space_state.intersect_shape(query).is_empty()

func _is_spawn_system_ready()->bool:
	return(
		player!=null
		and enemy_scene!=null
		and enemy_container!=null
		and not enemy_spawn_points.is_empty()
		and not available_enemy_configs.is_empty()
	)
func _pick_spawn_point()->Marker2D:
	if enemy_spawn_points.is_empty():
		return null
	var random_index:=random_generator.randi_range(0,enemy_spawn_points.size()-1)
	return enemy_spawn_points[random_index]
func _pick_enemy_config()->EnemyConfig:
	if available_enemy_configs.is_empty():
		return null
	var random_index:=random_generator.randi_range(0,available_enemy_configs.size()-1)
	return available_enemy_configs[random_index]
func _get_alive_enemy_count()->int:
	var alive_enemy_count:=0
	for child in enemy_container.get_children():
		if child is Enemy:
			alive_enemy_count+=1
	return alive_enemy_count
#func _spawn_initial_enemies()
#func _start_enemy_spawn_timer()
#func _update_spawn_interval()
