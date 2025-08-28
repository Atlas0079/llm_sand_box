# res://Script/WorldExecutor.gd

# AutoLoad

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
        "AddEffect":#添加效果
            _execute_add_effect(effect_data, context)
        "RemoveEffect":#移除效果
            _execute_remove_effect(effect_data, context)
        "FinishTask":
            _execute_finish_task(effect_data, context)
        #"AddExperience":#添加经验,现在不需要了，直接修改组件属性就好了
        #    _execute_add_experience(effect_data, context)
        # ... 未来可以添加更多效果类型 ...
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
    var destination_str = data.get("destination") # "target_inventory", "agent_location", etc.

    # 1. 创建实体
    # 这里我们假设WorldManager有一个通用的实体创建函数
    var new_entity = WorldManager.create_entity(template_id)
    if not new_entity: return

    # 2. 决定放置位置
    var agent = context.get("agent")
    var target = context.get("target")

    match destination_str:
        "agent_inventory":
            var inventory = agent.get_component("InventoryComponent")
            if inventory: inventory.add_item(new_entity)
        "target_inventory":
            var container = target.get_component("ContainerComponent")
            if container: container.add_item(new_entity)
        "agent_location":
            var location = agent.get_location() # 假设Entity有此方法
            if location: location.add_entity(new_entity)
            
    print("Effect: Created '", new_entity.entity_name, "' at '", destination_str, "'")

func _execute_destroy_entity(data: Dictionary, context: Dictionary):
    var target_key = data.get("target", "target") # 默认为"target"
    var entity_to_destroy = context.get(target_key)
    
    if is_instance_valid(entity_to_destroy):
        print("Effect: Destroying '", entity_to_destroy.entity_name, "'")
        # queue_free() 会安全地在当前帧结束时删除节点
        # 它会自动触发我们之前设计的 _cleanup_before_deletion 逻辑
        entity_to_destroy.queue_free()

func _execute_add_effect(data: Dictionary, context: Dictionary):
    var target_entity = context.get(data.get("target"))
    var status_id = data.get("status_id")
    
    if is_instance_valid(target_entity):
        var condition_manager = target_entity.get_component("EffectComponent")
        if condition_manager:
            # 将状态/特质添加到 EffectComponent
            # 注意：这里的 add_condition 是 EffectComponent 的接口
            condition_manager.add_condition(status_id)
            print("Effect: Added status '", status_id, "' to '", target_entity.entity_name, "'")

func _execute_remove_effect(data: Dictionary, context: Dictionary):
    var target_entity = context.get(data.get("target"))
    var status_id = data.get("status_id")
    if is_instance_valid(target_entity):
        var condition_manager = target_entity.get_component("EffectComponent")
        if condition_manager:
            # 从 EffectComponent 移除状态/特质
            condition_manager.remove_condition(status_id)
            print("Effect: Removed status '", status_id, "' from '", target_entity.entity_name, "'")

func _execute_finish_task(data: Dictionary, context: Dictionary):
    var task = context.get("task") as Task
    var recipe = context.get("recipe") as Dictionary
    if not is_instance_valid(task): return

    # 1. 执行配方中定义的 "完成效果"
    var completion_effects = recipe.get("completion_effects", [])
    for effect_data in completion_effects:
        # 注意：这里我们复用了传入的 context，因为执行这些子效果也需要 agent, task 等信息
        execute(effect_data, context)

    # 2. 从目标实体的 TaskComponent 中移除任务引用
    var target_entity = WorldManager.get_entity_by_id(task.target_entity_id)
    if is_instance_valid(target_entity) and target_entity.has_component("TaskComponent"):
        target_entity.get_component("TaskComponent").remove_task(task.task_id)
        
    # 3. 从 WorldManager 的全局任务列表中注销任务
    WorldManager.unregister_task(task.task_id)


#这个应该是直接修改组件属性就好了，不需要单独处理
#func _execute_add_experience(data: Dictionary, context: Dictionary):
#    pass