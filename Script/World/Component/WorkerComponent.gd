# res://Script/World/Component/WorkerComponent.gd
extends Node
class_name WorkerComponent

var current_task_id: String = ""

# --- 公共API ---
func assign_task(p_task_id: String):
	current_task_id = p_task_id

func stop_task():
	current_task_id = ""

func has_task() -> bool:
	return not current_task_id.is_empty()

# --- 核心更新逻辑 ---
# 这个函数由拥有此组件的Entity在它的update_per_tick中调用
func update_per_tick(_ticks_passed: int):
	if not has_task():
		return

	# 1. 获取任务实例和它的配方
	var agent = get_owner() as Entity
	var task = _get_task_instance()
	if not is_instance_valid(task):
		printerr("WorkerComponent: Task with ID '", current_task_id, "' not found. Stopping work.")
		stop_task()
		return
	
	# 注释掉对未实现方法的调用，以便MVP能运行
	# TODO: DataManager 需要实现 get_task_recipe 方法
	# var task_recipe = DataManager.get_task_recipe(task.task_type)
	# if task_recipe.is_empty():
	#     printerr("WorkerComponent: No recipe found for task type '", task.task_type, "'.")
	#     stop_task()
	#     return
	
	# MVP阶段：使用一个硬编码的配方进行测试
	var task_recipe = {
		"base_progress_per_tick": 1.0,
		"progress_contributors": [
			# {"component": "CreatureComponent", "property": "strength", "multiplier": 0.2}
		],
		"tick_effects": [
            
			# {"effect": "ModifyProperty", "target": "agent", "component": "SkillComponent", "property": "mining_experience", "change": 0.5}
		],
		"completion_effects": []
	}

	# 2. 根据配方计算本轮tick的进度
	var progress_this_tick = task_recipe.get("base_progress_per_tick", 1.0)
	
	var contributors = task_recipe.get("progress_contributors", [])
	for contributor in contributors:
		var component = agent.get_component(contributor.get("component"))
		if is_instance_valid(component):
			var prop_value = component.get(contributor.get("property", 0.0))
			progress_this_tick += prop_value * contributor.get("multiplier", 1.0)

	# 3. 更新任务进度
	task.progress += progress_this_tick
	
	# 4. 执行每tick的效果 (如增加经验)
	var tick_effects = task_recipe.get("tick_effects", [])
	var context = {"agent": agent, "task": task} # 构建效果执行的上下文
	for effect_data in tick_effects:
		WorldExecutor.execute(effect_data, context)
		
	# 5. 检查任务是否完成
	if task.is_complete():
		print("WorkerComponent: Task '", task.task_type, "' completed by '", agent.entity_name, "'.")
		
		# 将所有清理和收尾工作打包成一个 "FinishTask" 效果，交给 WorldExecutor
		context["recipe"] = task_recipe
		WorldExecutor.execute({"effect": "FinishTask"}, context)
			
		# Worker 自己的工作完成，停止工作
		stop_task()

# --- 私有辅助函数 ---
func _get_task_instance() -> Task:
	var task_instance = WorldManager.get_task_by_id(current_task_id)
	if not is_instance_valid(task_instance):
		return null
	
	# Task资源现在知道它的目标实体ID
	var target_entity = WorldManager.get_entity_by_id(task_instance.target_entity_id)
	if is_instance_valid(target_entity) and target_entity.has_component("TaskComponent"):
		# 从目标实体的TaskComponent中获取对任务的引用
		return target_entity.get_component("TaskComponent").get_task(current_task_id)
		
	return null
