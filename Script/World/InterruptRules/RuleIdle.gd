# res://rules/rule_idle.gd
extends InterruptRule

func _check_condition(agent: Entity) -> Dictionary:
    # 从agent获取其TaskComponent
    var task_comp = agent.get_component("TaskComponent")
    
    # 如果没有TaskComponent，或者其分配的任务ID列表为空，则视为空闲
    if not task_comp or task_comp.assigned_task_ids.is_empty():
        return {"interrupt": true, "reason": "处于空闲状态"}
    
    else:
        return {"interrupt": false}