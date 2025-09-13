# res://world/location.gd
extends Node2D
class_name Location

# --- 核心属性 ---
var location_id: String
var location_name: String
var description: String

# --- 实体管理 ---
# 只存储当前在此地点的实体ID
var entities_in_location: Array[String] = []

# --- 连接数据 ---
var connections: Dictionary = {}


func _ready():
	pass

# --- 初始化方法 ---
func initialize_from_data(p_location_id: String, template_data: Dictionary):
	self.location_id = p_location_id
	self.location_name = template_data.get("location_name", "Unnamed Location")
	self.description = template_data.get("description", "")
	print("Location '", location_name, "' initialized.")

func add_connection(path_id: String, target_location_id: String):
	if not connections.has(path_id):
		connections[path_id] = target_location_id

# --- 公共API (容器接口) ---
func add_entity(entity_to_add: Entity) -> bool:
	if not is_instance_valid(entity_to_add):
		printerr("Location: Attempted to add an invalid entity to '", self.location_name, "'.")
		return false
	
	if not entity_to_add.entity_id in entities_in_location:
		entities_in_location.append(entity_to_add.entity_id)
		# 在纯ID模式下，Location节点不再是实体的父节点
		# add_child(entity_to_add) 
		print("Location: Added entity ID '", entity_to_add.entity_id, "' to '", self.location_name, "'.")
		return true
	else:
		printerr("Location: Entity ID '", entity_to_add.entity_id, "' already exists in '", self.location_name, "'.")
		return false

func remove_entity_by_id(entity_id: String) -> bool:
	if entity_id in entities_in_location:
		entities_in_location.erase(entity_id)
		print("Location: Removed entity ID '", entity_id, "' from '", self.location_name, "'.")
		return true
	
	printerr("Location: Failed to remove ID '", entity_id, "'. Not found.")
	return false

func can_accept_entity(_entity: Entity) -> bool:
	return true

# --- 公共API (路径接口) ---
func get_path_to_target_location(target_location_id: String) -> Array[String]:
	var found_path_ids = []
	for path_id in connections:
		if connections[path_id] == target_location_id:
			found_path_ids.append(path_id)
	return found_path_ids

func get_all_path_ids() -> Array[String]:
	return connections.keys()
