# res://Script/WorldExecutor.gd
# AutoLoad
#
# --- 核心职责 (Core Responsibilities) ---
# 1. 原子效果执行者 (Atomic Effect Executor):
#    - 提供一个单一的入口函数 `execute(effect_data, context)`。
#    - 负责执行游戏中所有具体的、不可分割的状态变更，我们称之为“效果(Effect)”。
#    - 例如: 修改实体属性、创建/销毁实体、添加/移除状态等。
#
# 2. "写"操作的唯一入口 (Single Entry for "Writes"):
#    - 游戏世界中任何系统（如InteractionEngine, AI）想要修改世界状态，
#      都必须通过调用本节点的 `execute` 方法来完成。
#    - 这确保了所有状态变更都是可追踪、可预测且遵循统一规则的。
#
# --- 设计原则 ---
# - "怎么做"而非"为什么做": Executor不关心一个效果为何被触发，它只负责精确地执行
#   `effect_data` 中描述的操作。决策逻辑（“为什么”）由InteractionEngine等其他系统处理。
# - 无状态: Executor本身不存储任何持久化的世界状态，它是一个纯粹的服务提供者。

extends Node

# --- 主入口函数 ---
# 这是所有效果执行的唯一入口点
# context 字典包含了执行该效果所需的所有相关实体引用
# e.g., { "agent": bob_entity, "target": anvil_entity, "source": recipe_data }
func execute(effect_data: Dictionary, context: Dictionary):
	var effect_type = effect_data.get("effect")
	if effect_type == null:
		printerr("WorldExecutor: Effect data is missing 'effect' type.")
		return

	# 使用match语句来分派到具体的执行函数
	match effect_type:
		"ModifyProperty":#修改属性
			_execute_modify_property(effect_data, context)
		"CreateEntity":#创建实体
			_execute_create_entity(effect_data, context)
		"DestroyEntity":#销毁实体
			_execute_destroy_entity(effect_data, context)
		"TransferEntity": # 转移实体
			_execute_transfer_entity(effect_data, context)
		"AddEffect":#添加效果
			_execute_add_effect(effect_data, context)
		"RemoveEffect":#移除效果
			_execute_remove_effect(effect_data, context)
		"FinishTask":
			_execute_finish_task(effect_data, context)
		"ConsumeInputs": # 新增：专门用于消耗配方输入的效果
			_execute_consume_inputs(effect_data, context)
		_:
			printerr("WorldExecutor: Unknown effect type '", effect_type, "'")


func _execute_modify_property(data: Dictionary, context: Dictionary):
	# 1. 确定目标实体
	var target_entity = context.get(data.get("target")) # "agent" -> bob_entity
	if not is_instance_valid(target_entity): return

	# 2. 找到目标组件
	var component_name = data.get("component")
	var component = target_entity.get_component(component_name)
	if not component: return

	# 3. 修改属性
	var property_name = data.get("property")
	var change_value = data.get("change")
	
	# 使用 set/get，因为我们不知道具体属性名，这是动态的
	var current_value = component.get(property_name)
	component.set(property_name, current_value + change_value)
	
	print("Effect: Modified '", property_name, "' on '", target_entity.entity_name, "' by ", change_value)


func _execute_create_entity(data: Dictionary, context: Dictionary):
	var template_id = data.get("template")
	var destination_data = data.get("destination")

	if template_id == null or destination_data == null:
		printerr("WorldExecutor: CreateEntity effect is missing 'template' or 'destination' data.")
		return

	# 1. 创建实体 (但尚未放置)
	# TODO: WorldManager.create_entity 仍需实现
	var new_entity = EntityFactory.create(template_id)
	# 运行期：如果工厂未设置 entity_id，这里生成唯一ID并赋值
	if new_entity != null and (new_entity.entity_id == null or new_entity.entity_id == ""):
		# 假设存在：IdGenerator.next_id(template_id)
		# 用意：确保运行时创建实体ID唯一；必要性：避免与现有实体ID冲突
		# 这里暂以时间戳+随机数作为占位策略，建议改为正式的 IdGenerator
		var unique_id = template_id + "_" + str(Time.get_ticks_msec())
		new_entity.entity_id = unique_id
	if not is_instance_valid(new_entity):
		printerr("WorldExecutor: Failed to create entity from template '", template_id, "'.")
		return

	# 2. 解析目标容器并放置实体
	var dest_type = destination_data.get("type")
	var dest_target_key = destination_data.get("target")
	var target_container_entity = null # 这是目标实体，它可能是一个容器
	var target_location_node = null  # 这是实体最终要放置的地点

	match dest_type:
		"container":
			target_container_entity = context.get(dest_target_key)
			if not is_instance_valid(target_container_entity):
				printerr("WorldExecutor: Destination entity '", dest_target_key, "' is not valid.")
				target_container_entity = null # 确保无效时不被使用
			
		"location":
			# TODO: Entity需要一个标准方法来获取其所在的Location节点
			var agent = context.get("agent")
			if is_instance_valid(agent) and agent.has_method("get_location"):
				target_location_node = agent.get_location()
			else:
				printerr("WorldExecutor: Could not determine agent's location to create entity.")

		_:
			printerr("WorldExecutor: Unknown CreateEntity destination type '", dest_type, "'.")

	# 3. 将实体添加到目标容器，并实现备用方案
	if is_instance_valid(target_container_entity):
		var container_comp = target_container_entity.get_component("ContainerComponent")
		if is_instance_valid(container_comp) and container_comp.has_method("add_entity"):
			var success = container_comp.add_entity(new_entity)
			if success:
				print("Effect: Created '", new_entity.entity_name, "' inside '", target_container_entity.entity_name, "'.")
				return # 成功，结束函数

		# --- 备用方案 ---
		print("WorldExecutor: Failed to add entity to target container '", target_container_entity.entity_name, "'. Attempting fallback to location.")
		if target_container_entity.has_method("get_location"):
			target_location_node = target_container_entity.get_location()

	if is_instance_valid(target_location_node) and target_location_node.has_method("add_entity"):
		target_location_node.add_entity(new_entity)
		print("Effect: Created '", new_entity.entity_name, "' at location '", target_location_node.name, "'.")
	else:
		# 如果连备用方案都失败了，必须销毁实体
		printerr("WorldExecutor: Fallback failed. Could not find a valid location for the new entity. It will be destroyed.")
		new_entity.queue_free()

