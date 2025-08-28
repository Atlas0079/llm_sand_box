# res://rules/interrupt_rule.gd
extends Resource
class_name InterruptRule

@export var rule_id: String = "base_rule" # 修改了变量名以保持一致
@export var priority: int = 100 # 规则的优先级，数字越小越优先
@export var description: String = "基础中断规则"
@export var enabled: bool = true

# 这是新的、唯一的初始化入口
func initialize_from_data(data: Dictionary):
    # 规则自我配置通用属性
    self.rule_id = data.get("id", "rule_" + str(randi()))
    self.priority = data.get("priority", 100)
    self.enabled = data.get("enabled", true)
    self.description = data.get("description", "") # 也从数据加载描述

    # 调用内部函数来处理特定配置
    var config = data.get("config", {})
    _initialize_from_config(config)

# 将此函数名前加上下划线，表示它主要供内部和子类使用
func _initialize_from_config(config: Dictionary):
    # 基类没有需要配置的，但子类可以重写这个方法
    pass

# 这是每个具体规则都需要实现的核心函数
# 它接收一个agent作为参数，返回一个字典
# 如果不中断，返回 {"interrupt": false}
# 如果中断，返回 {"interrupt": true, "reason": "some reason"}

func should_interrupt(agent: Entity) -> Dictionary:
    if not enabled:
        return {"interrupt": false}
    
    return _check_condition(agent)

# 这是一个虚拟方法，需要子类去重写(override)
func _check_condition(agent: Entity) -> Dictionary:
    # 基类默认不中断
    return {"interrupt": false}