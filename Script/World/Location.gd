# res://world/location.gd
extends Node2D # 使用Node2D作为基类，因为它有位置信息，方便在地图上可视化
class_name Location

# --- 核心属性 ---
var location_id: String # e.g., "town_square"
var location_name: String # e.g., "小镇广场"
var description: String # 对地点的描述

# --- 实体管理 ---
# 存储当前在此地点的所有实体
var entities_in_location: Dictionary = {} # key: entity_id, value: Entity node

# --- 连接数据 ---
# 只存储路径ID，完整的Path资源由WorldManager管理
var connections: Dictionary = {} # key: path_id, value: target_location_id


func _ready():
    pass



# --- 初始化方法 ---
# 和Entity一样，Location也由数据驱动
func initialize_from_data(p_location_id: String, template_data: Dictionary):
    self.location_id = p_location_id
    self.location_name = template_data.get("name", "Unnamed Location")
    self.description = template_data.get("description", "")
    print("Location '", location_name, "' initialized.")

# 由 WorldBuilder 在创建后调用，注册连接
func add_connection(path_id: String, target_location_id: String):
    if not connections.has(path_id):
        connections[path_id] = target_location_id

# --- 公共API ---
func get_path_to_target_location(target_location_id: String) -> Array[String]:
    var found_path_ids = []
    for path_id in connections:
        if connections[path_id] == target_location_id:
            found_path_ids.append(path_id)
    return found_path_ids

func get_all_path_ids() -> Array[String]:
    return connections.keys()
