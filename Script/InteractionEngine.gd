# res://world/interaction_engine.gd
extends Node
# --- 缓存的规则数据 ---
var recipe_db: Dictionary

func _ready():
    # 从DataManager加载所有交互的“配方”
    recipe_db = DataManager.get_all_recipes()
    print("InteractionEngine: Loaded ", recipe_db.size(), " interaction recipes.")

# ==============================================================================
# 主入口函数 (被AIControlComponent或PlayerControlComponent调用)
# ==============================================================================

# command_data 示例: {"verb": "Craft", "target_id": "anvil_01", "parameters": {"recipe_id": "iron_sword"}}
func process_command(agent: Entity, command_data: Dictionary) -> Dictionary:
    print("InteractionEngine: Processing command from '", agent.entity_name, "': ", command_data)
    
    # 1. 解析指令
    var verb = command_data.get("verb")
    var target_id = command_data.get("target_id")
    var target_entity = WorldManager.get_entity_by_id(target_id)
    # 创建一个贯穿整个流程的上下文
    var context = {"agent": agent, "target": target_entity}

    # 2. 找到匹配的配方
    var matched_recipe = _find_matching_recipe(verb, agent, target_entity, command_data.get("parameters", {}))
    
    if matched_recipe.is_empty():
        var error_msg = "No matching recipe found for this interaction."
        print("InteractionEngine: ", error_msg)
        return {"status": "failed", "reason": "NO_RECIPE", "message": error_msg}

    print("InteractionEngine: Matched recipe '", matched_recipe.id, "'")
    context["recipe"] = matched_recipe

    # 3. 验证并消耗输入 (材料等)
    if not _check_and_consume_inputs(agent, matched_recipe.get("inputs", {}), context):
        var error_msg = "Agent does not have the required materials."
        print("InteractionEngine: ", error_msg)
        return {"status": "failed", "reason": "MISSING_INPUTS", "message": error_msg}

    # 4. 处理交互过程 (瞬时 vs. 持续性)
    var process_data = matched_recipe.get("process", {})
    if process_data.get("required_progress", 0) == 0:
        # 瞬时交互
        return _handle_instant_interaction(context)
    else:
        # 持续性交互 (创建Task)
        return _handle_duration_interaction(context)


func _find_matching_recipe(verb: String, agent: Entity, target: Entity, params: Dictionary) -> Dictionary:
    for recipe_id in recipe_db:
        var recipe = recipe_db[recipe_id]
        
        # a. 动词匹配
        if recipe.get("verb") != verb:
            continue
            
        # b. 目标标签匹配
        var required_tags = recipe.get("target_tags", [])
        var all_tags_match = true
        for tag in required_tags:
            if not target.has_tag(tag):
                all_tags_match = false
                break
        if not all_tags_match:
            continue
            
        # c. 参数匹配 (例如，制作配方ID)
        if recipe.has("parameter_match"):
            var param_key = recipe.parameter_match.keys()[0]
            var param_value = recipe.parameter_match.values()[0]
            if params.get(param_key) != param_value:
                continue
        
        # 如果所有检查都通过，我们找到了！
        # 返回一个带ID的副本，方便调试
        var result_recipe = recipe.duplicate(true)
        result_recipe["id"] = recipe_id
        return result_recipe
        
    return {} # 没找到

#TODO：改为只检查输入，消耗物品由EffectExecutor处理
func _check_and_consume_inputs(agent: Entity, inputs: Dictionary, context: Dictionary) -> bool:
    if inputs.is_empty():
        return true # 不需要材料

    var equipment_comp = agent.get_component("EquipmentComponent")
    if not equipment_comp:
        print("InteractionEngine: Agent '", agent.entity_name, "' has no EquipmentComponent to find items in.")
        return false 

    var required_entities = equipment_comp.find_item_entities_for_recipe(inputs)
    
    if required_entities.is_empty():
        # find_item_entities_for_recipe 内部会打印找不到的错误信息
            return false # 材料不足

    # 关键：将找到的实体列表存入上下文，供WorldExecutor后续消耗
    context["entities_for_consumption"] = required_entities
    return true


func _handle_instant_interaction(context: Dictionary) -> Dictionary:
    print("InteractionEngine: Handling instant interaction.")
    
    var recipe = context.get("recipe")
    var outputs = recipe.get("outputs", [])
    
    # 立即执行所有输出效果
    for effect_data in outputs:
        # 直接传递已包含所有信息的context
        WorldExecutor.execute(effect_data, context)
        
    return {"status": "success", "type": "instant"}


func _handle_duration_interaction(context: Dictionary) -> Dictionary:
    print("InteractionEngine: Handling duration interaction by creating a task.")
    
    var agent = context.get("agent")
    var target = context.get("target")
    var recipe = context.get("recipe")
    
    var task_comp = target.get_component("TaskComponent")
    if not task_comp:
        var error_msg = "Target entity cannot host tasks (missing TaskComponent)."
        return {"status": "failed", "reason": "NO_TASK_COMPONENT", "message": error_msg}

    # 1. 创建一个新的Task资源实例
    var new_task = Task.new(recipe.get("verb"), target.entity_id)

    # 2. 从配方中配置Task
    var process_data = recipe.get("process", {})
    new_task.required_progress = process_data.get("required_progress", 1)
    
    # 将完成后的效果列表存入Task中
    new_task.on_completion_effects = recipe.get("outputs", [])
    
    # 3. 将Task附加到目标实体上
    task_comp.add_task(new_task)
    
    return {"status": "success", "type": "task_created", "task_id": new_task.task_id}