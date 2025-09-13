# res://Script/World/Component/ContainerComponent.gd
extends Node
class_name ContainerComponent

# --- 核心数据结构 ---
# "slots"字典管理不同的储物分区。
# 每个slot的"items"列表现在存储的是实体的 instance_id (String)。
var slots: Dictionary = {}

# --- 初始化 ---
func initialize_from_data(component_data: Dictionary):
	if not component_data.has("slots"):
		printerr("ContainerComponent: Template data is missing 'slots' dictionary.")
		return
	
	var slots_data = component_data.get("slots", {})
	for slot_id in slots_data:
		var slot_template = slots_data[slot_id]
		slots[slot_id] = {
			"config": {
				"capacity_volume": slot_template.get("capacity_volume", 999.0),
				"capacity_count": slot_template.get("capacity_count", 999),
				"accepted_tags": slot_template.get("accepted_tags", [])
			},
			"items": [] # 运行时存储实体ID的地方
		}
	print("ContainerComponent initialized with slots: ", slots.keys())

# --- 核心API ---

func add_entity(item_entity: Entity, target_slot_id: String = "") -> bool:
	"""
	向容器中添加一个物品实体。
	此函数现在只负责将实体的ID存入列表。
	"""
	if not is_instance_valid(item_entity): return false

	var slot_to_add_to = _find_first_available_slot_for(item_entity)
	if not target_slot_id.is_empty():
		slot_to_add_to = slots.get(target_slot_id)

	if slot_to_add_to == null:
		print("ContainerComponent: No suitable slot found for '", item_entity.entity_name, "'.")
		return false
	
	slot_to_add_to.items.append(item_entity.entity_id)
	print("ContainerComponent: Added entity ID '", item_entity.entity_id, "' to slot '", target_slot_id if not target_slot_id.is_empty() else "auto", "'.")
	return true

func remove_entity_by_id(item_id: String) -> bool:
	"""
	从容器的所有槽位中移除一个指定的物品ID。
	"""
	for slot_id in slots:
		var slot = slots[slot_id]
		if item_id in slot.items:
			slot.items.erase(item_id)
			print("ContainerComponent: Removed ID '", item_id, "' from slot '", slot_id, "'.")
			return true
	
	printerr("ContainerComponent: Failed to remove ID '", item_id, "'. Not found in any slot.")
	return false

func can_accept_entity(item_entity: Entity) -> bool:
	"""
	检查是否有任何一个槽位可以接收指定的物品实体。
	"""
	return _find_first_available_slot_for(item_entity) != null

func get_all_item_ids() -> Array[String]:
	"""
	遍历所有槽位，返回一个包含所有物品ID的统一列表。
	"""
	var all_ids: Array[String] = []
	for slot_id in slots:
		all_ids.append_array(slots[slot_id].items)
	return all_ids
	
# --- 私有辅助函数 ---
func _find_first_available_slot_for(item_entity: Entity):
	for slot_id in slots:
		var slot = slots[slot_id]
		var config = slot.config

		# 1. 检查数量限制
		if slot.items.size() >= config.capacity_count:
			continue

		# 2. 检查标签限制
		var required_tags = config.accepted_tags
		if not required_tags.is_empty():
			var has_all_tags = true
			for tag in required_tags:
				if not item_entity.has_tag(tag):
					has_all_tags = false
					break
			if not has_all_tags:
				continue
		
		# (TODO) 3. 检查体积限制
		
		# 找到合适的槽位！
		return slot
		
	return null

