extends Node

# 用于创建实体的统一工厂
# 职责：
# - 从 DataManager 读取模板
# - new Entity，设置 template_id/entity_id/name
# - 为实体挂载各组件，并调用组件的 initialize_from_data（若存在）
# - 返回未注册、未放置的实体
#
# 假设存在：IdGenerator.next_id(template_id)
# 用意：运行时生成唯一ID；必要性：避免运行期创建时发生ID冲突

static func create(template_id: String, instance_id: String = "") -> Entity:
	# 1. 从DataManager获取模板数据
	var template_data = DataManager.get_entity_template(template_id)
	if template_data.is_empty():
		printerr("EntityFactory: Failed to create entity. Template '", template_id, "' not found.")
		return null

	# 2. 创建基础Entity节点
	var new_entity = Entity.new()
	new_entity.template_id = template_id
	# 优先使用传入的实例ID（读档时），否则保持为空，调用侧可在注册前赋值
	if not instance_id.is_empty():
		new_entity.entity_id = instance_id
	else:
		# 假设存在：IdGenerator.next_id(template_id)
		# 用意：为运行时创建生成唯一ID；必要性：避免与已有ID冲突
		# 这里不直接调用，保留为空由调用侧决定；如需默认行为，可在此调用生成
		pass
	new_entity.entity_name = template_data.get("name", "Unnamed Entity")

	# 3. 遍历并挂载组件
	var components_data = template_data.get("components", {})
	for component_name in components_data:
		var component_data = components_data[component_name]
		var component_script_path = "res://Script/World/Component/" + component_name + ".gd"
		var script = load(component_script_path)
		if not script:
			printerr("EntityFactory: Failed to load script for component '", component_name, "' at path '", component_script_path, "'.")
			continue
		var component_instance = script.new()
		if component_instance.has_method("initialize_from_data"):
			component_instance.initialize_from_data(component_data)
		new_entity.add_component(component_instance, component_name)

	print("EntityFactory: Created entity '", new_entity.entity_name, "' from template '", template_id, "'.")
	return new_entity 
