# res://Script/World/Component/EquipmentComponent.gd
extends Node
class_name EquipmentComponent

# --- 核心职责 ---
# 1. 管理角色身上所有可用于储物的“容器”实体。
# 2. 提供统一的API来查询、添加、移除这些容器中的物品实体。

# --- 内部状态 ---
# 存储了所有已注册的、拥有ContainerComponent的实体引用。
var container_entities: Array[Entity] = []

# --- 容器管理API ---

func register_container(container_entity: Entity):
	"""
	注册一个新的储物容器。
	在WorldBuilder构建实体时，或在运行时装备/卸下背包时调用。
	"""
	if not is_instance_valid(container_entity) or not container_entity.has_component("ContainerComponent"):
		printerr("EquipmentComponent: Attempted to register an invalid or non-container entity.")
		return
	
	if not container_entity in container_entities:
		container_entities.append(container_entity)
		print("EquipmentComponent: Registered container '", container_entity.entity_name, "'.")

func unregister_container(container_entity: Entity):
	"""
	注销一个储物容器。
	"""
	if container_entity in container_entities:
		container_entities.erase(container_entity)
		print("EquipmentComponent: Unregistered container '", container_entity.entity_name, "'.")

# --- 统一库存查询API (核心) ---

func find_item_entities_for_recipe(inputs: Dictionary) -> Array[Entity]:
	"""
	(这是核心函数)
	接收一个配方输入, e.g., {"apple": 2, "wood_stick": 1}
	扫描所有已注册的容器，凑齐并返回一个包含所需实体引用的数组。
	如果材料足够，返回 [apple_entity_01, apple_entity_03, wood_stick_entity_05]。
	如果材料不足，返回一个空数组 []。
	
	注意：这个实现是“贪婪”的，它会从第一个容器开始找，直到找齐。
	"""
	var found_entities: Array[Entity] = []
	var required_items = inputs.duplicate(true) # 创建一个副本，因为我们会修改它

	for container_entity in container_entities:
		var container_comp = container_entity.get_component("ContainerComponent")
		if not is_instance_valid(container_comp): continue

		# 遍历容器内的所有物品ID
		for item_id in container_comp.get_all_item_ids():
			# 提前检查是否已找齐所有物品
			var all_found = true
			for key in required_items:
				if required_items[key] > 0:
					all_found = false
					break
			if all_found: break

			var item_entity = WorldManager.get_entity_by_id(item_id)
			if not is_instance_valid(item_entity): continue
			
			var item_template_id = item_entity.template_id
			
			if required_items.has(item_template_id) and required_items[item_template_id] > 0:
				found_entities.append(item_entity)
				required_items[item_template_id] -= 1
		
		# 再次检查，如果找齐了就不用再检查其他容器了
		var all_found_after_container = true
		for key in required_items:
			if required_items[key] > 0:
				all_found_after_container = false
				break
		if all_found_after_container: break

	# 最终检查是否所有物品都找齐了
	for key in required_items:
		if required_items[key] > 0:
			print("EquipmentComponent: Failed to find all required items. Missing ", required_items[key], " of '", key, "'.")
			return [] # 材料不足，返回空数组

	return found_entities

func add_entity_to_first_available_container(entity_to_add: Entity):
	"""
	遍历所有容器，找到第一个有足够空间的，把实体加进去。
	(简化版：暂时不检查空间，直接加到第一个容器里)
	"""
	if container_entities.is_empty():
		printerr("EquipmentComponent: No containers registered to add item to.")
		entity_to_add.queue_free() # 没有地方放，直接销毁，避免物品悬空
		return

	var first_container = container_entities[0]
	var container_comp = first_container.get_component("ContainerComponent")
	
	# ContainerComponent 需要一个 add_item 的方法
	if container_comp.has_method("add_item_entity"):
		container_comp.add_item_entity(entity_to_add)
	else:
		# 备用方案：直接加为子节点 (这要求ContainerComponent能处理)
		print("EquipmentComponent: Container '", first_container.entity_name, "' is missing 'add_item_entity' method. Adding as child.")
		first_container.add_child(entity_to_add)

func count_item(item_template_id: String) -> int:
	"""
	遍历所有容器，计算指定模板ID的物品总数。
	"""
	var count = 0
	for container_entity in container_entities:
		var container_comp = container_entity.get_component("ContainerComponent")
		if not is_instance_valid(container_comp): continue
		
		for item_id in container_comp.get_all_item_ids():
			var item_entity = WorldManager.get_entity_by_id(item_id)
			if is_instance_valid(item_entity) and item_entity.template_id == item_template_id:
				count += 1
	return count 