# res://tasks/task.gd
extends Resource
class_name Task

# --- 核心属性 ---
var task_id: String          # 任务的唯一实例ID
var task_type: String        
# e.g., "Crafting", "Moving", "Sleeping"
# TODO：全部的task种类

var action_type: String = "Action" # Action, Task
# action是一种特殊的task，它是瞬时完成的，没有进度，会被llm特殊理解。

var target_entity_id: String # 任务附着的实体ID

var progress: float = 0.0
var required_progress: float = 100.0

var multiple_entity: bool = false # 是否可以被多个实体执行
# 执行此任务的实体ID集合（仅保存ID，避免持有节点或名称）
var assigned_agent_ids: PackedStringArray = []

# 一个任务可以被多个Agent执行

var task_status: String = "Inactive" 
# "Inactive", "InProgress", "Paused", "Completed"
# 我现在在想要不要这个inactive和completed参数。

var parameters: Dictionary = {} # 任务的具体参数 (e.g., recipe_id)


func _init(p_task_type: String = "", p_target_entity_id: String = ""):
    self.task_id = "task_" + str(randi()) + "_" + str(Time.get_ticks_msec())
    self.task_type = p_task_type
    self.target_entity_id = p_target_entity_id

func is_complete() -> bool:
    return progress >= required_progress

func get_remaining_progress() -> float:
    return max(0, required_progress - progress)