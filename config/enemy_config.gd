extends Resource
class_name  EnemyConfig

enum EnemyType{
	BASIC,
	SHELLED,
	FAST_SMALL,
	BOMBER,
}
@export_group("basic information")
@export var enemy_type:EnemyType=EnemyType.BASIC
@export var display_name:String="基础敌人"

@export_group("基础数值")
@export_range(1,999,1,"or_greater")var max_heath:int=3
@export_range(0.0,1000.0,1.0,"or_greater")var move_speed:float=60.0
@export_range(1.0,256.0,0.5,"or_greater")var collision_radius:float=8

@export_group("动画资源")
@export var enemy_frames:SpriteFrames
@export var move_animation_name:StringName=&"move"
@export var death_aniamtion_name:StringName=&"death"
@export var explosion_animation_name:StringName=&"explode"


@export_group("死亡效果")
@export var explode_on_death:bool=false
@export_range(0,999,1,"or_greater")var explosion_damage:int =0
@export_range(0.0,512.0,1.0,"or_greater")var explosion_radius:float=0

@export_group("掉落")
@export_range(0.0,1.0,0.01)var pickup_drop_chance:float=0.3
@export var pickup_drop_configs:Array[PickupConfig]=[
	preload("res://config/pickup_rapid.tres"),
	preload("res://config/pickup_speed.tres"),
	preload("res://config/pickup_spiral.tres"),
]