func _execute_destroy_entity(data: Dictionary, context: Dictionary):
	var target_key = data.get("target", "target")
	var entity_to_destroy = context.get(target_key)
	
	if not is_instance_valid(entity_to_destroy): return

	print("Effect: Destroying '", entity_to_destroy.entity_name, "' (", entity_to_destroy.entity_id, ")")

	# --- 递归销毁逻辑 ---
	if entity_to_destroy.has_component("ContainerComponent"):
		var container_comp = entity_to_destroy.get_component("ContainerComponent")
		var item_ids = container_comp.get_all_item_ids()
		print(" > Found container with ", item_ids.size(), " items inside. Destroying them recursively.")
		for item_id in item_ids:
			var item_entity = WorldManager.get_entity_by_id(item_id)
			if is_instance_valid(item_entity):
				# 为每个子物品创建一个新的销毁效果和上下文
				var sub_effect_data = {"effect": "DestroyEntity", "target": "entity_to_destroy"}
				var sub_context = {"entity_to_destroy": item_entity}
				execute(sub_effect_data, sub_context)

	# 从WorldManager注销并释放节点
	WorldManager.unregister_entity(entity_to_destroy.entity_id)
	entity_to_destroy.queue_free()

func _execute_transfer_entity(data: Dictionary, context: Dictionary):
	# 1. 解析指令 (现在都是ID)
	var entity_id = context.get(data.get("entity_id"))
	var source_id = context.get(data.get("source_id"))
	var destination_id = context.get(data.get("destination_id"))

	var entity_to_move = WorldManager.get_entity_by_id(entity_id)
	var source_node = WorldManager.get_container_node_by_id(source_id) # 需要在WorldManager实现
	var destination_node = WorldManager.get_container_node_by_id(destination_id)

	# --- 2. 预检阶段 ---
	if not is_instance_valid(entity_to_move): return
	if source_node == null or destination_node == null: return

	# 检查目标是否能接收
	if not destination_node.can_accept_entity(entity_to_move):
		printerr("TransferEntity: Destination '", destination_id, "' cannot accept the entity.")
		return

	# --- 3. 执行阶段 ---
	if not source_node.remove_entity_by_id(entity_id):
		printerr("TransferEntity: Failed to remove entity from source '", source_id, "'. Aborting.")
		return
		
	if not destination_node.add_entity(entity_to_move):
		printerr("TransferEntity: CRITICAL - Failed to add entity to destination. Attempting to return to source.")
		source_node.add_entity(entity_to_move) # 放回原处
		return

	print("Effect: Transferred '", entity_id, "' from '", source_id, "' to '", destination_id, "'.")

func _execute_add_effect(data: Dictionary, context: Dictionary):
	var target_entity = context.get(data.get("target"))
	var status_id = data.get("status_id")
	
	if is_instance_valid(target_entity):
		var condition_manager = target_entity.get_component("EffectComponent")
		if condition_manager:
			condition_manager.add_condition(status_id)
			print("Effect: Added status '", status_id, "' to '", target_entity.entity_name, "'")

func _execute_remove_effect(data: Dictionary, context: Dictionary):
	var target_entity = context.get(data.get("target"))
	var status_id = data.get("status_id")
	if is_instance_valid(target_entity):
		var condition_manager = target_entity.get_component("EffectComponent")
		if condition_manager:
			condition_manager.remove_condition(status_id)
			print("Effect: Removed status '", status_id, "' from '", target_entity.entity_name, "'")

func _execute_consume_inputs(data: Dictionary, context: Dictionary):
	"""
	从上下文中获取由InteractionEngine找到的待消耗实体列表，并销毁它们。
	"""
	var entities_to_destroy = context.get("entities_for_consumption", [])
	if entities_to_destroy.is_empty():
		print("WorldExecutor: ConsumeInputs effect called, but no entities were provided for consumption.")
		return
		
	print("WorldExecutor: Consuming ", entities_to_destroy.size(), " entities as recipe input.")
	for entity in entities_to_destroy:
		if is_instance_valid(entity):
			entity.queue_free()

func _execute_finish_task(data: Dictionary, context: Dictionary):
	var task = context.get("task") as Task
	var recipe = context.get("recipe") as Dictionary
	if not is_instance_valid(task): return

	var completion_effects = recipe.get("completion_effects", [])
	for effect_data in completion_effects:
		execute(effect_data, context)

	var target_entity = WorldManager.get_entity_by_id(task.target_entity_id)
	if is_instance_valid(target_entity) and target_entity.has_component("TaskComponent"):
		target_entity.get_component("TaskComponent").remove_task(task.task_id)
		
	WorldManager.unregister_task(task.task_id)