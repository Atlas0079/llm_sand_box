# res://entities/components/decision_arbiter_component.gd
extends Node
class_name DecisionArbiterComponent

# 将规则类型映射到它们的脚本路径
const RULE_TYPE_MAP = {
    "Idle": "res://Script/World/InterruptRules/RuleIdle.gd",
    "LowNutrition": "res://Script/World/InterruptRules/RuleLowNutrition.gd",
    # 未来可以添加更多规则，例如：
    # "LowEnergy": "res://rules/rule_low_energy.gd"
}

# 每个agent的规则集是独立的！
var ruleset: Array[InterruptRule] = []

# 新的初始化函数，从JSON数据驱动
func initialize_from_data(component_data: Dictionary):
    if not component_data.has("rules"):
        printerr("DecisionArbiterComponent data is missing 'rules' array.")
        return

    var rules_data = component_data["rules"]
    for rule_data in rules_data:
        var rule_type = rule_data.get("type")
        
        if not RULE_TYPE_MAP.has(rule_type):
            printerr("Unknown interrupt rule type: ", rule_type)
            continue
        
        # 1. 加载脚本并创建实例
        var rule_script = load(RULE_TYPE_MAP[rule_type])
        if not rule_script:
            printerr("Failed to load script for rule type: ", rule_type)
            continue
        
        var new_rule: InterruptRule = rule_script.new()
        
        # 2. 调用规则自己的初始化函数，把整个数据块传给它
        new_rule.initialize_from_data(rule_data)
        
        # 3. 添加到规则集
        ruleset.append(new_rule)
        
    # 按优先级排序
    _sort_rules()
    print("DecisionArbiterComponent initialized with ", ruleset.size(), " rules.")
    
func _sort_rules():
    ruleset.sort_custom(func(a, b): return a.priority < b.priority)
    
# --- 核心仲裁函数 ---
# 将函数重命名，并让它只返回检查结果，而不是直接调用。
func check_if_interrupt_is_needed(agent: Entity) -> Dictionary:
    for rule in ruleset:
        var result = rule.should_interrupt(agent)
        if result.interrupt:
            # 只返回结果，不再调用LLMControlComponent
            return result
            
    # 如果没有任何规则触发，返回一个表示“无需中断”的字典
    return {"interrupt": false, "reason": ""}
            



    
# --- 提供给LLM修改的接口 ---
func modify_rule(rule_id: String, new_properties: Dictionary):
    var rule = find_rule(rule_id)
    if not rule:
        printerr("Rule '", rule_id, "' not found for this agent.")
        return

    for key in new_properties:
        if key == "priority":
            rule.priority = new_properties[key]
            _sort_rules() # 优先级变化后需要重新排序！
        elif key == "enabled":
            rule.enabled = new_properties[key]
        # ... 可以扩展修改其他属性，如阈值 ...

func find_rule(rule_id: String) -> InterruptRule:
    for r in ruleset:
        if r.rule_id == rule_id:
            return r
    return null