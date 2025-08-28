# res://entities/components/perception_component.gd
extends Node
class_name PerceptionComponent

# --- 引用 ---
var parent_entity: Entity

# 新增的初始化方法
func set_parent_entity(p_entity: Entity):
	self.parent_entity = p_entity

# ==============================================================================
# 核心公共API (供AIControlComponent调用)
# ==============================================================================

# --- 新增：上下文提供函数 ---
func get_environment_context() -> Dictionary:
    """
    收集所有与外部环境相关的上下文，并返回一个适合prompt填充的字典。
    """
    var context = {}
    var perception_data = get_current_perception() # 调用已有的感知函数
    
    var loc_data = perception_data.get("location", {})
    var entities_data = perception_data.get("entities", [])
    
    # [当前情境] - 地点
    context["current_location_name"] = loc_data.get("name", "未知地点")
    context["location_atmosphere_description"] = loc_data.get("description", "")
    var connections = loc_data.get("connections", {})
    context["location_connections_summary"] = ", ".join(connections.values().map(func(c): return c.get("path_name", "一条路"))) if not connections.is_empty() else "无"
    
    # [当前情境] - 实体与任务
    var agent_names = []
    var entity_infos = []
    var own_status_summary = "无 (空闲)"
    for entity_perception in entities_data:
        # 分离出关于自己的信息 (父实体是这个感知组件的所有者)
        if entity_perception.get("id") == parent_entity.entity_id:
            own_status_summary = entity_perception.get("status_summary", "无 (空闲)")
            continue
            
        # 将其他实体信息格式化为文本
        var info_str = entity_perception.get("name", "一个实体")
        if entity_perception.has("status_summary"):
            info_str += " (%s)" % entity_perception.get("status_summary")
        
        # 通过检查实体是否有AgentComponent来判断是否为agent
        var perceived_entity = WorldManager.get_entity_by_id(entity_perception.get("id"))
        if is_instance_valid(perceived_entity) and perceived_entity.has_component("AgentComponent"):
            agent_names.append(info_str)
        else:
            entity_infos.append(info_str)
            
    context["agents_in_location_summary"] = ", ".join(agent_names) if not agent_names.is_empty() else "无"
    context["entities_in_location_summary"] = ", ".join(entity_infos) if not entity_infos.is_empty() else "无"
    context["current_task_description"] = own_status_summary
    
    return context

# --- V1: 简单、无过滤的感知 ---
func get_current_perception() -> Dictionary:
    """
    生成一个关于当前环境的、完整的、无过滤的感知报告。
    这是为V1设计的“全知”模式。
    """
    var perception_data = {}
    
    # 1. 感知当前地点
    var current_location = _get_current_location()
    if not is_instance_valid(current_location):
        perception_data["location"] = {"error": "Currently in limbo (no location)."}
        return perception_data

    perception_data["location"] = {
        "id": current_location.location_id,
        "name": current_location.location_name,
        "description": current_location.description,
        "connections": _format_connections(current_location)
    }

    # 2. 感知地点内的所有实体
    perception_data["entities"] = _perceive_entities_in(current_location)
    
    return perception_data


# --- V2: 带有过滤的感知 (未来扩展的接口) ---
func get_filtered_perception() -> Dictionary:
    """
    这是为未来设计的、更真实的感知接口。
    它会考虑视线、距离、注意力、潜行等因素。
    """
    # 现在的V1版本，我们只是简单地调用V1的函数
    # 当未来实现V2时，我们将在这里加入过滤逻辑
    return get_current_perception()


# ==============================================================================
# 私有辅助函数 (信息采集与格式化)
# ==============================================================================

func _get_current_location() -> Location:
    # 向上遍历场景树，找到自己所在的Location节点
    var node = get_parent()
    while is_instance_valid(node):
        if node is Location:
            return node
        node = node.get_parent()
    return null

func _format_connections(location: Location) -> Dictionary:
    # 将Location的连接数据格式化成LLM更容易理解的格式
    var formatted = {}
    var paths = location.get_all_paths()
    for path_id in paths:
        var path_data = paths[path_id]
        formatted[path_data.target_location] = {
            "path_name": path_data.path_name,
            "travel_time": path_data.travel_time
        }
    return formatted

func _perceive_entities_in(location: Location) -> Array[Dictionary]:
    var perceived_entities = []
    
    # 遍历地点内的所有实体
    for entity in location.entities_in_location.values():
        # V1: 无过滤，把自己也加进去，让AI知道自己的存在
        # if entity == parent_entity:
        #     continue

        # 为每个实体创建一个描述性的数据包
        var entity_data = {
            "id": entity.entity_id,
            "name": entity.entity_name,
            "tags": entity.get_all_tags() if entity.has_method("get_all_tags") else [],
            "status_summary": _get_entity_status_summary(entity)
        }
        
        # 如果是工作站，列出其上的可用任务
        var task_comp = entity.get_component("TaskComponent")
        if is_instance_valid(task_comp):
            # 仅输出可用任务的计数，避免暴露任务对象细节
            entity_data["available_task_count"] = task_comp.get_available_tasks().size()
            
        # 如果是容器，并且是透明的，描述一下里面的东西
        var container_comp = entity.get_component("ContainerComponent")
        if is_instance_valid(container_comp) and container_comp.is_transparent:
            entity_data["contains"] = _format_container_contents(container_comp)

        perceived_entities.append(entity_data)
        
    return perceived_entities

func _get_entity_status_summary(entity: Entity) -> String:
    # 生成一个关于实体当前状态的简短描述
    # 例如： "正在制作一把剑", "正在睡觉", "看起来很累"
    var creature_comp = entity.get_component("CreatureComponent")
    if is_instance_valid(creature_comp):
        # 优先从TaskComponent获取正在执行的任务
        var task_comp = entity.get_component("TaskComponent")
        if task_comp and not task_comp.assigned_task_ids.is_empty():
            # 仅基于是否分配生成摘要，避免跨对象强引用
            return "正在执行任务"
        
        # 如果没有任务，再根据状态效果判断
        var effect_comp = entity.get_component("EffectComponent")
        if effect_comp:
            # 示例：可以添加一个从状态效果推断描述的逻辑
            if effect_comp.active_conditions.has("Tired"): # 假设有“疲劳”状态
                return "看起来很疲劳"
            
        return "看起来很正常"
    
    return "是一个物品"


func _format_tasks(tasks: Array[Task]) -> Array[Dictionary]:
    var formatted = []
    for task in tasks:
        formatted.append({
            "task_id": task.task_id,
            "task_type": task.task_type,
            "progress": str(task.progress) + "/" + str(task.required_progress)
        })
    return formatted

func _format_container_contents(container: ContainerComponent) -> Array[String]:
    var contents = []
    for entity in container.contained_entities.values():
        contents.append(entity.entity_name)
    return contents