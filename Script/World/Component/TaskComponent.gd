# res://entities/components/task_component.gd
extends Node
class_name TaskComponent

# 存储所有附加在此实体上的任务
# key: task_id, value: Task Resource object
var tasks: Dictionary = {}

# --- 公共API ---

func add_task(task: Task):
	if not tasks.has(task.task_id):
		tasks[task.task_id] = task

func remove_task(task_id: String):
	if tasks.has(task_id):
		tasks.erase(task_id)

func get_task(task_id: String) -> Task:
	return tasks.get(task_id, null)

func get_all_tasks() -> Array[Task]:
	return tasks.values()

func get_available_tasks() -> Array[Task]:
	# 返回所有未被分配给任何Agent的任务
	var available = []
	for task in tasks.values():
		# 仅依赖Task内的ID引用判断（assigned_agent_ids 为空表示未分配）
		if task.assigned_agent_ids.is_empty():
			available.append(task)
	return available
