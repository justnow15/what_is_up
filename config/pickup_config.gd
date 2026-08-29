extends Resource
class_name PickupConfig

enum PickupType{
	SPEED,
	RAPID,
	SPIRAL,
}
enum PlayerFormMode{
	NORMAL,
	ARMED,
}
enum ShotPattern{
	NORMAL,
	SPIRAL,
}
@export_group("基础信息")
@export var pickup_type:PickupType=PickupType.SPEED
@export var display_name:String="移速道具"
@export_range(0.0,1000.0,0.1,"or_great")var drop_weight:float=1.0
@export_group("buff effect")
@export_group("show resource")
@export var icon_texture:Texture2D
@export_range(0.0,120.0,0.1,"or_greater") var duration: float=5.0
@export_range(0.1,5.0,0.05,"or_greater") var move_speed_multiplier: float=1.0
@export_range(0.1,5.0,0.05,"or_greater") var fire_rate_multiplier: float=1.0


@export_group("形态和弹幕")
@export var player_form_mode:PlayerFormMode=PlayerFormMode.NORMAL
@export var shot_pattern: ShotPattern=ShotPattern.NORMAL
