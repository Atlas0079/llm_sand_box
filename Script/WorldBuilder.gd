# Script/WorldBuilder.gd
# --- 核心职责 (Core Responsibilities) ---
# 1. 世界总建筑师 (World Architect):
#    - 负责在游戏启动或读档时，根据一个“世界蓝图”文件 (World.json) 来构建或恢复整个游戏世界。
#
# 2. 一次性构建 (One-shot Construction):
#    - WorldBuilder 是一个一次性的工具。它在世界初始化时运行一次，将静态的数据转换为
#      一个“活的”、可运行的场景（即填充好WorldManager中的数据），然后它的主要工作就完成了。

extends Node

# 构建世界的入口函数
func build_world_from_save_data():
	print("--- WorldBuilder: Starting to build world from save data ---")
	
	# 1. 加载世界蓝图 (World.json)
	var world_data = _load_json("res://Data/World.json")
	if world_data.is_empty():
		printerr("WorldBuilder: Failed to load World.json. Cannot build world.")
		return
		
	# 2. 初始化世界状态
	var world_state = world_data.get("world_state", {})
	WorldManager.game_time.total_ticks = world_state.get("current_tick", 0)
	print("WorldBuilder: Game time set to tick ", WorldManager.game_time.total_ticks)
	
	# --- 先注册地点（若存在） ---
	var location_id_to_node: Dictionary = {}
	for loc_data in world_data.get("locations", []):
		var loc_id: String = loc_data.get("location_id", "")
		if loc_id.is_empty():
			continue
		# 创建地点节点并注册到 WorldManager
		var loc_node := Location.new()

		loc_node.initialize_from_data(loc_id, loc_data)
		WorldManager.register_location(loc_node)
		location_id_to_node[loc_id] = loc_node
	
	# --- 创建并注册实体，同时记录快照 ---
	var all_entities_map = {}
	var all_snapshots_map = {}

	for loc_data in world_data.get("locations", []):
		var loc_id: String = loc_data.get("location_id", "")
		var loc_node = location_id_to_node.get(loc_id, null)
		
		for entity_snapshot in loc_data.get("entities", []):
			var template_id = entity_snapshot.get("template_id")
			var instance_id = entity_snapshot.get("instance_id")
			if not template_id or not instance_id:
				continue
			var new_entity = EntityFactory.create(template_id, instance_id)
			if is_instance_valid(new_entity):
				# 立刻注册，保证后续ID读侧可用
				WorldManager.register_entity(new_entity)
				all_entities_map[instance_id] = new_entity
				all_snapshots_map[instance_id] = entity_snapshot
				# 默认放置到其所在地点（若无更具体父容器）
				if is_instance_valid(loc_node) and loc_node.has_method("add_entity"):
					loc_node.add_entity(new_entity)
	
	# --- 第二遍：建立父容器/地点关系（若提供 parent_container 覆盖默认放置） ---
	for instance_id in all_entities_map:
		var entity = all_entities_map[instance_id]
		var snapshot: Dictionary = all_snapshots_map[instance_id]
		var parent_id = snapshot.get("parent_container", "")
		if parent_id.is_empty():
			continue
		var parent_node = null
		if all_entities_map.has(parent_id):
			parent_node = all_entities_map[parent_id]
		elif WorldManager.get_location_by_id(parent_id):
			parent_node = WorldManager.get_location_by_id(parent_id)
		
		if not is_instance_valid(parent_node):
			printerr("WorldBuilder: Could not find parent container '", parent_id, "' for entity '", instance_id, "'.")
			continue
		
		# 如果父节点是地点：直接放置到地点
		if parent_node is Location and parent_node.has_method("add_entity"):
			parent_node.add_entity(entity)
			continue
		
		# 如果父节点是实体容器：交由容器组件处理
		if parent_node.has_method("get_component"):
			var container_comp = parent_node.get_component("ContainerComponent")
			if is_instance_valid(container_comp) and container_comp.has_method("add_entity"):
				container_comp.add_entity(entity)
				continue
		
		printerr("WorldBuilder: Parent node for '", instance_id, "' does not support entity placement.")
	
	# --- 组件状态覆盖：優先交給組件自處理 ---
	for instance_id in all_entities_map:
		var entity = all_entities_map[instance_id]
		var overrides = all_snapshots_map[instance_id].get("component_overrides", {})
		for comp_name in overrides:
			var comp = entity.get_component(comp_name)
			if not is_instance_valid(comp):
				continue
			var comp_data = overrides[comp_name]
			# 假设存在：apply_snapshot / initialize_from_data
			# 用意：讓組件自行處理其初始化/覆蓋細節；必要性：避免WorldBuilder耦合組件內部結構
			if comp.has_method("apply_snapshot"):
				comp.apply_snapshot(comp_data)
			elif comp.has_method("initialize_from_data"):
				comp.initialize_from_data(comp_data)
			else:
				# 回退：逐属性赋值（簡單屬性）
				for prop_name in comp_data:
					if comp.has_method("set"):
						comp.set(prop_name, comp_data[prop_name])
	
	print("--- WorldBuilder: World build process complete. ---")

# 加载JSON文件的辅助函数
func _load_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("Failed to open JSON file at path: ", path)
		return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if data else {} 