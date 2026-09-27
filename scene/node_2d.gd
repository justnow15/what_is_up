extends Node2D

const RESULT_TITLE_WIN:="你赢了"
const RESULT_TILTLE_LOSE:="你输了"
const RESULT_MESSAGE_WIN:="你成功坚持到了最后"
const  RESULT_MESSAGE_LOSE:="玩家生命值已经归零"
const RESULT_OK_BUTTON_TEXT:="结束游戏"

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
@export_group("关卡ui")
@export_range(1.0,3600.0,1.0,"or_greater") var stage_duration:float=60.0



@onready var player:Player=$Player
@onready var enemy_container:Node2D=$EnemyContainer
@onready var enemy_spawn_points_root:Node2D=$EenmySpawnPoints
@onready var enemy_spawn_timer:Timer=$EnemySpawnTimer
@onready var life_count_label:Label=$HUDlayer/LifeCountLabel
@onready var timer_bar:Sprite2D=$HUDlayer/TimerBar
@onready var result_dialog:AcceptDialog=$AcceptDialog
var random_generator:RandomNumberGenerator=RandomNumberGenerator.new()
var enemy_spawn_points:Array[Marker2D]=[]
var available_enemy_configs:Array[EnemyConfig]=[]
var stage_time_left:float=0.0
var time_bar_full_scale_x:float=1.0
var time_bar_left_edge_x:float=0.0
var time_bar_left_texture_width:float=0.0
var is_result_display:bool=false
var arena_center:Vector2=Vector2.ZERO

func _ready() -> void:
	random_generator.randomize()
	_configure_result_dialog()
	_setup_hub()
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
	if is_result_display:
		return
	
	_update_stage_timer(delta)
	_update_spawn_interval()
	_update_hub()
	_check_game_result()

func _configure_result_dialog()->void:
	result_dialog.process_mode=Node.PROCESS_MODE_ALWAYS
	result_dialog.dialog_close_on_escape=false
	result_dialog.ok_button_text=RESULT_OK_BUTTON_TEXT
	result_dialog.hide()
	if not result_dialog.confirmed.is_connected(_on_result_dialog_exit_requested):
		result_dialog.confirmed.connect(_on_result_dialog_exit_requested)
	if not result_dialog.close_requested.is_connected(_on_result_dialog_exit_requested):
		result_dialog.close_requested.connect(_on_result_dialog_exit_requested)
	if not result_dialog.canceled.is_connected(_on_result_dialog_exit_requested):
		result_dialog.canceled.connect(_on_result_dialog_exit_requested)

func _setup_hub()->void:
	stage_time_left=maxf(stage_duration,0.0)
	time_bar_full_scale_x=timer_bar.scale.x
	if timer_bar.texture!=null:
		time_bar_left_texture_width=timer_bar.texture.get_width()
	if timer_bar.centered:
		time_bar_left_edge_x=timer_bar.position.x-(time_bar_left_texture_width*time_bar_full_scale_x*0.5)
	else:
		time_bar_left_edge_x=timer_bar.position.x
	_update_hub()

func _update_stage_timer(delta:float)->void:
	if stage_time_left<=0.0:
		stage_time_left=0.0
		return
	stage_time_left=maxf(stage_time_left-delta,0.0)
func _update_hub()->void:
	_update_life_count_label()
	_update_time_bar()
func _update_life_count_label()->void:
	life_count_label.text="x %d" %_get_player_current_health()

func _update_time_bar()->void:
	var fill_ratio:=0.0
	if stage_duration>0.0:
		fill_ratio=clampf(stage_time_left/stage_duration,0.0,1.0)
	timer_bar.scale.x=time_bar_full_scale_x*fill_ratio
	if not timer_bar.centered:
		timer_bar.position.x=time_bar_left_edge_x
		return
	var current_width:=time_bar_left_texture_width*timer_bar.scale.x
	timer_bar.position.x=time_bar_left_edge_x+(current_width*0.5)

func _show_result_dialog(result_title:String,result_message:String)->void:
	if is_result_display:
		return
	is_result_display=true
	result_dialog.title=result_title
	result_dialog.dialog_text=result_message
	_stop_world()
	result_dialog.popup_centered()
	var ok_button:=result_dialog.get_ok_button()
	if ok_button!=null:
		ok_button.grab_focus()
func _check_game_result()->void:
	if stage_time_left<=0.0:
		_show_result_dialog(RESULT_TITLE_WIN,RESULT_MESSAGE_WIN)
		return
	if _get_player_current_health()<=0:
		_show_result_dialog(RESULT_TILTLE_LOSE,RESULT_MESSAGE_LOSE)
func _stop_world()->void:
	enemy_spawn_timer.stop()
	Engine.time_scale=0.0
	get_tree().paused=true
func _on_result_dialog_exit_requested()->void:
	get_tree().quit()
	
func _get_player_current_health()->int:
	if not is_instance_valid(player):
		return 0
	return player.get_current_health()
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
	if stage_duration<=0.0:
		return end_interval
	var difficulty_ratio:=1.0-clampf(stage_time_left/stage_duration,0.0,1.0)
	return lerpf(start_interval,end_interval,difficulty_ratio)
		
		
		
		
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
