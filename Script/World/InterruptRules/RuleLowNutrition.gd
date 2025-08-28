# res://rules/rule_low_nutrition.gd
extends InterruptRule

var threshold: float = 25.0 # 默认阈值

# 重写内部配置函数
func _initialize_from_config(config: Dictionary):
    # 从JSON的config部分读取阈值，如果不存在则使用默认值
    self.threshold = config.get("threshold", 25.0)

func _check_condition(agent: Entity) -> Dictionary:
    var creature_comp = agent.get_component("CreatureComponent")
    if not creature_comp:
        return {"interrupt": false}
        
    if creature_comp.current_nutrition < self.threshold:
        return {
            "interrupt": true,
            "reason": "营养已低于警戒阈值。"
        }
    
    return {"interrupt": false} 