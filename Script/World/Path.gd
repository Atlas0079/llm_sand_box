# Script/World/Path.gd
extends Resource
class_name Path

@export var path_name: String = "一条小径"
@export var target_location_id: String # 目标Location的ID
@export var travel_time: int = 10
@export var description: String = ""
@export var conditions: Dictionary = {}

func _init(p_name: String = "", p_target_location: String = "", p_travel_time: int = 0, p_description: String = "", p_conditions: Dictionary = {}):
    self.path_name = p_name
    self.target_location_id = p_target_location
    self.travel_time = p_travel_time
    self.description = p_description
    self.conditions = p_conditions 