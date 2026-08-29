extends Area2D
class_name  Pickup

const BLINK_ENABLED_SHADE_PAPAMETER:=&"blink_enabled"
@export var config:PickupConfig
@export_range(0.0,10.0,0.1,"or_greater") var blink_before_expire:float=1.2

@onready var sprite:Sprite2D=$Sprite2D
@onready var lifetime_timer:Timer=$LifetimeTimer

var is_expiring: bool=false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	lifetime_timer.one_shot=true
	if lifetime_timer.wait_time>0.0:
		lifetime_timer.start()
	_set_blink_enabled(false)
	_apply_config_to_visual()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_expiring:
		return
	if lifetime_timer.is_stopped():
		return
	if lifetime_timer.time_left>blink_before_expire:
		return
	is_expiring=true
	_set_blink_enabled(true)
func _on_body_entered(body:Node2D):
	if config==null:
		return
	var player:=body as Player
	if player==null:
		return
	if player.apply_pickup(config):
		queue_free()
func _on_lifetime_timer_timeout():
	queue_free()

func _set_blink_enabled(enabled:bool):
	var sprite_material:=sprite.material as ShaderMaterial
	if sprite_material!=null:
		sprite_material.set_shader_parameter(BLINK_ENABLED_SHADE_PAPAMETER,enabled)
		
func _apply_config_to_visual():
	if config==null:
		push_warning("config is missing")
		return
	sprite.texture=config.icon_texture
