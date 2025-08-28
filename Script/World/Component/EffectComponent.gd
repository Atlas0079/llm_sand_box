# res://Script/World/Component/EffectComponent.gd
extends Node

class_name EffectComponent
# --- 内部状态 ---
# key: condition_id (e.g., "MissingLeftArm"), value: ConditionInstance object
var active_conditions: Dictionary = {}

# --- 公共API ---

# 添加一个新效果
func add_condition(condition_id: String):
    if active_conditions.has(condition_id):
        # 如果效果已存在，可以根据游戏规则刷新持续时间或叠加
        print("Condition '", condition_id, "' already active. Refreshing.")
        # ...刷新逻辑...
        return

    # 从DataManager获取效果的模板数据
    var condition_template = DataManager.get_condition_template(condition_id)
    if condition_template.is_empty():
        printerr("Failed to add condition: template '", condition_id, "' not found.")
        return

    # 创建一个效果实例来跟踪运行时数据（如剩余时间）
    var condition_instance = Condition.new(condition_id, condition_template)
    active_conditions[condition_id] = condition_instance
    
    # 关键：通知父实体（生物）重新计算其能力值
    get_parent().recalculate_capacities() # 假设Creature有这个方法
    print("Condition '", condition_id, "' added.")

# 移除一个效果
func remove_condition(condition_id: String):
    if active_conditions.has(condition_id):
        active_conditions.erase(condition_id)
        # 同样，通知父实体重新计算
        get_parent().recalculate_capacities()
        print("Condition '", condition_id, "' removed.")

func update_per_tick(ticks_per_minute: int):
    pass

# 这是你提到的核心功能：计算对能力的总修正
func get_capacity_modifiers() -> Dictionary:
    var total_modifiers = {
        # "Manipulation": {"add": 0.0, "multiply": 1.0},
        # ...
    }

    for condition_instance in active_conditions.values():
        for modifier in condition_instance.template_data.get("modifiers", []):
            var target = modifier["target"]
            var op = modifier["operation"]
            var value = modifier["value"]

            if not total_modifiers.has(target):
                total_modifiers[target] = {"add": 0.0, "multiply": 1.0}
            
            if op == "add":
                total_modifiers[target]["add"] += value
            elif op == "multiply":
                total_modifiers[target]["multiply"] *= (1.0 + value)

    return total_modifiers


# --- 新增：上下文提供函数 ---
func get_conditions_context() -> Dictionary:
    """
    收集所有与此组件相关的状态和特质，并返回一个字典。
    """
    var context = {}
    var trait_list = []
    var status_list = []

    for condition_instance in active_conditions.values():
        if condition_instance.condition_type == "Trait":
            trait_list.append(condition_instance.condition_id)
        else:
            status_list.append(condition_instance.condition_id)
            
    context["trait_list"] = ", ".join(trait_list) if not trait_list.is_empty() else "无"
    context["status_list"] = ", ".join(status_list) if not status_list.is_empty() else "无"
    
    return context


# 条件实例
class Condition:
    var condition_id: String
    var template_data: Dictionary
    var remaining_duration: float = -1.0 # -1 代表无限期
    var condition_type: String = "Trait" # Trait, Status

    func _init(p_id, p_template):
        self.condition_id = p_id
        self.template_data = p_template
        if p_template.has("condition_type"):
            self.condition_type = p_template["condition_type"]
        if p_template.has("duration_hours"):
            self.remaining_duration = p_template["duration_hours"]
            
    func has_duration() -> bool:
        return remaining_duration > 0