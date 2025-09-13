# --- 职责说明 (TaskComponent) ---
# 组件定位：挂在“任务宿主”（如铁砧），管理附着式任务。
# 职责：
# 1) 任务集合管理：创建/持有/查询/筛选可领取任务（不跨实体）。
# 2) 生命周期（写侧建议）：在 add_task/remove_task 内调用 WorldManager.register_task/unregister_task，
#    保持组件内状态与全局索引一致（当前实现尚未注册，本注释说明建议与必要性）。
# 3) 读/写边界：对外提供只读查询；任何跨实体副作用与“任务完成”后的效果，
#    必须通过 WorldExecutor.execute(...) 进行，组件自身不直接修改其他实体。
# 协作：InteractionEngine 负责创建并附加任务；WorldManager 维护全局任务索引；
#       WorkerComponent 仅“领取/执行”任务，不在宿主上增删任务。
# 失败与幂等建议：重复添加同ID应拒绝并告警；移除不存在ID应安全返回；注册/注销需幂等。
# --------------------------------------------------------
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
